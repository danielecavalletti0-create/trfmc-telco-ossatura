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

let timer: number | undefined;
let bins = 1024;
let frame = 0;
let maxHold: Float32Array | null = null;
let average: Float32Array | null = null;

function clamp01(v: number) {
  return Math.max(0, Math.min(1, v));
}

function generateTrace(t: number, n: number): Float32Array {
  const out = new Float32Array(n);

  for (let i = 0; i < n; i++) {
    const f = i / (n - 1);

    let v =
      0.060 +
      0.020 * Math.sin(i * 0.030 + t * 0.0010) +
      0.012 * Math.sin(i * 0.090 + t * 0.0008) +
      0.006 * Math.cos(i * 0.017 + frame * 0.03);

    const hopping = [
      0.12 + 0.012 * Math.sin(t * 0.0008),
      0.25,
      0.37 + 0.020 * Math.sin(t * 0.0005),
      0.50,
      0.63,
      0.78 + 0.015 * Math.cos(t * 0.0006),
      0.87
    ];

    hopping.forEach((p, k) => {
      const amp = 0.20 + (k % 3) * 0.09;
      const width = 0.008 + (k % 2) * 0.006;
      v += amp * Math.exp(-Math.pow((f - p) / width, 2));
    });

    const adjacentMaskEnergy =
      f > 0.15 && f < 0.26 ? 0.028 :
      f > 0.73 && f < 0.88 ? 0.024 :
      0;

    out[i] = clamp01(v + adjacentMaskEnergy);
  }

  return out;
}

function generateIQ(t: number, count = 320): IQPoint[] {
  const centers = [
    [-0.65, -0.65],
    [-0.65, 0.65],
    [0.65, -0.65],
    [0.65, 0.65]
  ];

  const pts: IQPoint[] = [];

  for (let i = 0; i < count; i++) {
    const c = centers[i % centers.length];
    const jitter = 0.040 + 0.018 * Math.sin(t * 0.001 + i * 0.73);
    const err = Math.abs(Math.sin(t * 0.0009 + i * 0.31)) * 0.14;

    pts.push({
      i: c[0] + Math.sin(i * 12.989 + t * 0.0010) * jitter,
      q: c[1] + Math.cos(i * 7.123 + t * 0.0011) * jitter,
      err
    });
  }

  return pts;
}

function computeMetrics(trace: Float32Array) {
  let peak = 0;
  let sum = 0;
  let floorSum = 0;
  let floorCount = 0;

  for (let i = 0; i < trace.length; i++) {
    const v = trace[i];
    peak = Math.max(peak, v);
    sum += v;

    if (v < 0.16) {
      floorSum += v;
      floorCount++;
    }
  }

  const mean = sum / trace.length;
  const floor = floorCount ? floorSum / floorCount : 0.08;
  const snr = 20 + (peak - floor) * 38;
  const evm = Math.max(1.4, 4.5 - (snr - 25) * 0.07);
  const obw = 11.0 + Math.sin(frame * 0.02) * 0.7 + peak * 3.0;
  const aclr = -48 - (snr - 25) * 0.35;

  return {
    snr: Number(snr.toFixed(1)),
    evm: Number(evm.toFixed(2)),
    mer: Number((snr + 2.3).toFixed(1)),
    obw: Number(obw.toFixed(2)),
    aclrLow: Number(aclr.toFixed(1)),
    aclrHigh: Number((aclr - 0.5).toFixed(1)),
    channelPower: Number((-18.5 + mean * 4).toFixed(1)),
    noiseFloor: Number((-98 + floor * 14).toFixed(1)),
    crestFactor: Number((8.5 + peak * 2.4).toFixed(1)),
    classifier: "OFDM/FHSS",
    evidence: "DSP worker synthetic lab"
  };
}

function tick() {
  const t = performance.now();
  const primary = generateTrace(t, bins);

  if (!maxHold || maxHold.length !== bins) {
    maxHold = primary.slice();
    average = primary.slice();
  } else {
    for (let i = 0; i < bins; i++) {
      maxHold[i] = Math.max(maxHold[i] * 0.998, primary[i]);
      average![i] = average![i] * 0.94 + primary[i] * 0.06;
    }
  }

  const iq = generateIQ(t);
  const metrics = computeMetrics(primary);

  postMessage({
    type: "rf-frame",
    frame,
    primary,
    maxHold: maxHold.slice(),
    average: average!.slice(),
    iq,
    metrics,
    markers: [
      { index: 128, label: "M1" },
      { index: 260, label: "FH1" },
      { index: 512, label: "NR5G" },
      { index: 645, label: "M4" },
      { index: 800, label: "FHSS" }
    ]
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
