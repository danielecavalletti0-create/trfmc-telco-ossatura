#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
FRONTEND="$BASE/frontend"
PUBLIC="$FRONTEND/public"
RUNTIME="$BASE/runtime/domain_registry"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$RUNTIME/TRFMC_DOMAIN_REGISTRY_$TS"

mkdir -p "$OUT" "$PUBLIC"

echo "============================================================"
echo "TRFMC DOMAIN REGISTRY V1 - 12 DOMINI UFFICIALI"
echo "============================================================"
date
echo "BASE=$BASE"
echo "OUT=$OUT"
echo

python3 - <<'PY' "$BASE" "$FRONTEND" "$PUBLIC" "$OUT"
from pathlib import Path
from html.parser import HTMLParser
import sys, re, json, html, hashlib

base = Path(sys.argv[1])
frontend = Path(sys.argv[2])
public = Path(sys.argv[3])
out = Path(sys.argv[4])

DOMAINS = [
    {
        "id": "01_Mission_Control",
        "title": "Mission Control",
        "keywords": [
            "mission", "dashboard", "executive", "observability", "timeline",
            "alarms", "runtime", "golden", "readiness", "backup", "restore",
            "operator", "handbook", "scenario", "evidence", "vault"
        ],
        "engine_target": "Mission Control / NOC / Runtime Health Engine"
    },
    {
        "id": "02_RF_Physics",
        "title": "RF Physics",
        "keywords": [
            "rf_physics", "physics", "sapienza", "propagation", "fourier",
            "fft", "wave", "field", "phase", "dispersion", "heatmap"
        ],
        "engine_target": "RF Physics Field Engine"
    },
    {
        "id": "03_Signal_Analyzer",
        "title": "Signal Analyzer",
        "keywords": [
            "signal", "spectrum", "instrumentation", "iq", "waterfall",
            "modulation", "cockpit", "vsa", "tm_supreme"
        ],
        "engine_target": "RF Spectrum Lab / VSA / IQ Analyzer"
    },
    {
        "id": "04_RF_Microwave_Engineering",
        "title": "RF Microwave Engineering",
        "keywords": [
            "microwave", "smith", "vswr", "s11", "return", "impedance",
            "microstrip", "stripline", "patch"
        ],
        "engine_target": "Smith Chart & Matching Engine"
    },
    {
        "id": "05_Antenna_System",
        "title": "Antenna System",
        "keywords": [
            "antenna", "rru", "bbu", "cpri", "ecpri", "ret", "aisg",
            "mimo", "tilt", "azimuth", "port mapping"
        ],
        "engine_target": "Antenna System Explorer / RRU RET CPRI Simulator"
    },
    {
        "id": "06_Microwave_Link",
        "title": "Microwave Link",
        "keywords": [
            "link", "fresnel", "los", "fade", "rain", "rsl", "ber",
            "xpic", "adaptive modulation"
        ],
        "engine_target": "Microwave Link Budget Engine"
    },
    {
        "id": "07_Fiber_Optic",
        "title": "Fiber Optic",
        "keywords": [
            "fiber", "fibre", "optic", "otdr", "odf", "lc", "sc", "st",
            "mpo", "fronthaul", "backhaul"
        ],
        "engine_target": "Fiber / OTDR Trace Engine"
    },
    {
        "id": "08_Private_Networks",
        "title": "Private Networks",
        "keywords": [
            "private", "wifi", "wifi 7", "mlo", "mesh", "campus",
            "mining", "tactical", "slicing", "qos", "mec"
        ],
        "engine_target": "Private Network Scenario Engine"
    },
    {
        "id": "09_Core_Network",
        "title": "Core Network",
        "keywords": [
            "core", "open5gs", "ueransim", "amf", "smf", "upf",
            "ngap", "pfcp", "gtp", "pdu", "call-flow", "callflow", "ran"
        ],
        "engine_target": "5G Core / RAN Call-Flow Engine"
    },
    {
        "id": "10_Data_Center_Infrastructure",
        "title": "Data Center Infrastructure",
        "keywords": [
            "infrastructure", "rack", "pdu", "ups", "-48v", "grounding",
            "temperature", "snmp", "data center", "datacenter"
        ],
        "engine_target": "Infrastructure Digital Twin"
    },
    {
        "id": "11_Cyber_RF_Intelligence",
        "title": "Cyber RF Intelligence",
        "keywords": [
            "cyber", "security", "anomaly", "jamming", "rogue", "intrusion",
            "threat", "evidence", "forensic", "attack"
        ],
        "engine_target": "Cyber RF Intelligence Engine"
    },
    {
        "id": "12_Knowledge_Base",
        "title": "Knowledge Base",
        "keywords": [
            "knowledge", "theory", "glossary", "formula", "procedure",
            "checklist", "lesson", "doctrine", "component", "library",
            "registry", "design token", "template"
        ],
        "engine_target": "Knowledge & Procedure Engine"
    }
]

class MetaParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_title = False
        self.title = ""
        self.h1 = ""
        self._h1 = False
        self.links = []
    def handle_starttag(self, tag, attrs):
        d = dict(attrs)
        if tag == "title":
            self.in_title = True
        if tag == "h1":
            self._h1 = True
        if tag == "a" and "href" in d:
            self.links.append(d["href"])
    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False
        if tag == "h1":
            self._h1 = False
    def handle_data(self, data):
        if self.in_title:
            self.title += data.strip() + " "
        if self._h1 and not self.h1:
            self.h1 += data.strip() + " "

def route_for_file(p: Path):
    if public in p.parents:
        return "/" + p.relative_to(public).as_posix()
    return "/" + p.relative_to(frontend).as_posix()

def extract_meta(p: Path):
    text = p.read_text(errors="ignore")
    parser = MetaParser()
    try:
        parser.feed(text)
    except Exception:
        pass
    title = " ".join(parser.title.split()).strip()
    h1 = " ".join(parser.h1.split()).strip()
    sample = re.sub(r"\s+", " ", text[:12000]).lower()
    return title, h1, sample, parser.links, text

def classify(route, title, h1, sample):
    hay = f"{route} {title} {h1} {sample}".lower()
    scores = []
    for d in DOMAINS:
        score = 0
        hits = []
        for kw in d["keywords"]:
            k = kw.lower()
            if k in hay:
                # Peso maggiore se compare nella route o nel titolo.
                route_title = f"{route} {title} {h1}".lower()
                weight = 5 if k in route_title else 1
                score += weight
                hits.append(kw)
        scores.append((score, d, hits))
    scores.sort(key=lambda x: x[0], reverse=True)
    best_score, best_domain, hits = scores[0]
    if best_score == 0:
        return "12_Knowledge_Base", "Knowledge Base", "Knowledge & Procedure Engine", 0, []
    return best_domain["id"], best_domain["title"], best_domain["engine_target"], best_score, hits[:10]

def action_for(route, title, domain_id, size, text):
    r = route.lower()
    t = (title or "").lower()
    body = text.lower()

    if "master_digital_twin" in r:
        return "PROMOTE", "Master console già candidata a entrypoint funzionale."
    if "home_v87g" in r or r.endswith("/trfmc_home.html") or r.endswith("/trfmc.html"):
        return "PROMOTE", "Home/entrypoint da collegare alla Master Console."
    if "collaudo" in r or "quality" in r or "golden" in r:
        return "PROMOTE", "Console di validazione e quality gate."
    if re.search(r"_v8[0-9][a-z]?|_v7[0-9]|_v6[0-9]", r):
        if "rf_sapienza_console_v84" in r or "webgl_rf_physics_engine_v83" in r or "webgl_rf_heatmap_engine" in r:
            return "FUSE", "Serie evolutiva RF/WebGL: fondere nella versione primaria."
    if "engine" in r or "simulator" in body or "canvas" in body or "webgl" in body:
        return "ENGINE", "Base tecnica da trasformare in engine interattivo maturo."
    if "template" in r or "audit" in r or "registry" in r:
        return "FUSE", "Pagina di supporto da fondere nel registry/knowledge base."
    if size < 4500:
        return "REWRITE", "Pagina leggera: utile come seme, ma da riscrivere in stile omogeneo."
    return "FUSE", "Contenuto utile da integrare nella struttura ufficiale."

html_files = []
for p in sorted(frontend.rglob("*.html")):
    parts = set(p.parts)
    if "node_modules" in parts or "dist" in parts:
        continue
    html_files.append(p)

records = []
for p in html_files:
    route = route_for_file(p)
    title, h1, sample, links, text = extract_meta(p)
    size = p.stat().st_size
    sha = hashlib.sha256(p.read_bytes()).hexdigest()[:16]
    domain_id, domain_title, engine_target, score, hits = classify(route, title, h1, sample)
    action, reason = action_for(route, title, domain_id, size, text)

    records.append({
        "route": route,
        "file": str(p),
        "size_bytes": size,
        "sha256_16": sha,
        "title": title,
        "h1": h1,
        "domain_id": domain_id,
        "domain_title": domain_title,
        "engine_target": engine_target,
        "classification_score": score,
        "matched_keywords": hits,
        "recommended_action": action,
        "reason": reason,
        "link_count": len(links)
    })

# Ordine per dominio e poi action.
action_rank = {"PROMOTE":0, "ENGINE":1, "FUSE":2, "REWRITE":3, "ARCHIVE":4}
records.sort(key=lambda r: (r["domain_id"], action_rank.get(r["recommended_action"],9), r["route"]))

summary = {
    "total_pages": len(records),
    "domains": {},
    "actions": {},
}
for r in records:
    summary["domains"].setdefault(r["domain_id"], 0)
    summary["domains"][r["domain_id"]] += 1
    summary["actions"].setdefault(r["recommended_action"], 0)
    summary["actions"][r["recommended_action"]] += 1

(out / "trfmc_domain_registry_v1.json").write_text(json.dumps({
    "portal": "TRFMC / 5G RF TELCO LAB",
    "official_port": 5173,
    "domains": DOMAINS,
    "summary": summary,
    "pages": records
}, indent=2, ensure_ascii=False))

(out / "trfmc_domain_registry_v1.tsv").write_text(
    "domain_id\tdomain_title\taction\troute\ttitle\tsize_bytes\tengine_target\treason\tmatched_keywords\tfile\n" +
    "\n".join(
        "\t".join([
            r["domain_id"],
            r["domain_title"],
            r["recommended_action"],
            r["route"],
            (r["title"] or "").replace("\t"," "),
            str(r["size_bytes"]),
            r["engine_target"],
            r["reason"].replace("\t"," "),
            ",".join(r["matched_keywords"]),
            r["file"]
        ])
        for r in records
    ) + "\n"
)

# Generate HTML
def esc(x): return html.escape(str(x))

by_domain = {}
for r in records:
    by_domain.setdefault(r["domain_id"], []).append(r)

cards = []
for d in DOMAINS:
    rs = by_domain.get(d["id"], [])
    cards.append(f"""
    <section class="domain">
      <div class="domainHead">
        <div>
          <h2>{esc(d["id"])} — {esc(d["title"])}</h2>
          <p>{esc(d["engine_target"])}</p>
        </div>
        <strong>{len(rs)} pagine</strong>
      </div>
      <table>
        <thead>
          <tr>
            <th>Azione</th>
            <th>Route</th>
            <th>Titolo</th>
            <th>Engine target</th>
            <th>Motivo</th>
          </tr>
        </thead>
        <tbody>
          {''.join(f'''
          <tr>
            <td><span class="badge {esc(r["recommended_action"].lower())}">{esc(r["recommended_action"])}</span></td>
            <td><a href="{esc(r["route"])}">{esc(r["route"])}</a></td>
            <td>{esc(r["title"] or r["h1"] or "-")}</td>
            <td>{esc(r["engine_target"])}</td>
            <td>{esc(r["reason"])}</td>
          </tr>''' for r in rs)}
        </tbody>
      </table>
    </section>
    """)

action_cards = "".join(
    f'<div class="kpi"><b>{esc(k)}</b><span>{v}</span></div>'
    for k,v in sorted(summary["actions"].items())
)

domain_cards = "".join(
    f'<div class="kpi"><b>{esc(k.split("_",1)[0])}</b><span>{v} pagine</span></div>'
    for k,v in sorted(summary["domains"].items())
)

report = f"""<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>TRFMC Domain Registry V1</title>
<style>
:root {{
  --bg:#030711;
  --panel:rgba(8,18,36,.88);
  --line:rgba(125,190,255,.24);
  --text:#eaf3ff;
  --muted:#93a9c6;
  --cyan:#86d7ff;
  --green:#9dffc7;
  --amber:#ffd37a;
  --red:#ff8d8d;
  --violet:#bda7ff;
}}
*{{box-sizing:border-box}}
body{{
  margin:0;
  background:
    radial-gradient(circle at 20% 0%,rgba(50,130,255,.22),transparent 30%),
    radial-gradient(circle at 100% 10%,rgba(0,255,190,.11),transparent 26%),
    linear-gradient(180deg,#030711,#07111f 48%,#030711);
  color:var(--text);
  font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
}}
header{{
  padding:28px 34px;
  border-bottom:1px solid var(--line);
  background:rgba(3,7,17,.78);
  position:sticky;
  top:0;
  z-index:5;
  backdrop-filter:blur(16px);
}}
h1{{margin:0;font-size:30px;letter-spacing:-.03em}}
header p{{color:var(--muted);margin:8px 0 0}}
main{{padding:26px 34px 70px}}
.grid{{display:grid;grid-template-columns:repeat(6,minmax(130px,1fr));gap:12px;margin:18px 0}}
.kpi{{
  background:rgba(255,255,255,.055);
  border:1px solid var(--line);
  border-radius:16px;
  padding:14px;
}}
.kpi b{{display:block;font-size:20px;color:var(--cyan)}}
.kpi span{{color:var(--muted);font-size:12px}}
.domain{{
  margin-top:20px;
  background:var(--panel);
  border:1px solid var(--line);
  border-radius:20px;
  overflow:hidden;
  box-shadow:0 18px 60px rgba(0,0,0,.24);
}}
.domainHead{{
  display:flex;
  justify-content:space-between;
  gap:16px;
  padding:18px 20px;
  border-bottom:1px solid rgba(255,255,255,.08);
  background:rgba(255,255,255,.035);
}}
.domainHead h2{{margin:0;color:var(--cyan);font-size:20px}}
.domainHead p{{margin:5px 0 0;color:var(--muted)}}
.domainHead strong{{
  border:1px solid rgba(157,255,199,.35);
  color:var(--green);
  border-radius:999px;
  padding:8px 12px;
  height:max-content;
}}
table{{width:100%;border-collapse:collapse}}
th,td{{padding:9px 11px;border-bottom:1px solid rgba(255,255,255,.07);font-size:13px;text-align:left;vertical-align:top}}
th{{color:var(--cyan);background:rgba(80,130,220,.12)}}
a{{color:#9ed0ff;text-decoration:none}}
.badge{{display:inline-block;border-radius:999px;padding:5px 8px;font-size:11px;border:1px solid rgba(255,255,255,.18)}}
.promote{{color:var(--green);border-color:rgba(157,255,199,.5)}}
.engine{{color:var(--cyan);border-color:rgba(134,215,255,.5)}}
.fuse{{color:var(--amber);border-color:rgba(255,211,122,.5)}}
.rewrite{{color:var(--violet);border-color:rgba(189,167,255,.5)}}
.archive{{color:var(--red);border-color:rgba(255,141,141,.5)}}
.nav{{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}}
.nav a{{border:1px solid var(--line);border-radius:999px;padding:8px 10px;background:rgba(255,255,255,.04)}}
@media(max-width:1000px){{.grid{{grid-template-columns:repeat(2,1fr)}}}}
</style>
</head>
<body>
<header>
  <h1>TRFMC Domain Registry V1</h1>
  <p>Classificazione delle pagine esistenti nei 12 domini ufficiali del portale RF/Telco/Cyber.</p>
  <div class="nav">
    <a href="/trfmc_master_digital_twin_console_v1.html">Master Digital Twin Console</a>
    <a href="/trfmc_collaudo_report.html">Collaudo</a>
    <a href="/api/health">Health</a>
  </div>
</header>
<main>
  <h2>Azioni consigliate</h2>
  <div class="grid">{action_cards}</div>

  <h2>Distribuzione domini</h2>
  <div class="grid">{domain_cards}</div>

  {''.join(cards)}
</main>
</body>
</html>
"""

(out / "trfmc_domain_registry_v1.html").write_text(report)
(public / "trfmc_domain_registry_v1.html").write_text(report)
(public / "trfmc_domain_registry_v1.json").write_text((out / "trfmc_domain_registry_v1.json").read_text())

print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "=== FILE GENERATI ==="
ls -lh "$OUT"/trfmc_domain_registry_v1.*
ls -lh "$PUBLIC"/trfmc_domain_registry_v1.*

echo
echo "=== PATCH LINK SU MASTER CONSOLE E PORTAL INDEX ==="
MASTER="$PUBLIC/trfmc_master_digital_twin_console_v1.html"
INDEX="$PUBLIC/api/portal/index"

if [ -f "$MASTER" ]; then
  cp -a "$MASTER" "$MASTER.bak_domain_registry_$TS"
  if ! grep -q "trfmc_domain_registry_v1.html" "$MASTER"; then
    sed -i '/<a href="\/trfmc_collaudo_report.html">Collaudo<\/a>/a \      <a href="/trfmc_domain_registry_v1.html">Domain Registry</a>' "$MASTER" || true
  fi
fi

if [ -f "$INDEX" ]; then
  cp -a "$INDEX" "$INDEX.bak_domain_registry_$TS"
  if ! grep -q "trfmc_domain_registry_v1.html" "$INDEX"; then
    sed -i '/<ul>/a <li><a href="/trfmc_domain_registry_v1.html">TRFMC Domain Registry V1</a></li>' "$INDEX" || true
  fi
fi

echo
echo "REGISTRY URL:"
echo "http://127.0.0.1:5173/trfmc_domain_registry_v1.html"
