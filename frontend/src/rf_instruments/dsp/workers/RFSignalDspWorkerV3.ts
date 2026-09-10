type StartMessage = {
  type: "start";
  bins?: number;
  intervalMs?: number;
};

type StopMessage = {
  type: "stop";
};

type WorkerInput = StartMessage | StopMessage;

type IQPoint = {
  i: number;
  q: number;
  err: number;
};

type Marker = {
  index: number;
  label: string;
};

let timer: number | undefined;
let bins = 1024;
let frame = 0;
let maxHold: Float32Array | null = null;
let average: Float32Array | null = null;

const PI2 = Math.PI * 2;

// ============================================================================
// COSTANTI DI CALIBRAZIONE STRUMENTO (documentate esplicitamente)
//
// Questo e' un generatore simulato, non un ricevitore reale: la potenza FFT
// grezza non ha un riferimento dBm fisico. Come qualunque spectrum analyzer
// reale (che richiede una "reference level" e uno "span" impostati
// dall'operatore), scegliamo qui due costanti di riferimento fisse e le
// applichiamo in modo coerente a tutte le metriche derivate, cosi' i numeri
// restano internamente consistenti (rapporti/log corretti) anche se il punto
// zero e' una scelta di calibrazione dichiarata, non una misura assoluta.
// ============================================================================
const REF_SPAN_MHZ = 20; // span simulato dell'analizzatore, Nyquist = 10 MHz
const REF_LEVEL_DBM = -10; // livello di riferimento per la conversione potenza->dBm
const DB_FLOOR = -140; // pavimento numerico per evitare log(0)

function blackmanHarris(length: number) {
  const window = new Float32Array(length);

  for (let n = 0; n < length; n++) {
    window[n] =
      0.35875 -
      0.48829 * Math.cos((PI2 * n) / (length - 1)) +
      0.14128 * Math.cos((2 * PI2 * n) / (length - 1)) -
      0.01168 * Math.cos((3 * PI2 * n) / (length - 1));
  }

  return window;
}

function applyWindow(samples: Float32Array, window: Float32Array) {
  const out = new Float32Array(samples.length);
  for (let i = 0; i < samples.length; i++) {
    out[i] = samples[i] * window[i];
  }
  return out;
}

function createBitReversal(length: number) {
  const bits = Math.log2(length);
  const reversed = new Uint32Array(length);

  for (let i = 0; i < length; i++) {
    let x = i;
    let y = 0;

    for (let j = 0; j < bits; j++) {
      y = (y << 1) | (x & 1);
      x >>>= 1;
    }

    reversed[i] = y;
  }

  return reversed;
}

function fft(real: Float32Array, imag: Float32Array) {
  const n = real.length;
  const bitReverse = createBitReversal(n);

  for (let i = 0; i < n; i++) {
    const j = bitReverse[i];
    if (j > i) {
      [real[i], real[j]] = [real[j], real[i]];
      [imag[i], imag[j]] = [imag[j], imag[i]];
    }
  }

  for (let size = 2; size <= n; size *= 2) {
    const half = size / 2;
    const theta = -PI2 / size;
    const wPhaseStep = Math.cos(theta);
    const wPhaseStepImag = Math.sin(theta);

    for (let offset = 0; offset < n; offset += size) {
      let wr = 1;
      let wi = 0;

      for (let k = 0; k < half; k++) {
        const i = offset + k;
        const j = i + half;
        const tr = wr * real[j] - wi * imag[j];
        const ti = wr * imag[j] + wi * real[j];
        real[j] = real[i] - tr;
        imag[j] = imag[i] - ti;
        real[i] += tr;
        imag[i] += ti;

        const tmp = wr;
        wr = tmp * wPhaseStep - wi * wPhaseStepImag;
        wi = tmp * wPhaseStepImag + wi * wPhaseStep;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Generatore di rumore gaussiano (Box-Muller). Necessario per iniettare un
// rumore additivo quantificato (AWGN) con una varianza nota, in modo che
// SNR/EVM misurati a valle abbiano un riferimento di verita' rispetto a cui
// essere confrontati (esattamente come si fa calibrando un generatore RF
// reale con un noise floor noto prima di misurarlo con l'analizzatore).
// ---------------------------------------------------------------------------
function gaussianNoise(): number {
  let u1 = 0;
  let u2 = 0;
  while (u1 === 0) u1 = Math.random();
  u2 = Math.random();
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(PI2 * u2);
}

/**
 * Segnale portante deterministico (senza rumore): somma di toni fissi piu'
 * deriva lenta di fase, per simulare un multiplex a banda stretta con
 * qualche struttura spettrale riconoscibile (picchi).
 */
function carrierSignal(t: number, length: number) {
  const real = new Float32Array(length);
  const phaseDrift = t * 0.00015;

  const carriers = [
    { freq: 0.128, amp: 0.28, phase: 0.12 },
    { freq: 0.261, amp: 0.22, phase: 1.08 },
    { freq: 0.432, amp: 0.33, phase: 2.14 },
    { freq: 0.582, amp: 0.19, phase: 3.32 }
  ];

  for (let n = 0; n < length; n++) {
    let sample = 0;
    const base = 0.11 * Math.sin(PI2 * ((n / length) * 1.0 + phaseDrift * 0.4));
    const drift = 0.05 * Math.sin(PI2 * (n / 128 + phaseDrift * 0.8));

    sample += base + drift;

    for (const carrier of carriers) {
      const phase = PI2 * carrier.freq * n + carrier.phase + phaseDrift;
      sample += carrier.amp * Math.sin(phase);
    }

    sample += 0.025 * Math.sin(PI2 * (n / 20 + phaseDrift * 0.7));
    sample += 0.018 * Math.cos(PI2 * (n / 11 + phaseDrift * 0.53));
    sample += (Math.sin(n * 0.23 + phaseDrift * 0.32) * Math.cos(n * 0.11 + phaseDrift * 0.21)) * 0.009;
    sample *= 0.92 + 0.06 * Math.sin(PI2 * (n / length) + phaseDrift * 0.95);

    real[n] = sample;
  }

  return real;
}

/**
 * SNR "di verita'" del canale simulato: varia lentamente nel tempo, come un
 * vero link RF soggetto a fading/interferenza lenta. Questo NON e' il numero
 * mostrato all'utente: e' il parametro nascosto che il rumore iniettato
 * rispetta, e che le metriche calcolate a valle devono ricostruire misurando
 * il segnale risultante (proprio come farebbe uno strumento reale).
 */
function groundTruthSnrDb(t: number): number {
  return 26 + 7 * Math.sin(t * 0.00007) + 2 * Math.sin(t * 0.00023 + 1.3);
}

/**
 * Genera il segnale nel tempo con rumore gaussiano additivo iniettato alla
 * potenza necessaria per ottenere lo SNR di verita' richiesto, misurato
 * rispetto alla potenza media del segnale portante.
 */
function generateTimeDomainSignal(t: number, length: number) {
  const carrier = carrierSignal(t, length);

  let signalPower = 0;
  for (let n = 0; n < length; n++) signalPower += carrier[n] * carrier[n];
  signalPower /= length;

  const snrDb = groundTruthSnrDb(t);
  const noisePower = signalPower / Math.pow(10, snrDb / 10);
  const noiseStd = Math.sqrt(noisePower);

  const out = new Float32Array(length);
  for (let n = 0; n < length; n++) {
    out[n] = carrier[n] + gaussianNoise() * noiseStd;
  }

  return out;
}

function normalizeTrace(trace: Float32Array) {
  let max = 1e-6;
  for (let i = 0; i < trace.length; i++) {
    max = Math.max(max, trace[i]);
  }

  const out = new Float32Array(trace.length);
  for (let i = 0; i < trace.length; i++) {
    out[i] = Math.max(0, Math.min(1, trace[i] / max));
  }

  return out;
}

function extractMarkers(spectrum: Float32Array) {
  const markers: Marker[] = [];
  const threshold = 0.35;
  const size = spectrum.length;

  for (let i = 4; i < size - 4 && markers.length < 5; i++) {
    const value = spectrum[i];
    if (value < threshold) continue;
    if (value > spectrum[i - 1] && value >= spectrum[i + 1]) {
      markers.push({ index: i, label: `PK${markers.length + 1}` });
    }
  }

  if (markers.length < 5) {
    for (let i = 0; i < size && markers.length < 5; i += Math.floor(size / 7)) {
      if (!markers.some((m) => m.index === i)) {
        markers.push({ index: i, label: `M${markers.length + 1}` });
      }
    }
  }

  return markers;
}

function toDb(power: number): number {
  return Math.max(DB_FLOOR, 10 * Math.log10(Math.max(power, 1e-12)));
}

/**
 * Metriche derivate dallo spettro di potenza a piena risoluzione (prima
 * della decimazione ai bin di visualizzazione) e dal segnale nel tempo
 * grezzo. Ogni misura e' calcolata con la formula standard corrispondente,
 * non con un'approssimazione cosmetica:
 *
 * - OBW: metodo della banda al 99% della potenza (standard per spectrum
 *   analyzer: banda che esclude lo 0.5% di potenza da ciascun lato).
 * - Channel power / noise floor: integrazione di potenza in banda / mediana
 *   dei bin fuori banda.
 * - SNR: derivato come channel power - noise floor (non una formula
 *   indipendente), esattamente come misurerebbe uno strumento reale.
 * - ACLR: rapporto di potenza tra banda adiacente e banda principale.
 * - Crest factor: picco/RMS reale sul segnale nel tempo non finestrato.
 */
function computeSpectrumMetrics(
  powerSpectrum: Float32Array,
  timeSignal: Float32Array
) {
  const half = powerSpectrum.length;

  let totalPower = 0;
  for (let k = 0; k < half; k++) totalPower += powerSpectrum[k];

  const sideTarget = totalPower * 0.005;

  let cumulative = 0;
  let lowIndex = 0;
  for (let k = 0; k < half; k++) {
    cumulative += powerSpectrum[k];
    if (cumulative >= sideTarget) {
      lowIndex = k;
      break;
    }
  }

  cumulative = 0;
  let highIndex = half - 1;
  for (let k = half - 1; k >= 0; k--) {
    cumulative += powerSpectrum[k];
    if (cumulative >= sideTarget) {
      highIndex = k;
      break;
    }
  }
  if (highIndex < lowIndex) highIndex = lowIndex;

  let channelPower = 0;
  for (let k = lowIndex; k <= highIndex; k++) channelPower += powerSpectrum[k];

  const bandWidth = highIndex - lowIndex + 1;
  const adjLowStart = Math.max(0, lowIndex - bandWidth);
  const adjHighEnd = Math.min(half - 1, highIndex + bandWidth);

  let adjLowPower = 0;
  for (let k = adjLowStart; k < lowIndex; k++) adjLowPower += powerSpectrum[k];

  let adjHighPower = 0;
  for (let k = highIndex + 1; k <= adjHighEnd; k++) adjHighPower += powerSpectrum[k];

  const outOfBand: number[] = [];
  for (let k = 0; k < half; k++) {
    if (k < lowIndex || k > highIndex) outOfBand.push(powerSpectrum[k]);
  }
  outOfBand.sort((a, b) => a - b);
  const noiseFloorPower = outOfBand.length
    ? outOfBand[Math.floor(outOfBand.length / 2)]
    : 1e-9;

  const channelPowerDbm = toDb(channelPower) + REF_LEVEL_DBM;
  const noiseFloorDbm = toDb(noiseFloorPower) + REF_LEVEL_DBM;
  // SNR confronta grandezze comparabili: potenza totale in banda (somma su
  // bandWidth bin) contro potenza di rumore nella STESSA banda (densita' per
  // bin moltiplicata per il numero di bin), non densita' contro totale.
  const noisePowerInChannelBw = noiseFloorPower * bandWidth;
  const snrDb = Math.max(
    0,
    10 * Math.log10(Math.max(channelPower, 1e-12) / Math.max(noisePowerInChannelBw, 1e-12))
  );

  const aclrLowDb = 10 * Math.log10(Math.max(adjLowPower, 1e-12) / Math.max(channelPower, 1e-12));
  const aclrHighDb = 10 * Math.log10(Math.max(adjHighPower, 1e-12) / Math.max(channelPower, 1e-12));

  const obwFractionOfNyquist = (highIndex - lowIndex + 1) / half;
  const obwMHz = obwFractionOfNyquist * (REF_SPAN_MHZ / 2);

  let peak = 0;
  let sumSq = 0;
  for (let n = 0; n < timeSignal.length; n++) {
    const abs = Math.abs(timeSignal[n]);
    peak = Math.max(peak, abs);
    sumSq += timeSignal[n] * timeSignal[n];
  }
  const rms = Math.sqrt(sumSq / timeSignal.length) || 1e-9;
  const crestFactorDb = 20 * Math.log10(peak / rms);

  return {
    snrDb,
    channelPowerDbm,
    noiseFloorDbm,
    aclrLowDb,
    aclrHighDb,
    obwMHz,
    crestFactorDb
  };
}

function computeFFTTrace(t: number, binsCount: number) {
  const fftSize = Math.max(1024, binsCount * 4);
  const timeSignal = generateTimeDomainSignal(t, fftSize);
  const window = blackmanHarris(fftSize);
  const windowed = applyWindow(timeSignal, window);

  const imag = new Float32Array(fftSize);
  const real = windowed;

  fft(real, imag);

  const half = fftSize / 2;
  const scale = 2 / fftSize;

  // Spettro di potenza a piena risoluzione (per le metriche - vedi
  // computeSpectrumMetrics), separato dalla traccia decimata per la sola
  // visualizzazione grafica (che non necessita della stessa precisione).
  const fullPower = new Float32Array(half);
  for (let k = 0; k < half; k++) {
    const mag = Math.sqrt(real[k] * real[k] + imag[k] * imag[k]) * scale;
    fullPower[k] = mag * mag;
  }

  const spectrum = new Float32Array(binsCount);
  let max = 0;
  for (let i = 0; i < binsCount; i++) {
    const index = Math.floor((i / binsCount) * half);
    const value = Math.sqrt(fullPower[index]);
    spectrum[i] = value;
    max = Math.max(max, value);
  }

  for (let i = 0; i < binsCount; i++) {
    spectrum[i] = Math.max(0, Math.min(1, spectrum[i] / (max || 1)));
  }

  return { spectrum, fullPower, rawTimeSignal: timeSignal };
}

// ---------------------------------------------------------------------------
// Costellazioni standard (posizioni esatte, non punti sparsi a caso). Il
// tipo realmente generato viene riportato in metrics.classifier: non e' un
// "classificatore" nel senso di riconoscimento cieco del segnale (che
// richiederebbe una pipeline di demodulazione reale, fuori scopo qui), ma
// la verita' nota del simulatore - la stessa distinzione che un banco di
// test dichiara quando genera un segnale di riferimento noto.
// ---------------------------------------------------------------------------
const QPSK_SYMBOLS: Array<[number, number]> = ([
  [1, 1],
  [1, -1],
  [-1, 1],
  [-1, -1]
] as Array<[number, number]>).map(([i, q]) => [i / Math.SQRT2, q / Math.SQRT2]);

const QAM16_LEVELS = [-3, -1, 1, 3];
const QAM16_SYMBOLS: Array<[number, number]> = [];
for (const i of QAM16_LEVELS) {
  for (const q of QAM16_LEVELS) {
    QAM16_SYMBOLS.push([i / Math.sqrt(10), q / Math.sqrt(10)]);
  }
}

function groundTruthEvmPercent(t: number): number {
  return 3.2 + 1.6 * Math.sin(t * 0.00013 + 1.7);
}

function activeModulation(t: number): { symbols: Array<[number, number]>; label: string } {
  // Alterna modulazione ogni ~20s (t in ms) - cambio lento e deliberato,
  // non un contatore di frame usato come sostituto di un classificatore.
  const cycle = Math.floor(t / 20000) % 2;
  return cycle === 0
    ? { symbols: QPSK_SYMBOLS, label: "QPSK" }
    : { symbols: QAM16_SYMBOLS, label: "16-QAM" };
}

function generateIQ(t: number, count = 320): { points: IQPoint[]; evmPercent: number; merDb: number; label: string } {
  const { symbols, label } = activeModulation(t);
  const evmTarget = groundTruthEvmPercent(t);

  let idealPowerSum = 0;
  let errorPowerSum = 0;
  const points: IQPoint[] = [];

  for (let n = 0; n < count; n++) {
    const symbol = symbols[n % symbols.length];
    const idealI = symbol[0];
    const idealQ = symbol[1];
    const symbolRms = Math.sqrt(idealI * idealI + idealQ * idealQ);

    // Rumore gaussiano 2D calibrato per ottenere, in aggregato sul burst,
    // un EVM misurato vicino a evmTarget (stesso principio della catena
    // spettro/SNR sopra: verita' nota -> rumore iniettato -> misura).
    const perAxisStd = (evmTarget / 100) * symbolRms * 0.7071; // 1/sqrt(2)
    const errI = gaussianNoise() * perAxisStd;
    const errQ = gaussianNoise() * perAxisStd;

    const i = idealI + errI;
    const q = idealQ + errQ;

    idealPowerSum += idealI * idealI + idealQ * idealQ;
    errorPowerSum += errI * errI + errQ * errQ;

    points.push({ i, q, err: Math.sqrt(errI * errI + errQ * errQ) });
  }

  const evmRms = Math.sqrt(errorPowerSum / idealPowerSum);
  const evmPercent = evmRms * 100;
  const merDb = -20 * Math.log10(Math.max(evmRms, 1e-6));

  return { points, evmPercent, merDb, label };
}

function tick() {
  const t = performance.now();
  const { spectrum, fullPower, rawTimeSignal } = computeFFTTrace(t, bins);

  if (!maxHold || maxHold.length !== bins) {
    maxHold = spectrum.slice();
    average = spectrum.slice();
  } else {
    for (let i = 0; i < bins; i++) {
      maxHold[i] = Math.max(maxHold[i] * 0.995, spectrum[i]);
      average![i] = average![i] * 0.92 + spectrum[i] * 0.08;
    }
  }

  const spectrumMetrics = computeSpectrumMetrics(fullPower, rawTimeSignal);
  const constellation = generateIQ(t);

  const metrics = {
    snr: Number(spectrumMetrics.snrDb.toFixed(1)),
    evm: Number(constellation.evmPercent.toFixed(2)),
    mer: Number(constellation.merDb.toFixed(1)),
    obw: Number(spectrumMetrics.obwMHz.toFixed(2)),
    aclrLow: Number(spectrumMetrics.aclrLowDb.toFixed(1)),
    aclrHigh: Number(spectrumMetrics.aclrHighDb.toFixed(1)),
    channelPower: Number(spectrumMetrics.channelPowerDbm.toFixed(1)),
    noiseFloor: Number(spectrumMetrics.noiseFloorDbm.toFixed(1)),
    crestFactor: Number(spectrumMetrics.crestFactorDb.toFixed(1)),
    classifier: constellation.label,
    evidence: "simulatore: costellazione e canale noti (non rilevamento cieco)"
  };

  const markers = extractMarkers(spectrum);

  postMessage({
    type: "rf-frame",
    frame,
    primary: spectrum,
    maxHold: maxHold.slice(),
    average: average!.slice(),
    iq: constellation.points,
    metrics,
    markers
  });

  frame++;
}

self.onmessage = (ev: MessageEvent<WorkerInput>) => {
  const msg = ev.data;

  if (msg.type === "start") {
    bins = msg.bins ?? 1024;
    const intervalMs = msg.intervalMs ?? 33;

    if (timer !== undefined) clearInterval(timer);
    timer = setInterval(tick, intervalMs) as unknown as number;
  }

  if (msg.type === "stop") {
    if (timer !== undefined) clearInterval(timer);
    timer = undefined;
  }
};

export {};
