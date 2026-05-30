#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
PUBLIC="$BASE/frontend/public"
RUNTIME="$BASE/runtime/engine_promotion"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$RUNTIME/TRFMC_ENGINE_PROMOTION_BOARD_$TS"

mkdir -p "$OUT" "$PUBLIC"

echo "============================================================"
echo "TRFMC ENGINE PROMOTION BOARD V1"
echo "============================================================"
date
echo "BASE=$BASE"
echo "OUT=$OUT"

cd "$BASE"

python3 - <<'PY' "$BASE" "$PUBLIC" "$OUT"
from pathlib import Path
import sys, json, html

base = Path(sys.argv[1])
public = Path(sys.argv[2])
out = Path(sys.argv[3])

registry_path = public / "trfmc_domain_registry_v1.json"
if not registry_path.exists():
    raise SystemExit("ERRORE: manca frontend/public/trfmc_domain_registry_v1.json. Crea prima il Domain Registry.")

registry = json.loads(registry_path.read_text())

domains = registry.get("domains", [])
pages = registry.get("pages", [])

action_rank = {
    "PROMOTE": 0,
    "ENGINE": 1,
    "FUSE": 2,
    "REWRITE": 3,
    "ARCHIVE": 4
}

engine_objects = {
    "01_Mission_Control": [
        "Lab State Matrix",
        "Open5GS / UERANSIM Monitor",
        "HackRF / SDR Control Plane",
        "Alarm Correlation Wall",
        "KPI Live Engine"
    ],
    "02_RF_Physics": [
        "RF Physics Field Engine",
        "Fourier / FFT Explorer",
        "Group Delay Simulator",
        "Phase Noise Lab",
        "Propagation Sandbox"
    ],
    "03_Signal_Analyzer": [
        "RF Spectrum Lab",
        "Waterfall Engine",
        "IQ / Constellation Lab",
        "Modulation Classifier",
        "HackRF 0-6 GHz Analyzer"
    ],
    "04_RF_Microwave_Engineering": [
        "Smith Chart Engine",
        "VSWR / Return Loss Analyzer",
        "Transmission Line Simulator",
        "Microstrip / Stripline Designer",
        "Patch Antenna Designer"
    ],
    "05_Antenna_System": [
        "Antenna System Explorer",
        "RRU / RET / CPRI Port Mapping Simulator",
        "MIMO Array Simulator",
        "Tilt / Azimuth Planner",
        "AISG Chain Mapper"
    ],
    "06_Microwave_Link": [
        "LOS / Fresnel Visualizer",
        "Microwave Link Budget Engine",
        "Rain Fading Simulator",
        "XPIC Simulator",
        "Adaptive Modulation Lab"
    ],
    "07_Fiber_Optic": [
        "Fiber Connector Explorer",
        "ODF / Fiber Route Mapper",
        "OTDR Trace Simulator",
        "Fronthaul / Backhaul Planner",
        "Optical Loss Budget Engine"
    ],
    "08_Private_Networks": [
        "5G SA Private Planner",
        "WiFi 7 / MLO Explorer",
        "Industrial Mesh Simulator",
        "Slicing / QoS Console",
        "MEC Placement Console"
    ],
    "09_Core_Network": [
        "5G Core / RAN Call-Flow Engine",
        "NGAP / PFCP / GTP-U Correlator",
        "Open5GS Service Map",
        "UERANSIM Attach Lab",
        "PDU Session Explorer"
    ],
    "10_Data_Center_Infrastructure": [
        "Infrastructure Digital Twin",
        "Rack Layout Explorer",
        "Power Chain Monitor",
        "Grounding / EMC Checklist",
        "SNMP Monitoring Console"
    ],
    "11_Cyber_RF_Intelligence": [
        "Spectrum Anomaly Detector",
        "Jamming Scenario Lab",
        "Rogue RF Hunter",
        "Protocol Anomaly Correlator",
        "Evidence Report Builder"
    ],
    "12_Knowledge_Base": [
        "Formula Navigator",
        "Procedure Runbook",
        "Troubleshooting Tree",
        "Checklist Engine",
        "Lesson Plan Builder"
    ]
}

board = {
    "portal": "TRFMC / 5G RF TELCO LAB",
    "official_port": 5173,
    "quality_gate": {
        "broken_refs_required": 0,
        "external_refs_required": 0,
        "forbidden_refs_required": 0
    },
    "principle": "Every visual object must become a technical interactive engine, simulator, explorer or analyzer.",
    "domains": []
}

for d in domains:
    did = d["id"]
    dpages = [p for p in pages if p.get("domain_id") == did]
    dpages.sort(key=lambda p: (action_rank.get(p.get("recommended_action", "FUSE"), 9), p.get("route", "")))

    primary = dpages[0] if dpages else None
    promote = [p for p in dpages if p.get("recommended_action") == "PROMOTE"]
    engine = [p for p in dpages if p.get("recommended_action") == "ENGINE"]
    fuse = [p for p in dpages if p.get("recommended_action") == "FUSE"]
    rewrite = [p for p in dpages if p.get("recommended_action") == "REWRITE"]

    board["domains"].append({
        "domain_id": did,
        "title": d.get("title"),
        "engine_target": d.get("engine_target"),
        "interactive_objects": engine_objects.get(did, []),
        "page_count": len(dpages),
        "primary_seed": primary,
        "counts": {
            "PROMOTE": len(promote),
            "ENGINE": len(engine),
            "FUSE": len(fuse),
            "REWRITE": len(rewrite)
        },
        "promotion_plan": [
            "P0: mantenere quality gate 0/0/0 su 5173",
            "P1: promuovere il primary seed come pannello ufficiale del dominio",
            "P2: fondere le varianti duplicate e legacy",
            "P3: trasformare visual statici in engine interattivi",
            "P4: aggiungere hook runtime/strumentazione quando disponibili",
            "P5: ricollaudo completo e freeze"
        ],
        "candidates": dpages[:12]
    })

(out / "trfmc_engine_promotion_board_v1.json").write_text(json.dumps(board, indent=2, ensure_ascii=False))
(public / "trfmc_engine_promotion_board_v1.json").write_text(json.dumps(board, indent=2, ensure_ascii=False))

def esc(x):
    return html.escape(str(x if x is not None else ""))

domain_sections = []
for d in board["domains"]:
    seed = d["primary_seed"]
    seed_html = ""
    if seed:
        seed_html = f'''
        <div class="seed">
          <div>
            <strong>Primary seed</strong>
            <a href="{esc(seed.get("route"))}">{esc(seed.get("title") or seed.get("route"))}</a>
            <p>{esc(seed.get("reason", ""))}</p>
          </div>
          <span class="badge {esc(seed.get("recommended_action", "FUSE"))}">{esc(seed.get("recommended_action", "FUSE"))}</span>
        </div>
        '''
    else:
        seed_html = '<div class="seed empty">Nessun seed disponibile: dominio da costruire.</div>'

    objects = "".join(f"<li>{esc(o)}</li>" for o in d["interactive_objects"])

    candidates = "".join(
        f'''
        <tr>
          <td><span class="badge {esc(p.get("recommended_action", "FUSE"))}">{esc(p.get("recommended_action", "FUSE"))}</span></td>
          <td><a href="{esc(p.get("route"))}">{esc(p.get("route"))}</a></td>
          <td>{esc(p.get("title") or p.get("h1") or "-")}</td>
        </tr>
        '''
        for p in d["candidates"]
    )

    domain_sections.append(f'''
    <section class="domain">
      <div class="domainHead">
        <div>
          <h2>{esc(d["domain_id"])} — {esc(d["title"])}</h2>
          <p>{esc(d["engine_target"])}</p>
        </div>
        <div class="count">{d["page_count"]} pagine</div>
      </div>

      <div class="domainGrid">
        <div>
          {seed_html}
          <h3>Oggetti da trasformare in engine</h3>
          <ul class="objects">{objects}</ul>
        </div>
        <div>
          <h3>Azioni</h3>
          <div class="miniGrid">
            <div><b>{d["counts"]["PROMOTE"]}</b><span>PROMOTE</span></div>
            <div><b>{d["counts"]["ENGINE"]}</b><span>ENGINE</span></div>
            <div><b>{d["counts"]["FUSE"]}</b><span>FUSE</span></div>
            <div><b>{d["counts"]["REWRITE"]}</b><span>REWRITE</span></div>
          </div>
        </div>
      </div>

      <table>
        <thead>
          <tr><th>Azione</th><th>Route</th><th>Titolo</th></tr>
        </thead>
        <tbody>{candidates}</tbody>
      </table>
    </section>
    ''')

report = f'''<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Engine Promotion Board V1</title>
<style>
:root{{
  --bg:#030711;
  --panel:rgba(8,18,36,.88);
  --line:rgba(125,190,255,.24);
  --text:#eaf3ff;
  --muted:#94a9c5;
  --cyan:#86d7ff;
  --green:#9dffc7;
  --amber:#ffd37a;
  --violet:#bda7ff;
}}
*{{box-sizing:border-box}}
body{{
  margin:0;
  background:
    radial-gradient(circle at 15% 0%,rgba(50,130,255,.24),transparent 30%),
    radial-gradient(circle at 92% 10%,rgba(0,255,190,.10),transparent 28%),
    linear-gradient(180deg,#030711,#07111f 50%,#030711);
  color:var(--text);
  font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}}
header{{
  position:sticky;
  top:0;
  z-index:5;
  padding:24px 32px;
  border-bottom:1px solid var(--line);
  background:rgba(3,7,17,.84);
  backdrop-filter:blur(18px);
}}
h1{{margin:0;font-size:30px;letter-spacing:-.03em}}
header p{{margin:8px 0 0;color:var(--muted)}}
.nav{{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}}
.nav a{{
  color:var(--text);
  text-decoration:none;
  border:1px solid var(--line);
  border-radius:999px;
  padding:8px 11px;
  background:rgba(255,255,255,.045);
  font-size:12px;
}}
main{{padding:26px 32px 70px}}
.kpiGrid{{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:20px}}
.kpi{{
  border:1px solid var(--line);
  background:rgba(255,255,255,.055);
  border-radius:18px;
  padding:16px;
}}
.kpi b{{display:block;font-size:28px;color:var(--cyan)}}
.kpi span{{color:var(--muted);font-size:12px}}
.domain{{
  margin-top:18px;
  border:1px solid var(--line);
  background:var(--panel);
  border-radius:22px;
  overflow:hidden;
  box-shadow:0 18px 60px rgba(0,0,0,.28);
}}
.domainHead{{
  display:flex;
  justify-content:space-between;
  gap:16px;
  padding:18px 20px;
  border-bottom:1px solid rgba(255,255,255,.08);
  background:rgba(255,255,255,.035);
}}
.domainHead h2{{margin:0;color:var(--cyan);font-size:21px}}
.domainHead p{{margin:6px 0 0;color:var(--muted)}}
.count{{
  height:max-content;
  color:var(--green);
  border:1px solid rgba(157,255,199,.45);
  border-radius:999px;
  padding:8px 12px;
}}
.domainGrid{{display:grid;grid-template-columns:1.2fr .8fr;gap:16px;padding:18px 20px}}
.seed{{
  display:flex;
  justify-content:space-between;
  gap:14px;
  border:1px solid rgba(157,255,199,.24);
  background:rgba(157,255,199,.055);
  border-radius:16px;
  padding:14px;
}}
.seed a{{display:block;color:var(--text);font-weight:800;text-decoration:none;margin-top:5px}}
.seed p{{color:var(--muted);margin:7px 0 0;font-size:13px}}
.empty{{color:var(--muted)}}
.objects{{display:grid;grid-template-columns:repeat(2,1fr);gap:8px;padding-left:18px;color:#cfe1f7}}
.objects li{{margin-bottom:4px}}
.miniGrid{{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}}
.miniGrid div{{
  border:1px solid rgba(255,255,255,.10);
  background:rgba(255,255,255,.04);
  border-radius:14px;
  padding:12px;
}}
.miniGrid b{{display:block;font-size:24px}}
.miniGrid span{{color:var(--muted);font-size:12px}}
table{{width:100%;border-collapse:collapse}}
th,td{{padding:9px 11px;border-top:1px solid rgba(255,255,255,.07);font-size:13px;text-align:left;vertical-align:top}}
th{{color:var(--cyan);background:rgba(80,130,220,.12)}}
a{{color:#9ed0ff;text-decoration:none}}
.badge{{display:inline-block;border-radius:999px;padding:5px 8px;font-size:11px;border:1px solid rgba(255,255,255,.18)}}
.PROMOTE{{color:var(--green);border-color:rgba(157,255,199,.5)}}
.ENGINE{{color:var(--cyan);border-color:rgba(134,215,255,.5)}}
.FUSE{{color:var(--amber);border-color:rgba(255,211,122,.5)}}
.REWRITE{{color:var(--violet);border-color:rgba(189,167,255,.5)}}
@media(max-width:1000px){{
  .kpiGrid,.domainGrid{{grid-template-columns:1fr}}
  .objects{{grid-template-columns:1fr}}
}}
</style>
</head>
<body>
<header>
  <h1>TRFMC Engine Promotion Board V1</h1>
  <p>Da pagine sane a motori tecnici interattivi: simulators, analyzers, explorers, digital twins.</p>
  <div class="nav">
    <a href="/trfmc_unified_navigation_shell_v1.html">Unified Shell</a>
    <a href="/trfmc_master_digital_twin_console_v1.html">Master Console</a>
    <a href="/trfmc_domain_registry_v1.html">Domain Registry</a>
    <a href="/trfmc_collaudo_report.html">Collaudo</a>
    <a href="/api/health">Health</a>
  </div>
</header>
<main>
  <div class="kpiGrid">
    <div class="kpi"><b>{len(board["domains"])}</b><span>domini ufficiali</span></div>
    <div class="kpi"><b>{sum(d["page_count"] for d in board["domains"])}</b><span>pagine classificate</span></div>
    <div class="kpi"><b>5173</b><span>porta unica</span></div>
    <div class="kpi"><b>0/0/0</b><span>quality gate richiesto</span></div>
  </div>

  {''.join(domain_sections)}
</main>
</body>
</html>
'''

(out / "trfmc_engine_promotion_board_v1.html").write_text(report)
(public / "trfmc_engine_promotion_board_v1.html").write_text(report)

print(json.dumps({
    "domains": len(board["domains"]),
    "pages": sum(d["page_count"] for d in board["domains"]),
    "output": "/trfmc_engine_promotion_board_v1.html"
}, indent=2, ensure_ascii=False))
PY

echo
echo "=== PATCH LINK SU SHELL / MASTER / INDEX ==="

python3 - <<'PY'
from pathlib import Path

files = [
    Path("frontend/public/trfmc_unified_navigation_shell_v1.html"),
    Path("frontend/public/trfmc_master_digital_twin_console_v1.html"),
    Path("frontend/public/trfmc_domain_registry_v1.html"),
    Path("frontend/public/api/portal/index"),
]

for p in files:
    if not p.exists():
        print("SKIP:", p)
        continue

    s = p.read_text(errors="ignore")
    old = s

    if "trfmc_engine_promotion_board_v1.html" not in s:
        if "</div>" in s and "quick" in s:
            s = s.replace(
                '<a href="/trfmc_domain_registry_v1.html">Domain Registry</a>',
                '<a href="/trfmc_domain_registry_v1.html">Domain Registry</a>\n      <a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>',
                1
            )
        elif "<ul>" in s:
            s = s.replace(
                "<ul>",
                '<ul>\n<li><a href="/trfmc_engine_promotion_board_v1.html">TRFMC Engine Promotion Board V1</a></li>',
                1
            )
        elif "nav" in s:
            s = s.replace(
                '<a href="/trfmc_domain_registry_v1.html">Domain Registry</a>',
                '<a href="/trfmc_domain_registry_v1.html">Domain Registry</a>\n    <a href="/trfmc_engine_promotion_board_v1.html">Engine Board</a>',
                1
            )

    if s != old:
        p.write_text(s)
        print("PATCHED:", p)
    else:
        print("UNCHANGED:", p)
PY

echo
echo "=== TEST HTTP ==="
curl -I --max-time 5 http://127.0.0.1:5173/trfmc_engine_promotion_board_v1.html

echo
echo "ENGINE PROMOTION BOARD:"
echo "http://127.0.0.1:5173/trfmc_engine_promotion_board_v1.html"
