from __future__ import annotations
import hashlib, json, math, shutil, statistics, subprocess, time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse, FileResponse
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/v584", tags=["RF PRO v5.8.4 UAV FHSS"])
ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "runtime" / "workbench_v580"
IQ_DIR, UAV_DIR, REPORT_DIR = RUNTIME/"iq", RUNTIME/"uav", RUNTIME/"reports"
for d in (IQ_DIR, UAV_DIR, REPORT_DIR): d.mkdir(parents=True, exist_ok=True)
try:
    import numpy as np
    HAS_NUMPY=True
except Exception:
    np=None
    HAS_NUMPY=False

PROFILES={
 "LOWBAND_TEST_1_5":{"label":"Low-band engineering test 1–5 MHz","start_hz":1_000_000,"stop_hz":5_000_000,"bin_hz":100_000,"bucket_hz":100_000},
 "SRD_433":{"label":"433 MHz telemetry / RC candidate","start_hz":433_000_000,"stop_hz":435_000_000,"bin_hz":25_000,"bucket_hz":25_000},
 "SRD_868_EU":{"label":"868 MHz EU SRD / telemetry candidate","start_hz":863_000_000,"stop_hz":870_000_000,"bin_hz":50_000,"bucket_hz":100_000},
 "ISM_915":{"label":"902–928 MHz ISM / FHSS candidate","start_hz":902_000_000,"stop_hz":928_000_000,"bin_hz":100_000,"bucket_hz":250_000},
 "L_BAND_VIDEO_12_13":{"label":"1.2/1.3 GHz video downlink witness","start_hz":1_200_000_000,"stop_hz":1_360_000_000,"bin_hz":500_000,"bucket_hz":1_000_000},
 "ISM_24_UAV":{"label":"2.4 GHz UAV C2/video/Wi-Fi-like","start_hz":2_400_000_000,"stop_hz":2_483_500_000,"bin_hz":250_000,"bucket_hz":1_000_000},
 "ISM_58_UAV":{"label":"5.8 GHz video/C2 candidate","start_hz":5_725_000_000,"stop_hz":5_875_000_000,"bin_hz":500_000,"bucket_hz":2_000_000},
 "GNSS_L1_WITNESS":{"label":"GNSS L1 interference witness","start_hz":1_559_000_000,"stop_hz":1_610_000_000,"bin_hz":250_000,"bucket_hz":1_000_000}
}

def now(): return datetime.now(timezone.utc).isoformat()
def sha(p:Path)->str:
    h=hashlib.sha256()
    with p.open("rb") as f:
        for c in iter(lambda:f.read(1024*1024),b""): h.update(c)
    return h.hexdigest()
def save(prefix:str,obj:Dict[str,Any])->Dict[str,Any]:
    p=UAV_DIR/f"{prefix}_{int(time.time())}.json"
    obj["created_at"]=now()
    p.write_text(json.dumps(obj,indent=2,ensure_ascii=False),encoding="utf-8")
    obj["file"]=str(p); obj["name"]=p.name; obj["sha256"]=sha(p)
    return obj
def run(cmd:List[str],timeout:int=45)->Dict[str,Any]:
    try:
        r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=timeout,check=False)
        return {"cmd":cmd,"returncode":r.returncode,"stdout":r.stdout[-300000:],"stderr":r.stderr[-20000:]}
    except Exception as e:
        return {"cmd":cmd,"returncode":-1,"stdout":"","stderr":repr(e)}
def parse_sweep(txt:str,start:float,stop:float)->List[Dict[str,float]]:
    rows=[]
    for line in (txt or "").splitlines():
        parts=[x.strip() for x in line.split(",")]
        if len(parts)<7: continue
        try:
            low=float(parts[2]); high=float(parts[3]); step=float(parts[4]); vals=[float(x) for x in parts[6:] if x.strip()]
        except Exception: continue
        for i,db in enumerate(vals):
            f=low+i*step+step/2
            if start<=f<=stop and f<=high: rows.append({"freq_hz":round(f,3),"db":round(db,2)})
    merged={}
    for r in rows:
        k=int(round(r["freq_hz"]))
        if k not in merged or r["db"]>merged[k]["db"]: merged[k]=r
    return sorted(merged.values(),key=lambda x:x["freq_hz"])
def synthetic(start:float,stop:float,points:int,seq:int)->List[Dict[str,float]]:
    points=max(64,min(4096,points)); w=stop-start
    hops=[.13,.27,.41,.58,.73,.86]; hop=start+w*hops[seq%len(hops)]; fixed=start+w*.52
    out=[]
    for i in range(points):
        f=start+w*i/(points-1); noise=-94+4*math.sin(i/17)
        g1=math.exp(-.5*((f-hop)/max(w*.004,1))**2); g2=math.exp(-.5*((f-fixed)/max(w*.01,1))**2)
        out.append({"freq_hz":round(f,3),"db":round(noise+44*g1+24*g2,2)})
    return out
def peaks(bins:List[Dict[str,float]],thr:float,maxp:int=40)->List[Dict[str,Any]]:
    if len(bins)<3: return []
    med=statistics.median([b["db"] for b in bins]); out=[]
    for i in range(1,len(bins)-1):
        b=bins[i]
        if b["db"]>=bins[i-1]["db"] and b["db"]>=bins[i+1]["db"] and b["db"]-med>=thr:
            out.append({"freq_hz":b["freq_hz"],"freq_mhz":round(b["freq_hz"]/1e6,6),"db":b["db"],"delta_db":round(b["db"]-med,2)})
    return sorted(out,key=lambda x:x["db"],reverse=True)[:maxp]
def bucket(f:float,b:float)->float: return round(round(f/max(b,1))*max(b,1),3)
def latest(prefix:str)->Dict[str,Any]:
    files=sorted(UAV_DIR.glob(f"{prefix}_*.json"),key=lambda p:p.stat().st_mtime,reverse=True)
    if not files: raise HTTPException(404,f"nessun file {prefix}")
    return json.loads(files[0].read_text(encoding="utf-8"))
def rows(base:Path,suf:Tuple[str,...],limit:int=200):
    out=[]
    for s in suf:
        for p in base.glob(f"*{s}"):
            if p.is_file(): out.append({"name":p.name,"size":p.stat().st_size,"mtime":datetime.fromtimestamp(p.stat().st_mtime,timezone.utc).isoformat(),"sha256":sha(p)})
    return sorted(out,key=lambda x:x["mtime"],reverse=True)[:limit]
def safe_iq(name:Optional[str])->Path:
    if name: p=IQ_DIR/Path(name).name
    else:
        fs=list(IQ_DIR.glob("*.iq8"))+list(IQ_DIR.glob("*.iq"))+list(IQ_DIR.glob("*.c8"))
        if not fs: raise HTTPException(404,"nessun IQ disponibile")
        p=sorted(fs,key=lambda x:x.stat().st_mtime,reverse=True)[0]
    p=p.resolve()
    if not str(p).startswith(str(IQ_DIR.resolve())) or not p.exists(): raise HTTPException(404,"IQ non trovato")
    return p
def load_iq(p:Path,max_samples:int):
    if not HAS_NUMPY: raise HTTPException(500,"numpy non disponibile")
    raw=np.fromfile(p,dtype=np.int8)
    if raw.size%2: raw=raw[:-1]
    raw=raw[:max_samples*2]
    return raw[0::2].astype(np.float32)/128.0 + 1j*raw[1::2].astype(np.float32)/128.0

class Settings(BaseModel):
    profile_id:str="ISM_24_UAV"
    start_hz:Optional[float]=None; stop_hz:Optional[float]=None; bin_hz:Optional[float]=None; bucket_hz:Optional[float]=None
    threshold_db:float=Field(8,ge=1,le=60); iterations:int=Field(8,ge=1,le=80); dwell_ms:int=Field(120,ge=0,le=5000); use_hackrf:bool=True
class BurstReq(BaseModel):
    filename:Optional[str]=None; sample_rate:float=Field(2_000_000,ge=10_000,le=50_000_000); max_seconds:float=Field(5,ge=.05,le=60)
    threshold_sigma:float=Field(6,ge=1,le=30); min_burst_us:float=Field(20,ge=1,le=1_000_000); merge_gap_us:float=Field(50,ge=0,le=1_000_000)

@router.get("/uav/page", response_class=HTMLResponse)
def page():
    p=ROOT/"frontend"/"public"/"uav_fhss_v584.html"
    if not p.exists(): raise HTTPException(404,f"Pagina non trovata: {p}")
    return HTMLResponse(p.read_text(encoding="utf-8",errors="ignore"))
@router.get("/uav/profiles")
def profiles(): return {"ok":True,"version":"5.8.4","mode":"RX_ONLY","profiles":PROFILES}
@router.get("/uav/selftest")
def selftest(): return {"ok":True,"version":"5.8.4","numpy":HAS_NUMPY,"profiles":list(PROFILES.keys()),"uav_dir":str(UAV_DIR)}
@router.post("/uav/sweep_band")
def sweep_band(req:Settings):
    prof=dict(PROFILES.get(req.profile_id,PROFILES["ISM_24_UAV"]))
    start=float(req.start_hz or prof["start_hz"]); stop=float(req.stop_hz or prof["stop_hz"]); bin_hz=float(req.bin_hz or prof["bin_hz"]); bucket_hz=float(req.bucket_hz or prof["bucket_hz"])
    if start<1e6 or stop>6e9 or stop<=start: raise HTTPException(400,"range HackRF valido 1 MHz-6 GHz, stop > start")
    snaps=[]; real=False
    for i in range(req.iterations):
        bins=[]; raw=None
        if req.use_hackrf and shutil.which("hackrf_sweep"):
            raw=run(["hackrf_sweep","-f",f"{start/1e6:.6f}:{stop/1e6:.6f}","-w",str(int(bin_hz)),"-1"])
            if raw["returncode"]==0:
                bins=parse_sweep(raw.get("stdout",""),start,stop); real=real or bool(bins)
        if not bins: bins=synthetic(start,stop,max(128,min(2048,int((stop-start)/max(bin_hz,1)))),i)
        pk=peaks(bins,req.threshold_db)
        snaps.append({"idx":i,"time":now(),"bins":bins,"peaks":pk,"dominant":pk[0] if pk else None,"raw_returncode":raw.get("returncode") if raw else None})
        if req.dwell_ms and i<req.iterations-1: time.sleep(req.dwell_ms/1000)
    return save("uav_sweep",{"ok":True,"version":"5.8.4","mode":"UAV_BAND_SWEEP","source_state":"REAL_HACKRF" if real else "SYNTHETIC_OR_EMPTY","rx_only":True,"profile_id":req.profile_id,"start_hz":start,"stop_hz":stop,"bin_hz":bin_hz,"bucket_hz":bucket_hz,"threshold_db":req.threshold_db,"iterations":req.iterations,"snapshots":snaps})
@router.post("/uav/hopping/analyze")
def hopping():
    sw=latest("uav_sweep"); bucket_hz=float(sw.get("bucket_hz",sw.get("channel_bucket_hz",1_000_000)))
    seq=[]; chans={}; prev=None; trans=0
    for s in sw.get("snapshots",[]):
        dom=s.get("dominant")
        if not dom: seq.append({"idx":s.get("idx"),"channel_hz":None}); continue
        ch=bucket(float(dom["freq_hz"]),bucket_hz); key=str(int(ch))
        rec=chans.setdefault(key,{"channel_hz":ch,"channel_mhz":round(ch/1e6,6),"hits":0,"max_db":-999,"vals":[]})
        rec["hits"]+=1; rec["max_db"]=max(rec["max_db"],float(dom["db"])); rec["vals"].append(float(dom["db"]))
        seq.append({"idx":s.get("idx"),"time":s.get("time"),"channel_hz":ch,"channel_mhz":round(ch/1e6,6),"peak_db":dom["db"]})
        if prev is not None and ch!=prev: trans+=1
        prev=ch
    rows=[]
    for v in chans.values():
        vals=v.pop("vals"); v["avg_db"]=round(sum(vals)/len(vals),2) if vals else None; rows.append(v)
    rows.sort(key=lambda x:x["hits"],reverse=True); valid=[x for x in seq if x.get("channel_hz") is not None]
    rate=trans/max(1,len(valid)-1); score=min(100.0,30*len(rows)+70*rate)
    lik="HIGH_FHSS_CANDIDATE" if len(rows)>=4 and rate>.35 else ("MEDIUM_HOPPING_OR_ADAPTIVE_LINK" if len(rows)>=2 and rate>.15 else ("FIXED_CHANNEL_OR_SINGLE_DOMINANT_CARRIER" if len(rows)==1 else "LOW_OR_INSUFFICIENT_DATA"))
    return save("uav_hopping_analysis",{"ok":True,"version":"5.8.4","mode":"UAV_FHSS_ANALYSIS","source_sweep":sw.get("name"),"profile_id":sw.get("profile_id"),"unique_channels":len(rows),"transitions":trans,"transition_rate":round(rate,4),"fhss_score":round(score,2),"likelihood":lik,"sequence":seq,"channels":rows,"note":"RF witness RX-only: hop channels/occupancy, non payload decoding."})
@router.post("/uav/burst/analyze_iq")
def burst(req:BurstReq):
    p=safe_iq(req.filename); iq=load_iq(p,int(req.sample_rate*req.max_seconds))
    env=np.abs(iq); power=env*env; med=float(np.median(power)); mad=float(np.median(np.abs(power-med)))+1e-12; th=med+req.threshold_sigma*1.4826*mad
    active=power>th; min_len=max(1,int(req.sample_rate*req.min_burst_us/1e6)); merge=int(req.sample_rate*req.merge_gap_us/1e6)
    segs=[]; i=0; n=active.size
    while i<n:
        if not active[i]: i+=1; continue
        a=i
        while i<n and active[i]: i+=1
        b=i
        if b-a>=min_len:
            if segs and a-segs[-1][1]<=merge: segs[-1]=(segs[-1][0],b)
            else: segs.append((a,b))
    bursts=[]
    for idx,(a,b) in enumerate(segs[:1000]):
        x=iq[a:b]; dur=(b-a)/req.sample_rate
        peak_off=peak_db=obw=0.0
        if x.size>=256:
            m=min(x.size,4096); m=2**int(math.floor(math.log2(m)))
            sp=np.fft.fftshift(np.fft.fft(x[:m]*np.hanning(m))); pwr=20*np.log10(np.abs(sp)+1e-12); freqs=np.fft.fftshift(np.fft.fftfreq(m,1/req.sample_rate)); pi=int(np.argmax(pwr)); peak_off=float(freqs[pi]); peak_db=float(pwr[pi])
            mask=pwr>=max(float(np.max(pwr))-20,float(np.median(pwr))+6); obw=float(freqs[mask][-1]-freqs[mask][0]) if np.any(mask) else 0.0
        bursts.append({"idx":idx,"start_s":round(a/req.sample_rate,9),"end_s":round(b/req.sample_rate,9),"duration_us":round(dur*1e6,3),"samples":b-a,"peak_mag":round(float(np.max(np.abs(x))),6),"rms_mag":round(float(np.sqrt(np.mean(np.abs(x)**2))),6),"peak_offset_hz":round(peak_off,3),"peak_db":round(peak_db,2),"estimated_obw_hz":round(obw,3)})
    intervals=[round((bursts[i]["start_s"]-bursts[i-1]["start_s"])*1e6,3) for i in range(1,len(bursts))]
    def st(v): return {"count":len(v),"min":round(min(v),3) if v else None,"max":round(max(v),3) if v else None,"mean":round(sum(v)/len(v),3) if v else None,"median":round(statistics.median(v),3) if v else None}
    duty=sum(x["duration_us"] for x in bursts)/(req.max_seconds*1e6) if req.max_seconds else 0
    return save("uav_burst_iq_analysis",{"ok":True,"version":"5.8.4","mode":"UAV_RF_BURST_PACKET_MEASUREMENT","source_iq":p.name,"source_sha256":sha(p),"sample_rate":req.sample_rate,"threshold":th,"burst_count":len(bursts),"duty_cycle_percent":round(duty*100,6),"duration_us_stats":st([x["duration_us"] for x in bursts]),"inter_burst_interval_us":st(intervals),"bursts":bursts,"measurement_note":"'packet' = burst RF envelope/IQ, non payload decoding."})
@router.post("/uav/link/report")
def link_report():
    def last_or_none(prefix):
        try: return latest(prefix)
        except Exception: return None
    hop=last_or_none("uav_hopping_analysis"); bur=last_or_none("uav_burst_iq_analysis")
    return save("uav_link_report",{"ok":True,"version":"5.8.4","mode":"UAV_GCS_LINK_RF_REPORT","rx_only":True,"hopping_summary":None if not hop else {"profile_id":hop.get("profile_id"),"unique_channels":hop.get("unique_channels"),"transitions":hop.get("transitions"),"likelihood":hop.get("likelihood"),"fhss_score":hop.get("fhss_score")},"burst_summary":None if not bur else {"source_iq":bur.get("source_iq"),"burst_count":bur.get("burst_count"),"duty_cycle_percent":bur.get("duty_cycle_percent"),"duration_us_stats":bur.get("duration_us_stats")},"tx_rx_measurement_matrix":[{"area":"GCS -> UAV uplink","rf_evidence":"burst/FHSS candidate, direction/RSSI needed"},{"area":"UAV -> GCS downlink","rf_evidence":"telemetry/video burst or wideband channel, direction/RSSI needed"},{"area":"Protocol metadata","rf_evidence":"use authorized GCS logs/MAVLink/PCAP, not RF-only payload extraction"}]})
@router.get("/uav/files")
def files(): return {"ok":True,"version":"5.8.4","uav":rows(UAV_DIR,(".json",)),"iq":rows(IQ_DIR,(".iq8",".iq",".c8")),"reports":rows(REPORT_DIR,(".json",))}
@router.get("/uav/file/{filename}")
def get_file(filename:str):
    name=Path(filename).name
    for base,media in ((UAV_DIR,"application/json"),(REPORT_DIR,"application/json"),(IQ_DIR,"application/octet-stream")):
        p=(base/name).resolve()
        if str(p).startswith(str(base.resolve())) and p.exists(): return FileResponse(p,media_type=media,filename=p.name)
    raise HTTPException(404,"file non trovato")
