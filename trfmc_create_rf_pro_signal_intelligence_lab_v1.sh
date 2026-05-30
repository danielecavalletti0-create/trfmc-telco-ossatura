#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/quality/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V1_$TS"
LATEST="$BASE/runtime/quality/latest_rf_pro_signal_intelligence_lab_v1"

DOSSIER="$BASE/runtime/quality/latest_orphan_consolidation_dossier_v1"
TRIAGE="$BASE/runtime/quality/latest_orphan_triage_board_v1"

REG="$PUBLIC/trfmc_portal_registry_unified.json"
V6R3="$PUBLIC/trfmc_official_safe_entrypoint_v6r3_command_center.html"
CONTROL="$PUBLIC/trfmc_integration_control_room.html"

ASSET_DIR="$PUBLIC/assets/trfmc_rf_pro_signal_intelligence"
CSS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v1.css"
JS="$ASSET_DIR/trfmc_rf_pro_signal_intelligence_v1.js"

PAGE="$PUBLIC/trfmc_rf_pro_signal_intelligence_lab_v1.html"
MANIFEST="$PUBLIC/trfmc_rf_pro_signal_intelligence_manifest_v1.json"

mkdir -p "$OUT" "$ASSET_DIR" "$BASE/runtime/backups" "$BASE/runtime/freezes" "$BASE/runtime/quality"
cd "$BASE"

echo "============================================================"
echo "TRFMC RF PRO SIGNAL INTELLIGENCE LAB V1"
echo "New controlled premium leaf · no orphan mutation · no shell mutation"
echo "============================================================"

if [ ! -f "$DOSSIER/summary.json" ]; then
  echo "ERRORE: manca dossier consolidamento orphan:"
  echo "$DOSSIER/summary.json"
  exit 10
fi

DOSSIER_RESULT="$(python3 - <<PY
import json
from pathlib import Path
print(json.loads(Path("$DOSSIER/summary.json").read_text()).get("result",""))
PY
)"

if [ "$DOSSIER_RESULT" != "PASS" ]; then
  echo "ERRORE: dossier non PASS: $DOSSIER_RESULT"
  exit 11
fi

echo
echo "[1/9] Snapshot + hash protetti"

BACKUP="$BASE/runtime/backups/TRFMC_BEFORE_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V1_$TS.tar.gz"
tar -czf "$BACKUP" frontend/public runtime/quality/latest_orphan_consolidation_dossier_v1 runtime/quality/latest_orphan_triage_board_v1 2>/dev/null || true
ls -lh "$BACKUP" | tee "$OUT/backup.txt"

{
  echo "V6R3_SHA_BEFORE=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_BEFORE=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_BEFORE=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/pre_sha.txt"

echo
echo "[2/9] Estraggo sorgenti orphan RF PRO read-only"

python3 - "$PUBLIC" "$TRIAGE" "$DOSSIER" "$OUT" <<'PY'
import csv, json, hashlib, re, html, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
triage = Path(sys.argv[2])
dossier = Path(sys.argv[3])
out = Path(sys.argv[4])

plan = triage / "orphan_triage_plan.tsv"
rows = []

with plan.open(errors="ignore") as fp:
    reader = csv.DictReader(fp, delimiter="\t")
    for r in reader:
        if r.get("action") == "REBUILD_AS_LEAF":
            rows.append(r)

def extract(path):
    if not path.exists():
        return {
            "exists": False,
            "sha256": "",
            "title": "",
            "h1": [],
            "h2": [],
            "word_estimate": 0,
            "keywords": []
        }
    data = path.read_bytes()
    txt = data.decode("utf-8", errors="ignore")
    title = ""
    m = re.search(r"<title[^>]*>(.*?)</title>", txt, re.I | re.S)
    if m:
        title = html.unescape(re.sub(r"\s+", " ", m.group(1)).strip())
    h1 = [html.unescape(re.sub(r"<[^>]+>", " ", x)).strip() for x in re.findall(r"<h1[^>]*>(.*?)</h1>", txt, re.I | re.S)]
    h2 = [html.unescape(re.sub(r"<[^>]+>", " ", x)).strip() for x in re.findall(r"<h2[^>]*>(.*?)</h2>", txt, re.I | re.S)]
    words = re.findall(r"\b[A-Za-z0-9_+\-/]{3,}\b", re.sub(r"<[^>]+>", " ", txt))
    keys = []
    for k in ["FFT","IQ","I/Q","FHSS","burst","demod","waterfall","spectrum","SNR","EVM","ACLR","OBW","QPSK","QAM","OFDM","UAV","hop"]:
        if re.search(re.escape(k), txt, re.I):
            keys.append(k)
    return {
        "exists": True,
        "sha256": hashlib.sha256(data).hexdigest(),
        "title": title,
        "h1": h1[:8],
        "h2": h2[:14],
        "word_estimate": len(words),
        "keywords": keys
    }

sources = []
for r in rows:
    url = r.get("url","")
    f = public / url.lstrip("/")
    meta = extract(f)
    sources.append({
        "url": url,
        "title": r.get("title",""),
        "reason": r.get("reason",""),
        "target": r.get("target",""),
        "size": int(r.get("size") or 0),
        **meta
    })

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_RF_PRO_REBUILD_SOURCE_SCAN_V1",
    "source_orphans": len(sources),
    "expected_source_orphans": 4,
    "all_sources_exist": all(s.get("exists") for s in sources),
    "total_size": sum(s.get("size",0) for s in sources),
    "total_word_estimate": sum(s.get("word_estimate",0) for s in sources),
    "policy": "Read-only source scan. No orphan file changed."
}

(out / "rf_pro_rebuild_sources.json").write_text(json.dumps(sources, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "rf_pro_source_scan_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

with (out / "rf_pro_rebuild_sources.tsv").open("w", encoding="utf-8") as fp:
    fp.write("url\texists\tsize\tword_estimate\tkeywords\tsha256\ttitle\treason\n")
    for s in sources:
        fp.write(f'{s["url"]}\t{s["exists"]}\t{s["size"]}\t{s["word_estimate"]}\t{",".join(s["keywords"])}\t{s["sha256"]}\t{s["title"]}\t{s["reason"]}\n')

print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "[3/9] Creo CSS RF PRO cinematic/instrument-grade"

cat > "$CSS" <<'CSS'
/*
 TRFMC RF PRO Signal Intelligence Lab V1
 Instrument-grade cinematic UI.
 No CDN. No iframe. No external refs.
*/

:root{
  --rfp-bg:#010409;
  --rfp-panel:rgba(2,18,30,.92);
  --rfp-cyan:#00e5ff;
  --rfp-green:#75ff5b;
  --rfp-warn:#ffd84d;
  --rfp-red:#ff3d7f;
  --rfp-text:#dffaff;
  --rfp-muted:#8fb8c8;
}

.rfpro-root{
  min-height:100vh;
  color:var(--rfp-text);
  background:
    radial-gradient(circle at 82% 8%, rgba(0,229,255,.18), transparent 30%),
    radial-gradient(circle at 14% 88%, rgba(117,255,91,.07), transparent 28%),
    linear-gradient(145deg,#020812,#010409 60%,#000);
  font-family:ui-monospace,Consolas,monospace;
}

.rfpro-topology{
  position:relative;
  z-index:1;
  display:grid;
  grid-template-columns:390px 1fr;
  gap:8px;
  padding:8px;
  min-height:calc(100vh - 78px);
}

.rfpro-panel{
  border:1px solid rgba(0,229,255,.28);
  border-radius:14px;
  background:
    linear-gradient(145deg,rgba(2,18,30,.92),rgba(1,7,13,.96)),
    radial-gradient(circle at 70% 0%,rgba(0,229,255,.08),transparent 35%);
  box-shadow:
    0 0 38px rgba(0,229,255,.12),
    inset 0 0 24px rgba(0,229,255,.05),
    0 20px 54px rgba(0,0,0,.42);
  padding:9px;
}

.rfpro-title{
  color:var(--rfp-cyan);
  font-size:15px;
  letter-spacing:.12em;
  text-transform:uppercase;
  text-shadow:0 0 16px rgba(0,229,255,.45);
}

.rfpro-sub{
  color:var(--rfp-muted);
  font-size:10px;
  line-height:1.5;
  margin-top:4px;
}

.rfpro-kpis{
  display:grid;
  grid-template-columns:repeat(2,1fr);
  gap:7px;
  margin-top:8px;
}

.rfpro-kpi{
  border:1px solid rgba(0,229,255,.24);
  background:rgba(0,229,255,.045);
  border-radius:10px;
  padding:7px;
}

.rfpro-kpi small{
  display:block;
  color:var(--rfp-muted);
  text-transform:uppercase;
  font-size:8px;
}

.rfpro-kpi b{
  display:block;
  color:var(--rfp-green);
  font-size:16px;
  margin-top:2px;
}

.rfpro-grid{
  display:grid;
  grid-template-columns:1.2fr .8fr;
  gap:8px;
}

.rfpro-stack{
  display:grid;
  gap:8px;
}

.rfpro-card{
  border:1px solid rgba(0,229,255,.22);
  border-radius:12px;
  background:rgba(0,229,255,.035);
  padding:8px;
}

.rfpro-card h3{
  color:var(--rfp-warn);
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.08em;
  margin:0 0 6px 0;
}

.rfpro-card p,
.rfpro-formulas{
  color:var(--rfp-text);
  font-size:10px;
  line-height:1.52;
}

.rfpro-formulas{
  white-space:pre-wrap;
}

.rfpro-canvas{
  width:100%;
  height:230px;
  display:block;
  background:#010409;
  border:1px solid rgba(0,229,255,.20);
  border-radius:11px;
}

.rfpro-canvas.tall{
  height:330px;
}

.rfpro-canvas.small{
  height:150px;
}

.rfpro-assets{
  display:grid;
  grid-template-columns:1fr 1fr;
  gap:8px;
}

.rfpro-assets trfmc-visual-asset:first-child{
  grid-column:1 / -1;
}

.rfpro-pill{
  display:inline-block;
  border:1px solid rgba(117,255,91,.34);
  background:rgba(117,255,91,.07);
  color:var(--rfp-green);
  border-radius:7px;
  padding:2px 6px;
  margin:2px 3px 2px 0;
  font-size:9px;
}

.rfpro-source{
  font-size:9px;
  color:var(--rfp-muted);
  border-bottom:1px solid rgba(0,229,255,.15);
  padding:5px 0;
}

.rfpro-source a{
  color:var(--rfp-cyan);
}

@media(max-width:1350px){
  .rfpro-topology{grid-template-columns:1fr}
  .rfpro-grid{grid-template-columns:1fr}
}

@media(max-width:900px){
  .rfpro-assets{grid-template-columns:1fr}
  .rfpro-kpis{grid-template-columns:1fr}
}
CSS

echo
echo "[4/9] Creo JS Web Component + synthetic RF engine"

cat > "$JS" <<'JS'
/*
 TRFMC RF PRO Signal Intelligence Lab V1
 Synthetic/lab-only RF visual engine.
 No network fetch. No external dependency.
*/

(function(){
  "use strict";

  const TAU = Math.PI * 2;

  function fit(c){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    const w = Math.max(2, Math.floor(c.clientWidth * dpr));
    const h = Math.max(2, Math.floor(c.clientHeight * dpr));
    if(c.width !== w || c.height !== h){ c.width = w; c.height = h; }
    const ctx = c.getContext("2d");
    return {ctx,w,h,dpr};
  }

  function grid(ctx,w,h,dpr){
    ctx.strokeStyle = "rgba(0,229,255,.095)";
    ctx.lineWidth = 1*dpr;
    for(let i=0;i<12;i++){
      const x = w*i/11;
      ctx.beginPath(); ctx.moveTo(x,0); ctx.lineTo(x,h); ctx.stroke();
    }
    for(let i=0;i<7;i++){
      const y = h*i/6;
      ctx.beginPath(); ctx.moveTo(0,y); ctx.lineTo(w,y); ctx.stroke();
    }
  }

  function bg(ctx,w,h){
    const g = ctx.createLinearGradient(0,0,0,h);
    g.addColorStop(0,"#061827");
    g.addColorStop(1,"#010409");
    ctx.fillStyle = g;
    ctx.fillRect(0,0,w,h);
  }

  function text(ctx,dpr,label,x,y,color){
    ctx.fillStyle = color || "#8fb8c8";
    ctx.font = `${10*dpr}px ui-monospace,Consolas,monospace`;
    ctx.fillText(label,x,y);
  }

  function spectrum(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    ctx.lineWidth = 2*dpr;
    ctx.strokeStyle = "#00e5ff";
    ctx.beginPath();
    for(let i=0;i<900;i++){
      const f=i/899;
      const x=w*f;
      let y=h*.74 + Math.sin(i*.03+t*1.2)*h*.012;
      y -= Math.exp(-Math.pow(f-.19,2)/.00055)*h*.25;
      y -= Math.exp(-Math.pow(f-.33,2)/.00075)*h*.17;
      y -= Math.exp(-Math.pow(f-.51,2)/.00065)*h*.38;
      y -= Math.exp(-Math.pow(f-.68,2)/.00090)*h*.23;
      y -= Math.exp(-Math.pow(f-.84,2)/.00050)*h*.14;
      if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
    }
    ctx.stroke();

    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<5;i++){
      const cx=[.19,.33,.51,.68,.84][i]*w;
      const a=.08+.05*Math.sin(t+i);
      const rg=ctx.createRadialGradient(cx,h*.54,2*dpr,cx,h*.54,h*.18);
      rg.addColorStop(0,`rgba(117,255,91,${a})`);
      rg.addColorStop(1,"rgba(117,255,91,0)");
      ctx.fillStyle=rg;
      ctx.fillRect(cx-w*.08,h*.25,w*.16,h*.50);
    }
    ctx.restore();

    text(ctx,dpr,"SPECTRUM · SYNTHETIC RF SCENE · FFT/RBW/OBW/ACLR",10*dpr,18*dpr,"#8fb8c8");
    text(ctx,dpr,"RBW 30 kHz · Span 40 MHz · Noise floor -92 dBm",10*dpr,h-12*dpr,"#75ff5b");
  }

  function waterfall(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h);

    const rows=80, cols=180;
    const cw=w/cols, rh=h/rows;
    for(let y=0;y<rows;y++){
      for(let x=0;x<cols;x++){
        const f=x/cols;
        const age=y/rows;
        const hop = Math.floor((t*2 + y*.05))%8;
        const center = (.10 + ((hop*23)%80)/100);
        const burst1 = Math.exp(-Math.pow(f-center,2)/.0008);
        const burst2 = Math.exp(-Math.pow(f-(.25+.55*Math.abs(Math.sin(t*.2+y*.01))),2)/.0012);
        const noise = .08*Math.sin(x*.31+y*.21+t);
        const v = Math.max(0, Math.min(1, burst1*.95 + burst2*.35 + noise + .05));
        const r = Math.floor(20 + 40*v);
        const g = Math.floor(55 + 200*v);
        const b = Math.floor(80 + 175*v);
        ctx.fillStyle = `rgba(${r},${g},${b},${.35+.55*v})`;
        ctx.fillRect(x*cw,y*rh,cw+1,rh+1);
      }
    }

    grid(ctx,w,h,dpr);
    text(ctx,dpr,"WATERFALL · HOP/BURST OCCUPANCY MAP",10*dpr,18*dpr,"#dffaff");
  }

  function constellation(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    const cx=w*.5, cy=h*.52, scale=Math.min(w,h)*.25;
    ctx.strokeStyle="rgba(0,229,255,.22)";
    ctx.beginPath(); ctx.moveTo(cx, h*.12); ctx.lineTo(cx,h*.90); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(w*.12, cy); ctx.lineTo(w*.88,cy); ctx.stroke();

    const pts=[[-1,-1],[-1,1],[1,-1],[1,1]];
    ctx.save();
    ctx.globalCompositeOperation="lighter";
    for(let i=0;i<720;i++){
      const p=pts[i%4];
      const jitter=.10*Math.sin(t*2+i*.61);
      const jitter2=.10*Math.cos(t*1.7+i*.47);
      const x=cx+(p[0]+jitter)*scale;
      const y=cy+(p[1]+jitter2)*scale;
      ctx.fillStyle=i%5?"rgba(0,229,255,.16)":"rgba(117,255,91,.20)";
      ctx.beginPath(); ctx.arc(x,y,2.1*dpr,0,TAU); ctx.fill();
    }
    ctx.restore();

    text(ctx,dpr,"I/Q CONSTELLATION · QPSK SYNTHETIC · EVM TRACE",10*dpr,18*dpr,"#8fb8c8");
    text(ctx,dpr,"EVM 2.8% · CFO compensated · phase noise synthetic",10*dpr,h-12*dpr,"#75ff5b");
  }

  function timeline(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    const t=ms*.001;
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    const lanes=8;
    for(let l=0;l<lanes;l++){
      const y=h*(.18 + l*.085);
      ctx.strokeStyle="rgba(0,229,255,.12)";
      ctx.beginPath(); ctx.moveTo(w*.06,y); ctx.lineTo(w*.94,y); ctx.stroke();
      text(ctx,dpr,`CH${l+1}`,10*dpr,y+3*dpr,"#8fb8c8");
    }

    for(let i=0;i<42;i++){
      const lane=(i*5+Math.floor(t*2))%lanes;
      const x=w*((i*.067 + t*.055)%1);
      const y=h*(.18 + lane*.085)-8*dpr;
      const bw=w*(.018 + ((i%4)*.006));
      ctx.fillStyle=i%3===0?"rgba(255,216,77,.55)":i%3===1?"rgba(0,229,255,.55)":"rgba(117,255,91,.50)";
      ctx.fillRect(x,y,bw,16*dpr);
      ctx.strokeStyle="rgba(255,255,255,.22)";
      ctx.strokeRect(x,y,bw,16*dpr);
    }

    text(ctx,dpr,"FHSS / BURST TIMELINE · LAB-SYNTHETIC HOP SEQUENCE",10*dpr,18*dpr,"#dffaff");
  }

  function formula(c,ms){
    const {ctx,w,h,dpr}=fit(c);
    bg(ctx,w,h); grid(ctx,w,h,dpr);

    ctx.fillStyle="#00e5ff";
    ctx.font=`${12*dpr}px ui-monospace,Consolas,monospace`;
    const lines=[
      "FFT: X[k] = Σ x[n]·e^(-j2πkn/N)",
      "RBW ≈ Fs/N · window_ENBW",
      "SNR = Psignal / Pnoise",
      "EVM = RMS(error_vector) / RMS(reference_vector)",
      "OBW: occupied bandwidth containing selected integrated power",
      "ACLR = Pchannel / Padjacent",
      "FHSS dwell = burst_time / hop_period"
    ];
    lines.forEach((line,i)=>{
      ctx.fillStyle=i%2?"#75ff5b":"#dffaff";
      ctx.fillText(line,18*dpr,(28+i*20)*dpr);
    });
  }

  class TrfmcRfProLab extends HTMLElement{
    connectedCallback(){
      this.innerHTML = `
        <section class="rfpro-root">
          <div class="rfpro-topology">
            <aside class="rfpro-panel">
              <div class="rfpro-title">RF PRO Signal Intelligence Lab</div>
              <div class="rfpro-sub">
                Controlled synthetic/lab-only signal laboratory. Built from RF PRO orphan dossier without mutating legacy pages.
              </div>
              <div class="rfpro-kpis">
                <div class="rfpro-kpi"><small>Mode</small><b>LAB</b></div>
                <div class="rfpro-kpi"><small>Input</small><b>IQ/SYN</b></div>
                <div class="rfpro-kpi"><small>FFT</small><b>LIVE</b></div>
                <div class="rfpro-kpi"><small>FHSS</small><b>TRACE</b></div>
                <div class="rfpro-kpi"><small>EVM</small><b>2.8%</b></div>
                <div class="rfpro-kpi"><small>Gate</small><b>PASS</b></div>
              </div>

              <div class="rfpro-card" style="margin-top:8px">
                <h3>Operational doctrine</h3>
                <p>
                  This leaf does not intercept, decode or operate on third-party RF traffic. It visualizes synthetic or lab-owned IQ concepts:
                  spectrum occupancy, burst timing, FHSS patterning, modulation quality and evidence-grade RF measurements.
                </p>
              </div>

              <div class="rfpro-card">
                <h3>RF PRO closure</h3>
                <span class="rfpro-pill">FFT</span>
                <span class="rfpro-pill">Waterfall</span>
                <span class="rfpro-pill">I/Q</span>
                <span class="rfpro-pill">FHSS</span>
                <span class="rfpro-pill">Burst</span>
                <span class="rfpro-pill">EVM</span>
                <span class="rfpro-pill">ACLR</span>
                <span class="rfpro-pill">OBW</span>
              </div>

              <div class="rfpro-card">
                <h3>Rebuild sources</h3>
                <div class="rfpro-source"><a href="/signal_demod_v581.html">/signal_demod_v581.html</a></div>
                <div class="rfpro-source"><a href="/signal_workbench_v580.html">/signal_workbench_v580.html</a></div>
                <div class="rfpro-source"><a href="/signal_workbench_v582.html">/signal_workbench_v582.html</a></div>
                <div class="rfpro-source"><a href="/uav_fhss_v584.html">/uav_fhss_v584.html</a></div>
              </div>
            </aside>

            <main class="rfpro-panel">
              <div class="rfpro-grid">
                <div class="rfpro-stack">
                  <div class="rfpro-card">
                    <h3>Vector Spectrum Analyzer</h3>
                    <canvas class="rfpro-canvas tall" data-rfpro="spectrum"></canvas>
                  </div>
                  <div class="rfpro-card">
                    <h3>Waterfall / Occupancy</h3>
                    <canvas class="rfpro-canvas" data-rfpro="waterfall"></canvas>
                  </div>
                  <div class="rfpro-card">
                    <h3>FHSS / Burst Timeline</h3>
                    <canvas class="rfpro-canvas small" data-rfpro="timeline"></canvas>
                  </div>
                </div>

                <div class="rfpro-stack">
                  <div class="rfpro-card">
                    <h3>Visual asset engine</h3>
                    <div class="rfpro-assets">
                      <trfmc-visual-asset kind="spectrum-scope" data-size="medium" title="RF Spectrum Scope"></trfmc-visual-asset>
                      <trfmc-visual-asset kind="cyber-evidence" data-size="small" title="Evidence Chain"></trfmc-visual-asset>
                      <trfmc-visual-asset kind="core-map" data-size="small" title="Signal-to-NOC Correlation"></trfmc-visual-asset>
                    </div>
                  </div>

                  <div class="rfpro-card">
                    <h3>I/Q constellation</h3>
                    <canvas class="rfpro-canvas" data-rfpro="constellation"></canvas>
                  </div>

                  <div class="rfpro-card">
                    <h3>Formula cockpit</h3>
                    <canvas class="rfpro-canvas small" data-rfpro="formula"></canvas>
                  </div>

                  <div class="rfpro-card">
                    <h3>Engineering formulas</h3>
                    <div class="rfpro-formulas formulaLive">FFT: X[k] = Σ x[n]·e^(-j2πkn/N)
RBW ≈ Fs/N · ENBW(window)
SNR = Psignal / Pnoise
EVM = RMS(error_vector) / RMS(reference_vector)
ACLR = Pchannel / Padjacent
OBW = bandwidth containing integrated occupied power
FHSS dwell ratio = burst_time / hop_period</div>
                  </div>
                </div>
              </div>
            </main>
          </div>
        </section>
      `;
      this.start();
    }

    start(){
      const canvases = Array.from(this.querySelectorAll("canvas[data-rfpro]"));
      const draw = (ms)=>{
        for(const c of canvases){
          const mode = c.dataset.rfpro;
          if(mode === "spectrum") spectrum(c,ms);
          else if(mode === "waterfall") waterfall(c,ms);
          else if(mode === "constellation") constellation(c,ms);
          else if(mode === "timeline") timeline(c,ms);
          else if(mode === "formula") formula(c,ms);
        }
        this._raf = requestAnimationFrame(draw);
      };
      this._raf = requestAnimationFrame(draw);
    }

    disconnectedCallback(){
      if(this._raf) cancelAnimationFrame(this._raf);
    }
  }

  if(!customElements.get("trfmc-rf-pro-lab")){
    customElements.define("trfmc-rf-pro-lab", TrfmcRfProLab);
  }
})();
JS

echo
echo "[5/9] Creo pagina RF PRO Signal Intelligence Lab"

python3 - "$OUT" "$PAGE" "$MANIFEST" <<'PY'
import json, html, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
page = Path(sys.argv[2])
manifest = Path(sys.argv[3])

source_summary = json.loads((out / "rf_pro_source_scan_summary.json").read_text(errors="ignore"))
sources = json.loads((out / "rf_pro_rebuild_sources.json").read_text(errors="ignore"))

manifest_data = {
    "id": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V1",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v1.html",
    "source_orphans": [s["url"] for s in sources],
    "source_summary": source_summary,
    "mode": "synthetic_lab_only",
    "capabilities": [
        "spectrum_analyzer",
        "waterfall_occupancy",
        "iq_constellation",
        "fhss_burst_timeline",
        "formula_cockpit",
        "visual_asset_engine_binding"
    ],
    "policy": "New premium leaf. Orphan pages are not modified. V6R3 and Control Room are protected."
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

src_rows = ""
for s in sources:
    src_rows += f'''
<tr>
<td><a href="{html.escape(s["url"])}">{html.escape(s["url"])}</a></td>
<td>{html.escape(str(s["exists"]))}</td>
<td>{html.escape(str(s["word_estimate"]))}</td>
<td>{html.escape(",".join(s["keywords"]))}</td>
<td>{html.escape(s["sha256"][:16])}…</td>
</tr>
'''

page.write_text(f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC RF PRO Signal Intelligence Lab V1</title>
<link rel="stylesheet" href="/assets/trfmc_design_system/trfmc_leaf_master_v1.css">
<link rel="stylesheet" href="/assets/trfmc_visual_xp/trfmc_visual_xp_v1.css">
<link rel="stylesheet" href="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.css">
<link rel="stylesheet" href="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.css">
<link rel="stylesheet" href="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.css">
<link rel="stylesheet" href="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v1.css">
<style>
.source-panel{{position:relative;z-index:1;margin:8px;border:1px solid rgba(0,229,255,.24);border-radius:12px;background:rgba(0,229,255,.035);padding:8px}}
.source-panel h2{{color:#00e5ff;font-size:13px;text-transform:uppercase;letter-spacing:.10em}}
table{{width:100%;border-collapse:collapse;font-family:ui-monospace,Consolas,monospace;font-size:10px}}
th,td{{border-bottom:1px solid rgba(0,229,255,.18);padding:6px;text-align:left;vertical-align:top}}
th{{color:#00e5ff;background:rgba(0,229,255,.06)}}
</style>
</head>
<body class="trfmc-leaf trfmc-vxp trfmc-gpu-v2 trfmc-soul-v1">
<header class="leaf-top">
  <div>
    <div class="leaf-title">TRFMC RF PRO Signal Intelligence Lab V1</div>
    <div class="leaf-sub">Premium RF laboratory: spectrum, waterfall, I/Q, FHSS, burst analysis, formula cockpit, synthetic/lab-only signal engine</div>
  </div>
  <div class="leaf-actions">
    <a class="leaf-btn" href="/trfmc_post_promotion_control_center_v1.html">Governance</a>
    <a class="leaf-btn" href="/trfmc_rf_spectrum_lab_v1.html">RF Spectrum Lab</a>
    <a class="leaf-btn" href="/trfmc_orphan_consolidation_dossier_v1.html">Dossier</a>
    <a class="leaf-btn" href="/trfmc_rf_pro_signal_intelligence_manifest_v1.json">Manifest</a>
  </div>
</header>

<trfmc-rf-pro-lab></trfmc-rf-pro-lab>

<section class="source-panel">
<h2>Read-only rebuild source evidence</h2>
<table>
<thead><tr><th>Source orphan</th><th>Exists</th><th>Words</th><th>RF keywords</th><th>SHA256</th></tr></thead>
<tbody>{src_rows}</tbody>
</table>
</section>

<script src="/assets/trfmc_gpu_visual_runtime/trfmc_gpu_visual_runtime_v2.js"></script>
<script src="/assets/trfmc_visual_asset_engine/trfmc_visual_asset_engine_v3.js"></script>
<script src="/assets/trfmc_soul_runtime/trfmc_soul_runtime_v1.js"></script>
<script src="/assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v1.js"></script>
</body>
</html>
''', encoding="utf-8")

print(json.dumps(manifest_data, indent=2, ensure_ascii=False))
PY

echo
echo "[6/9] Registro nuova leaf premium nel registry"

python3 - "$PUBLIC" "$REG" <<'PY'
import json, re, sys
from pathlib import Path
from datetime import datetime, timezone

public = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

reg = json.loads(reg_path.read_text(errors="ignore"))
by_url = {p.get("url"): p for p in reg.get("pages", []) if p.get("url")}

target = public / "trfmc_rf_pro_signal_intelligence_lab_v1.html"
txt = target.read_text(errors="ignore")

by_url["/trfmc_rf_pro_signal_intelligence_lab_v1.html"] = {
    "class": "leaf_operational_candidate",
    "name": "trfmc_rf_pro_signal_intelligence_lab_v1.html",
    "url": "/trfmc_rf_pro_signal_intelligence_lab_v1.html",
    "size": target.stat().st_size,
    "domain": "rf",
    "premium_leaf": True,
    "rf_pro_rebuild": True,
    "canvas": True,
    "web_component": True,
    "has_iframe": False,
    "external_refs": 0,
    "refs_count": len(re.findall(r'href=|src=', txt, re.I)),
    "upgrade": "RF PRO Signal Intelligence Lab V1"
}

reg["pages"] = list(by_url.values())

counts = {}
for p in reg["pages"]:
    c = p.get("class", "unknown")
    counts[c] = counts.get(c, 0) + 1

counts["total_html"] = len([p for p in reg["pages"] if str(p.get("url","")).endswith(".html")])
for k in ["official_shell", "service", "leaf_operational_candidate", "shell_or_legacy_container", "orphan_or_legacy_candidate"]:
    counts.setdefault(k, 0)

reg["counts"] = counts
reg["last_rf_pro_signal_intelligence_lab_v1_update"] = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "page": "/trfmc_rf_pro_signal_intelligence_lab_v1.html",
    "policy": "New leaf only. Orphan pages unchanged. V6R3 and Control Room protected."
}

reg_path.write_text(json.dumps(reg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(counts, indent=2, ensure_ascii=False))
PY

echo
echo "[7/9] HTTP + external/iframe/content gate"

{
  printf "url\tstatus\tbytes\n"
  for u in \
    /trfmc_rf_pro_signal_intelligence_lab_v1.html \
    /trfmc_rf_pro_signal_intelligence_manifest_v1.json \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v1.css \
    /assets/trfmc_rf_pro_signal_intelligence/trfmc_rf_pro_signal_intelligence_v1.js \
    /trfmc_orphan_consolidation_dossier_v1.html \
    /trfmc_portal_registry_unified.json \
    /trfmc_official_safe_entrypoint_v6r3_command_center.html \
    /trfmc_integration_control_room.html
  do
    resp="$(curl -sS -o /dev/null -w "%{http_code} %{size_download}" --max-time 8 "http://127.0.0.1:5173$u" 2>/dev/null || true)"
    code="$(printf '%s' "$resp" | awk '{print $1}')"
    bytes="$(printf '%s' "$resp" | awk '{print $2}')"
    [ -n "$code" ] || code="000"
    [ -n "$bytes" ] || bytes="0"
    printf "%s\t%s\t%s\n" "$u" "$code" "$bytes"
  done
} | tee "$OUT/http.tsv"

: > "$OUT/external_refs.txt"
: > "$OUT/iframe_refs.txt"
: > "$OUT/content_checks.txt"

for f in "$PAGE" "$MANIFEST" "$CSS" "$JS"; do
  grep -nEi '(href|src|url|@import)[^"\047]*(https?://|//)|https?://|//cdn\.|unpkg\.com|jsdelivr\.net|cdnjs\.cloudflare\.com' "$f" >> "$OUT/external_refs.txt" 2>/dev/null || true
  grep -nEi '<iframe' "$f" >> "$OUT/iframe_refs.txt" 2>/dev/null || true
done

for token in \
  "TRFMC RF PRO Signal Intelligence Lab V1" \
  "customElements.define" \
  "trfmc-rf-pro-lab" \
  "SPECTRUM" \
  "WATERFALL" \
  "I/Q CONSTELLATION" \
  "FHSS" \
  "EVM" \
  "ACLR" \
  "OBW" \
  "formulaLive" \
  "trfmc-visual-asset" \
  "synthetic_lab_only"
do
  if grep -Rqs "$token" "$PAGE" "$MANIFEST" "$CSS" "$JS"; then
    echo "OK: $token" >> "$OUT/content_checks.txt"
  else
    echo "MISS: $token" >> "$OUT/content_checks.txt"
  fi
done

echo
echo "[8/9] Summary"

{
  cat "$OUT/pre_sha.txt"
  echo "V6R3_SHA_AFTER=$(sha256sum "$V6R3" | awk '{print $1}')"
  echo "CONTROL_SHA_AFTER=$(sha256sum "$CONTROL" | awk '{print $1}')"
  echo "REG_SHA_AFTER=$(sha256sum "$REG" | awk '{print $1}')"
} > "$OUT/sha_compare.txt"

python3 - "$OUT" "$REG" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone

out = Path(sys.argv[1])
reg_path = Path(sys.argv[2])

http = []
for line in (out / "http.tsv").read_text(errors="ignore").splitlines()[1:]:
    p = line.split("\t")
    if len(p) >= 3:
        http.append({"url": p[0], "status": p[1], "bytes": p[2]})

non200 = sum(1 for r in http if r["status"] != "200")
ext = sum(1 for x in (out / "external_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
ifr = sum(1 for x in (out / "iframe_refs.txt").read_text(errors="ignore").splitlines() if x.strip())
miss = sum(1 for x in (out / "content_checks.txt").read_text(errors="ignore").splitlines() if x.startswith("MISS:"))

src = json.loads((out / "rf_pro_source_scan_summary.json").read_text(errors="ignore"))

sha = {}
for line in (out / "sha_compare.txt").read_text(errors="ignore").splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        sha[k] = v

protected_ok = (
    sha.get("V6R3_SHA_BEFORE") == sha.get("V6R3_SHA_AFTER")
    and sha.get("CONTROL_SHA_BEFORE") == sha.get("CONTROL_SHA_AFTER")
)
registry_changed = sha.get("REG_SHA_BEFORE") != sha.get("REG_SHA_AFTER")
reg = json.loads(reg_path.read_text(errors="ignore"))

summary = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "operation": "TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V1",
    "http_non_200": non200,
    "external_refs": ext,
    "iframe_refs": ifr,
    "content_check_miss": miss,
    "source_orphans": src.get("source_orphans"),
    "all_sources_exist": src.get("all_sources_exist"),
    "protected_v6r3_and_control_files_unchanged": protected_ok,
    "registry_changed_intentionally": registry_changed,
    "registry_total_html": reg.get("counts",{}).get("total_html"),
    "registry_counts": reg.get("counts",{}),
    "new_leaf": "/trfmc_rf_pro_signal_intelligence_lab_v1.html",
    "result": "PASS" if non200 == 0 and ext == 0 and ifr == 0 and miss == 0 and protected_ok and registry_changed and src.get("source_orphans") == 4 else "WARN",
    "policy": "New premium RF PRO leaf. No orphan mutation. No V6R3/Control Room mutation."
}

(out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
(out / "result.flag").write_text(summary["result"] + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

rm -rf "$LATEST"
ln -s "$OUT" "$LATEST"

echo
echo "[9/9] Freeze se PASS"

if grep -q '^PASS$' "$OUT/result.flag"; then
  FREEZE="$BASE/runtime/freezes/TRFMC_RF_PRO_SIGNAL_INTELLIGENCE_LAB_V1_PASS_$TS.tar.gz"
  tar -czf "$FREEZE" \
    frontend/public/trfmc_rf_pro_signal_intelligence_lab_v1.html \
    frontend/public/trfmc_rf_pro_signal_intelligence_manifest_v1.json \
    frontend/public/assets/trfmc_rf_pro_signal_intelligence \
    frontend/public/trfmc_portal_registry_unified.json \
    runtime/quality/latest_rf_pro_signal_intelligence_lab_v1 \
    2>/dev/null || true
  ls -lh "$FREEZE" | tee "$OUT/freeze.txt"
else
  echo "WARN: freeze non creato perché result != PASS"
fi

echo
echo "============================================================"
cat "$OUT/summary.json" | python3 -m json.tool
echo
column -t -s $'\t' "$OUT/http.tsv"
echo
echo "=== SOURCE ORPHANS ==="
column -t -s $'\t' "$OUT/rf_pro_rebuild_sources.tsv"
echo
echo "=== CONTENT CHECKS ==="
cat "$OUT/content_checks.txt"
echo
echo "=== SHA ==="
cat "$OUT/sha_compare.txt"
echo
echo "Apri:"
echo "http://127.0.0.1:5173/trfmc_rf_pro_signal_intelligence_lab_v1.html"
echo "============================================================"
