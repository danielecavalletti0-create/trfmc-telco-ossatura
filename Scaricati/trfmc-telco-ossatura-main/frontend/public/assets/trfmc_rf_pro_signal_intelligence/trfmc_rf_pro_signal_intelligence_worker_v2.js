/*
 TRFMC RF PRO V2 DSP Worker
 Synthetic/lab-only signal generator.
 No network. No SDR control. No interception.
*/

"use strict";

let state = {
  running: true,
  profile: "fhss",
  snr: 28,
  spanMHz: 40,
  rbwKHz: 30,
  centerMHz: 2440,
  tick: 0
};

function clamp(x,a,b){ return Math.max(a, Math.min(b, x)); }

function gauss(x, mu, sigma){
  const z = (x - mu) / sigma;
  return Math.exp(-0.5 * z * z);
}

function dbNoise(i,t){
  return -92 + 2.5*Math.sin(i*.019 + t*.37) + 1.5*Math.sin(i*.071 + t*.91);
}

function hopCenter(t, lane){
  const seq = [0.12,0.37,0.62,0.21,0.78,0.48,0.31,0.86,0.56,0.69];
  return seq[(Math.floor(t*2.2)+lane*3) % seq.length];
}

function makeSpectrum(n,t){
  const arr = new Float32Array(n);
  for(let i=0;i<n;i++){
    const f = i/(n-1);
    let p = dbNoise(i,t);

    if(state.profile === "fhss"){
      for(let k=0;k<5;k++){
        const c = hopCenter(t, k);
        p += 34 * gauss(f, c, 0.010 + k*0.001);
      }
    } else if(state.profile === "ofdm"){
      p += 30 * gauss(f, .50, .095);
      p += 9 * gauss(f, .39, .008);
      p += 9 * gauss(f, .61, .008);
    } else if(state.profile === "qpsk"){
      p += 33 * gauss(f, .50, .035);
      p += 10 * gauss(f, .43, .012);
      p += 10 * gauss(f, .57, .012);
    } else if(state.profile === "burst"){
      const c = .18 + .68 * Math.abs(Math.sin(t*.35));
      p += 40 * gauss(f, c, .015);
      p += 18 * gauss(f, (c+.17)%1, .009);
    } else {
      p += 12 * gauss(f, .5, .20);
    }

    const floor = -110;
    const ceil = -18;
    arr[i] = clamp((p - floor) / (ceil - floor), 0, 1);
  }
  return arr;
}

function makeConstellation(points,t){
  const out = new Float32Array(points*2);
  const mod = state.profile === "ofdm" ? 16 : 4;
  const grid = mod === 16 ? [-3,-1,1,3] : [-1,1];
  const norm = mod === 16 ? 3 : 1;
  const jitter = Math.max(.018, (36-state.snr)/180);
  for(let i=0;i<points;i++){
    const a = grid[(i + Math.floor(t*7)) % grid.length] / norm;
    const b = grid[(Math.floor(i/grid.length) + Math.floor(t*5)) % grid.length] / norm;
    out[i*2] = a + jitter*Math.sin(i*.77+t*2.1);
    out[i*2+1] = b + jitter*Math.cos(i*.59+t*1.7);
  }
  return out;
}

function makeBursts(count,t){
  const out = new Float32Array(count*4);
  for(let i=0;i<count;i++){
    const lane = (i*5 + Math.floor(t*2.2)) % 8;
    const x = (i*.071 + t*.047) % 1;
    const width = .018 + (i%5)*.005;
    const amp = .45 + .5*((i%7)/6);
    out[i*4] = x;
    out[i*4+1] = lane;
    out[i*4+2] = width;
    out[i*4+3] = amp;
  }
  return out;
}

function makeMetrics(t){
  const evm = state.profile === "ofdm" ? 3.8 : state.profile === "fhss" ? 2.6 : 2.2;
  const occ = state.profile === "fhss" ? 18 + 6*Math.sin(t*.7) : state.profile === "ofdm" ? 42 : 12 + 5*Math.sin(t*.9);
  const aclr = state.profile === "ofdm" ? 45 : 51;
  const obw = state.profile === "ofdm" ? 18.4 : state.profile === "fhss" ? 7.2 : 4.8;
  return {
    profile: state.profile,
    snr: Number(state.snr.toFixed(1)),
    evm: Number(evm.toFixed(2)),
    occupancy: Number(occ.toFixed(1)),
    aclr: Number(aclr.toFixed(1)),
    obw: Number(obw.toFixed(1)),
    spanMHz: state.spanMHz,
    rbwKHz: state.rbwKHz,
    centerMHz: state.centerMHz,
    gpuReadyHint: false
  };
}

function frame(){
  if(!state.running) return;

  state.tick++;
  const t = state.tick / 30;
  const spectrum = makeSpectrum(1024, t);
  const constellation = makeConstellation(520, t);
  const bursts = makeBursts(52, t);
  const metrics = makeMetrics(t);

  postMessage(
    {type:"frame", spectrum, constellation, bursts, metrics},
    [spectrum.buffer, constellation.buffer, bursts.buffer]
  );
}

setInterval(frame, 33);

onmessage = (ev)=>{
  const msg = ev.data || {};
  if(msg.type === "config"){
    state = {...state, ...msg.config};
  }
  if(msg.type === "pause"){
    state.running = false;
  }
  if(msg.type === "resume"){
    state.running = true;
  }
};
