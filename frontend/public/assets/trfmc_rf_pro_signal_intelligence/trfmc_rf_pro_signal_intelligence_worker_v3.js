"use strict";

/*
 TRFMC RF PRO V3 Reality Worker
 Synthetic/lab-only RF telemetry.
 No network. No SDR control. No interception.
*/

let state = {
  running: true,
  profile: "fhss",
  snr: 31,
  spanMHz: 80,
  rbwKHz: 10,
  centerMHz: 2440,
  detector: "RMS",
  maxHold: true,
  tick: 0
};

const hopSeq = [0.08,0.19,0.32,0.47,0.61,0.76,0.88,0.54,0.27,0.69,0.41,0.13];

function clamp(x,a,b){ return Math.max(a, Math.min(b, x)); }
function gauss(x,mu,s){ const z=(x-mu)/s; return Math.exp(-0.5*z*z); }

function makeSpectrum(n,t){
  const arr = new Float32Array(n);
  const floor = -112, ceil = -18;

  for(let i=0;i<n;i++){
    const f=i/(n-1);
    let p = -96 + 1.4*Math.sin(i*.011+t*.4) + 1.2*Math.sin(i*.047+t*.9);

    if(state.profile === "fhss"){
      for(let k=0;k<6;k++){
        const c = hopSeq[(Math.floor(t*2.4)+k*2)%hopSeq.length];
        p += 33*gauss(f,c,0.0065+k*.0007);
      }
      p += 10*gauss(f,.50,.14);
    } else if(state.profile === "ofdm"){
      p += 35*gauss(f,.50,.105);
      p += 9*gauss(f,.37,.010);
      p += 9*gauss(f,.63,.010);
      p -= 7*(gauss(f,.28,.018)+gauss(f,.72,.018));
    } else if(state.profile === "qpsk"){
      p += 35*gauss(f,.50,.032);
      p += 8*gauss(f,.43,.009);
      p += 8*gauss(f,.57,.009);
    } else if(state.profile === "burst"){
      const c=.12+.76*Math.abs(Math.sin(t*.27));
      p += 42*gauss(f,c,.010);
      p += 19*gauss(f,(c+.21)%1,.006);
    } else {
      p += 8*gauss(f,.5,.25);
    }

    arr[i]=clamp((p-floor)/(ceil-floor),0,1);
  }
  return arr;
}

function makeMaxHold(spec, prev){
  if(!prev || prev.length !== spec.length) return spec.slice();
  const out = new Float32Array(spec.length);
  for(let i=0;i<spec.length;i++) out[i] = Math.max(prev[i]*0.992, spec[i]);
  return out;
}

let maxHoldBuf = null;

function makeConstellation(points,t){
  const out = new Float32Array(points*4);
  const isQam = state.profile === "ofdm";
  const grid = isQam ? [-3,-1,1,3] : [-1,1];
  const norm = isQam ? 3 : 1;
  const jitter = Math.max(.012,(42-state.snr)/220);
  const rot = 0.20*Math.sin(t*.3);

  for(let i=0;i<points;i++){
    const sx = grid[(i + Math.floor(t*5)) % grid.length] / norm;
    const sy = grid[(Math.floor(i/grid.length)+Math.floor(t*4)) % grid.length] / norm;
    const ex = jitter*Math.sin(i*.71+t*2.0);
    const ey = jitter*Math.cos(i*.53+t*1.6);

    const x0 = sx, y0 = sy;
    const x = (sx+ex)*Math.cos(rot) - (sy+ey)*Math.sin(rot);
    const y = (sx+ex)*Math.sin(rot) + (sy+ey)*Math.cos(rot);

    out[i*4] = x;
    out[i*4+1] = y;
    out[i*4+2] = x0;
    out[i*4+3] = y0;
  }
  return out;
}

function makeBursts(count,t){
  const out = new Float32Array(count*5);
  for(let i=0;i<count;i++){
    const lane = (i*5 + Math.floor(t*2.1)) % 12;
    const x = (i*.053 + t*.044) % 1;
    const width = .012 + (i%6)*.006;
    const amp = .38 + .58*((i%9)/8);
    const anomaly = ((i + Math.floor(t*1.3)) % 17) === 0 ? 1 : 0;
    out[i*5] = x;
    out[i*5+1] = lane;
    out[i*5+2] = width;
    out[i*5+3] = amp;
    out[i*5+4] = anomaly;
  }
  return out;
}

function peaks(spec){
  const candidates=[];
  for(let i=2;i<spec.length-2;i++){
    if(spec[i] > spec[i-1] && spec[i] > spec[i+1] && spec[i] > .43){
      candidates.push({bin:i, amp:spec[i]});
    }
  }
  candidates.sort((a,b)=>b.amp-a.amp);
  return candidates.slice(0,8).map((p,idx)=>({
    id:"M"+(idx+1),
    bin:p.bin,
    mhz:Number((state.centerMHz - state.spanMHz/2 + state.spanMHz*(p.bin/(spec.length-1))).toFixed(3)),
    dbm:Number((-112 + p.amp*94).toFixed(1))
  }));
}

function metrics(t, spec){
  const evm = state.profile === "ofdm" ? 3.5 : state.profile === "fhss" ? 2.3 : 2.0;
  const aclr = state.profile === "ofdm" ? 46.2 : 52.4;
  const obw = state.profile === "ofdm" ? 18.8 : state.profile === "fhss" ? 12.6 : 5.2;
  const occupancy = state.profile === "fhss" ? 28 + 8*Math.sin(t*.5) : state.profile === "ofdm" ? 49 : 18;
  const anomaly = state.profile === "burst" ? 0.42 : state.profile === "fhss" ? 0.18 : 0.08;
  return {
    profile: state.profile,
    snr: Number(state.snr.toFixed(1)),
    evm: Number(evm.toFixed(2)),
    aclr: Number(aclr.toFixed(1)),
    obw: Number(obw.toFixed(1)),
    occupancy: Number(occupancy.toFixed(1)),
    anomaly: Number(anomaly.toFixed(2)),
    spanMHz: state.spanMHz,
    rbwKHz: state.rbwKHz,
    centerMHz: state.centerMHz,
    detector: state.detector,
    maxHold: state.maxHold,
    markers: peaks(spec)
  };
}

function frame(){
  if(!state.running) return;
  state.tick++;
  const t = state.tick / 30;

  const spectrum = makeSpectrum(1536,t);
  maxHoldBuf = makeMaxHold(spectrum,maxHoldBuf);
  const constellation = makeConstellation(1400,t);
  const bursts = makeBursts(96,t);
  const m = metrics(t,spectrum);
  const hold = state.maxHold ? maxHoldBuf : new Float32Array(0);

  postMessage(
    {type:"frame", spectrum, maxHold:hold, constellation, bursts, metrics:m},
    [spectrum.buffer, hold.buffer, constellation.buffer, bursts.buffer]
  );
}

setInterval(frame,33);

onmessage = (ev)=>{
  const msg = ev.data || {};
  if(msg.type === "config"){
    state = {...state, ...msg.config};
    if(msg.config && Object.prototype.hasOwnProperty.call(msg.config,"profile")) maxHoldBuf = null;
  }
  if(msg.type === "pause") state.running=false;
  if(msg.type === "resume") state.running=true;
};
