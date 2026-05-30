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
  for (let i = 0; i < samples.length; i++) {
    samples[i] *= window[i];
  }
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

function generateTimeDomainSignal(t: number, length: number) {
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

function computeMetrics(spectrum: Float32Array) {
  let peak = 0;
  let sum = 0;
  const floorValues: number[] = [];

  for (let i = 0; i < spectrum.length; i++) {
    const value = spectrum[i];
    peak = Math.max(peak, value);
    sum += value;
    if (value < 0.18) floorValues.push(value);
  }

  const mean = sum / spectrum.length;
  const floor = floorValues.length ? floorValues.reduce((a, b) => a + b, 0) / floorValues.length : 0.12;
  const snr = Math.max(12, Math.min(42, 24 + (peak - floor) * 38));
  const evm = Math.max(1.0, 4.2 - (snr - 20) * 0.08);
  const obw = 9.5 + peak * 6.5 + (frame % 120) * 0.01;
  const aclr = -50 - (snr - 24) * 0.4;

  return {
    snr: Number(snr.toFixed(1)),
    evm: Number(evm.toFixed(2)),
    mer: Number((snr + 3.1).toFixed(1)),
    obw: Number(obw.toFixed(2)),
    aclrLow: Number(aclr.toFixed(1)),
    aclrHigh: Number((aclr - 0.9).toFixed(1)),
    channelPower: Number((-19.5 + mean * 16).toFixed(1)),
    noiseFloor: Number((-102 + floor * 22).toFixed(1)),
    crestFactor: Number((8.8 + peak * 2.2).toFixed(1)),
    classifier: frame % 180 < 90 ? "64QAM/OFDM" : "FHSS/QPSK",
    evidence: frame % 180 < 90 ? "software-defined receiver lab" : "adaptive burst scan"
  };
}

function computeFFTTrace(t: number, binsCount: number) {
  const fftSize = Math.max(1024, binsCount * 4);
  const timeSignal = generateTimeDomainSignal(t, fftSize);
  const window = blackmanHarris(fftSize);
  applyWindow(timeSignal, window);

  const imag = new Float32Array(fftSize);
  const real = timeSignal;

  fft(real, imag);

  const spectrum = new Float32Array(binsCount);
  const half = fftSize / 2;
  const scale = 2 / fftSize;

  let max = 0;
  for (let i = 0; i < binsCount; i++) {
    const index = Math.floor((i / binsCount) * half);
    const value = Math.sqrt(real[index] * real[index] + imag[index] * imag[index]) * scale;
    spectrum[i] = value;
    max = Math.max(max, value);
  }

  for (let i = 0; i < binsCount; i++) {
    spectrum[i] = Math.max(0, Math.min(1, spectrum[i] / (max || 1)));
  }

  return spectrum;
}

function generateIQ(t: number, count = 320): IQPoint[] {
  const baseSymbols = [
    [-0.75, -0.75],
    [-0.75, -0.25],
    [-0.25, -0.75],
    [-0.25, -0.25],
    [0.25, 0.25],
    [0.25, 0.75],
    [0.75, 0.25],
    [0.75, 0.75]
  ];

  const pts: IQPoint[] = [];
  const scale = 0.38;
  const jitterPhase = t * 0.0012;

  for (let i = 0; i < count; i++) {
    const symbol = baseSymbols[i % baseSymbols.length];
    const noise = 0.04 + 0.018 * Math.abs(Math.sin(jitterPhase + i * 0.13));
    const err = 0.06 + Math.abs(Math.cos(jitterPhase * 0.8 + i * 0.21)) * 0.14;
    const disturbance = 0.015 * Math.sin(i * 1.7 + jitterPhase * 3.1);

    pts.push({
      i: symbol[0] * scale + Math.sin(i * 0.93 + jitterPhase) * noise + disturbance,
      q: symbol[1] * scale + Math.cos(i * 1.1 + jitterPhase * 0.9) * noise + disturbance,
      err: Math.min(0.28, err)
    });
  }

  return pts;
}

function tick() {
  const t = performance.now();
  const primary = computeFFTTrace(t, bins);

  if (!maxHold || maxHold.length !== bins) {
    maxHold = primary.slice();
    average = primary.slice();
  } else {
    for (let i = 0; i < bins; i++) {
      maxHold[i] = Math.max(maxHold[i] * 0.995, primary[i]);
      average![i] = average![i] * 0.92 + primary[i] * 0.08;
    }
  }

  const iq = generateIQ(t);
  const metrics = computeMetrics(primary);
  const markers = extractMarkers(primary);

  postMessage({
    type: "rf-frame",
    frame,
    primary,
    maxHold: maxHold.slice(),
    average: average!.slice(),
    iq,
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
