from pathlib import Path
import json
import subprocess
import time
import html

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_VISUAL_ASSET_SCAFFOLD_V41B_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_VISUAL_ASSET_SCAFFOLD_V41B_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_VISUAL_ASSET_SCAFFOLD_V41B_{TS}.tar.gz"

PUBLIC = ROOT / "frontend/public"
ASSET_ROOT = PUBLIC / "trfmc_assets/visual_knowledge"
REGISTRY_V41 = ASSET_ROOT / "visual_asset_registry_v41_fallback.json"
REGISTRY_V35_COMPAT = ASSET_ROOT / "visual_asset_registry_v35.json"

MAIN = ROOT / "frontend/src/app/main.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC VISUAL ASSET SCAFFOLD V41B")
print("asset root · fallback SVGs · registry · no React/backend mutation")
print("=" * 60)

# Preconditions
for rel in [
    "runtime/quality/latest_visual_asset_binding_audit_v41a/summary.json",
    "runtime/quality/latest_scenario_knowledge_binding_v40/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not MAIN.exists():
    raise SystemExit("ERRORE: main.tsx mancante")

if "RFOperationalDeckV40ScenarioKnowledgeFusion" not in MAIN.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: main.tsx non monta V40")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:4181/api/mission/status"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0 or "TRFMC_READONLY_BACKEND_BRIDGE_V28" not in probe.stdout:
    raise SystemExit("ERRORE: API 4181 non operative")

print("OK: V41A/V40 PASS, active mount V40, API 4181 live")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_VISUAL_ASSET_SCAFFOLD_V41B_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/public/trfmc_assets",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

assets = [
    {
        "id": "electronics_symbols_basic_concepts",
        "title": "Electronics Fundamentals",
        "category": "01_electronics_symbols",
        "filename_svg": "electronics_symbols_basic_concepts.svg",
        "filename_jpg": "electronics_symbols_basic_concepts.jpg",
        "description": "Fallback tecnico per symbol library elettronica: componenti, segnali, logica e strumenti.",
        "accent": "#75eaff",
        "secondary": "#8dffbd",
        "labels": ["R", "C", "L", "GND", "DIODE", "BJT", "FET", "LOGIC", "RF"],
    },
    {
        "id": "microstrip_patch_antenna_5g",
        "title": "Microstrip Patch Antenna",
        "category": "02_antennas_microstrip",
        "filename_svg": "microstrip_patch_antenna_5g.svg",
        "filename_jpg": "microstrip_patch_antenna_5g.jpg",
        "description": "Fallback tecnico per patch, substrate, feed line, ground plane e pattern.",
        "accent": "#ffb06d",
        "secondary": "#75eaff",
        "labels": ["PATCH", "SUBSTRATE", "FEED", "GROUND", "S11", "PATTERN"],
    },
    {
        "id": "types_of_telecom_antennas",
        "title": "Types of Telecom Antennas",
        "category": "03_antennas_types",
        "filename_svg": "types_of_telecom_antennas.svg",
        "filename_jpg": "types_of_telecom_antennas.jpg",
        "description": "Fallback tecnico per sector, dish, MIMO, small cell, GPS, Yagi e horn.",
        "accent": "#75eaff",
        "secondary": "#ffd37b",
        "labels": ["SECTOR", "DISH", "MIMO", "SMALL CELL", "YAGI", "GPS"],
    },
    {
        "id": "beamwidth_narrow_wide",
        "title": "Beamwidth and Coverage",
        "category": "03_antennas_types",
        "filename_svg": "beamwidth_narrow_wide.svg",
        "filename_jpg": "beamwidth_narrow_wide.jpg",
        "description": "Fallback tecnico per confronto narrow/wide beam, HPBW, gain e coverage.",
        "accent": "#8dffbd",
        "secondary": "#75eaff",
        "labels": ["NARROW BEAM", "WIDE BEAM", "-3 dB", "GAIN", "COVERAGE"],
    },
    {
        "id": "telecom_towers_arabic_overview",
        "title": "Telecom Towers Overview",
        "category": "04_telco_infrastructure",
        "filename_svg": "telecom_towers_arabic_overview.svg",
        "filename_jpg": "telecom_towers_arabic_overview.jpg",
        "description": "Fallback tecnico per torri, macro site, radome, backhaul e smart pole.",
        "accent": "#75eaff",
        "secondary": "#ffb06d",
        "labels": ["MACRO", "BACKHAUL", "RADOME", "CABINET", "SMART POLE"],
    },
    {
        "id": "cellular_satellite_site_photo",
        "title": "Cellular and Satellite Site",
        "category": "04_telco_infrastructure",
        "filename_svg": "cellular_satellite_site_photo.svg",
        "filename_jpg": "cellular_satellite_site_photo.jpg",
        "description": "Fallback tecnico per sito cellulare/satellitare e apparati outdoor.",
        "accent": "#75eaff",
        "secondary": "#c6a8ff",
        "labels": ["CELL SITE", "SATCOM", "DISH", "RRU", "POWER"],
    },
    {
        "id": "rf_microwave_engineering_lab",
        "title": "RF & Microwave Engineering Lab",
        "category": "05_rf_lab_visuals",
        "filename_svg": "rf_microwave_engineering_lab.svg",
        "filename_jpg": "rf_microwave_engineering_lab.jpg",
        "description": "Fallback tecnico per VNA, VSA, Smith chart, S-parameters e banco RF.",
        "accent": "#75eaff",
        "secondary": "#8dffbd",
        "labels": ["VNA", "VSA", "SMITH", "S11/S21", "DUT", "CAL"],
    },
    {
        "id": "falco_xplorer_vs_bayraktar_tb2",
        "title": "UAV Platforms and ISR Systems",
        "category": "06_uav_rf_links",
        "filename_svg": "falco_xplorer_vs_bayraktar_tb2.svg",
        "filename_jpg": "falco_xplorer_vs_bayraktar_tb2.jpg",
        "description": "Fallback tecnico per UAV ISR, payload, datalink, telemetry e GCS.",
        "accent": "#75eaff",
        "secondary": "#ffd37b",
        "labels": ["UAV ISR", "PAYLOAD", "C2 LINK", "TELEMETRY", "GCS"],
    },
]

def svg_for_asset(asset):
    title = html.escape(asset["title"])
    desc = html.escape(asset["description"])
    accent = asset["accent"]
    secondary = asset["secondary"]
    labels = asset["labels"]

    label_svg = []
    x_positions = [90, 260, 430, 600, 770, 940, 1110, 1280, 1450]
    for idx, label in enumerate(labels[:9]):
        x = x_positions[idx]
        y = 760 if idx % 2 == 0 else 840
        label_svg.append(
            f'<g transform="translate({x},{y})">'
            f'<rect x="-70" y="-24" width="140" height="48" rx="18" fill="rgba(5,17,31,.88)" stroke="{accent}" stroke-opacity=".45"/>'
            f'<text x="0" y="6" text-anchor="middle" font-size="22" font-weight="800" fill="#f1fbff">{html.escape(label)}</text>'
            f'</g>'
        )

    # generic technical objects
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">
  <defs>
    <radialGradient id="g1" cx="20%" cy="10%" r="70%">
      <stop offset="0%" stop-color="{accent}" stop-opacity=".26"/>
      <stop offset="42%" stop-color="#06111f" stop-opacity=".95"/>
      <stop offset="100%" stop-color="#020812" stop-opacity="1"/>
    </radialGradient>
    <linearGradient id="panel" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0b2741"/>
      <stop offset="100%" stop-color="#04101d"/>
    </linearGradient>
    <filter id="glow">
      <feGaussianBlur stdDeviation="6" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  </defs>

  <rect width="1600" height="900" fill="url(#g1)"/>
  <g opacity=".22">
    <path d="M0 670 H1600 M0 730 H1600 M0 790 H1600 M0 850 H1600" stroke="{accent}" stroke-width="1"/>
    <path d="M120 0 V900 M260 0 V900 M400 0 V900 M540 0 V900 M680 0 V900 M820 0 V900 M960 0 V900 M1100 0 V900 M1240 0 V900 M1380 0 V900" stroke="{accent}" stroke-width="1"/>
  </g>

  <g transform="translate(90,72)">
    <text x="0" y="0" font-size="28" font-family="Inter,Segoe UI,Arial" font-weight="800" fill="{accent}" letter-spacing="6">TRFMC VISUAL FALLBACK ASSET</text>
    <text x="0" y="58" font-size="58" font-family="Inter,Segoe UI,Arial" font-weight="900" fill="#f1fbff">{title}</text>
    <text x="0" y="104" font-size="24" font-family="Inter,Segoe UI,Arial" fill="#9ab5c9">{desc}</text>
  </g>

  <g transform="translate(820,390)" filter="url(#glow)">
    <ellipse cx="0" cy="0" rx="260" ry="92" fill="{accent}" opacity=".18"/>
    <ellipse cx="0" cy="0" rx="170" ry="58" fill="{secondary}" opacity=".16"/>
    <path d="M-340 80 L-120 -60 L120 -60 L340 80 Z" fill="url(#panel)" stroke="{accent}" stroke-opacity=".6" stroke-width="3"/>
    <path d="M-200 25 L-60 -35 L80 -20 L210 48" fill="none" stroke="{secondary}" stroke-width="9" stroke-linecap="round"/>
    <circle cx="-220" cy="50" r="22" fill="{accent}" opacity=".75"/>
    <circle cx="220" cy="50" r="22" fill="{secondary}" opacity=".75"/>
    <path d="M-80 -105 C-30 -170 80 -170 140 -110" fill="none" stroke="{accent}" stroke-width="5" opacity=".75"/>
    <path d="M-140 -155 C-60 -255 110 -255 210 -155" fill="none" stroke="{secondary}" stroke-width="3" opacity=".52"/>
  </g>

  {''.join(label_svg)}

  <g transform="translate(90,820)">
    <rect x="0" y="-46" width="520" height="74" rx="22" fill="rgba(5,17,31,.82)" stroke="{secondary}" stroke-opacity=".35"/>
    <text x="24" y="-6" font-size="24" font-family="Inter,Segoe UI,Arial" fill="{secondary}" font-weight="800">source_mode: fallback · replaceable with real render</text>
  </g>
</svg>'''

# Create folders/assets
created = []
for asset in assets:
    folder = ASSET_ROOT / asset["category"]
    folder.mkdir(parents=True, exist_ok=True)
    svg_path = folder / asset["filename_svg"]
    svg_path.write_text(svg_for_asset(asset), encoding="utf-8")
    created.append(svg_path)

registry_assets = []
for asset in assets:
    svg_public = f"/trfmc_assets/visual_knowledge/{asset['category']}/{asset['filename_svg']}"
    jpg_public = f"/trfmc_assets/visual_knowledge/{asset['category']}/{asset['filename_jpg']}"
    registry_assets.append({
        "id": asset["id"],
        "title": asset["title"],
        "description": asset["description"],
        "category": asset["category"],
        "public_path": svg_public,
        "expected_real_render_path": jpg_public,
        "fallback_path": svg_public,
        "source_mode": "fallback",
        "replaceable": True,
        "tags": asset["labels"],
        "usage": [
            "scenario_visual_runtime",
            "knowledge_binding",
            "render_placeholder",
            "future_real_asset_replacement"
        ],
    })

registry = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_SCAFFOLD_V41B",
    "asset_root": "/trfmc_assets/visual_knowledge",
    "assets_count": len(registry_assets),
    "fallback_format": "svg",
    "real_render_expected_format": "jpg_or_webp",
    "assets": registry_assets,
    "safety": {
        "react_mutation": False,
        "backend_mutation": False,
        "nginx_mutation": False,
        "systemd_mutation": False,
        "static_assets_only": True,
    }
}

REGISTRY_V41.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")
# compatibility registry for old V36/V40 reference path
REGISTRY_V35_COMPAT.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")
created.extend([REGISTRY_V41, REGISTRY_V35_COMPAT])

# Optional compatibility: create lightweight SVG copies with .jpg filenames would be wrong MIME if served.
# Instead we keep expected jpg missing and provide registry fallback. V41R1 must use fallback_path.

# Checks
expected_paths = [
    "/trfmc_assets/visual_knowledge/01_electronics_symbols/electronics_symbols_basic_concepts.svg",
    "/trfmc_assets/visual_knowledge/02_antennas_microstrip/microstrip_patch_antenna_5g.svg",
    "/trfmc_assets/visual_knowledge/03_antennas_types/types_of_telecom_antennas.svg",
    "/trfmc_assets/visual_knowledge/03_antennas_types/beamwidth_narrow_wide.svg",
    "/trfmc_assets/visual_knowledge/04_telco_infrastructure/cellular_satellite_site_photo.svg",
    "/trfmc_assets/visual_knowledge/04_telco_infrastructure/telecom_towers_arabic_overview.svg",
    "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg",
    "/trfmc_assets/visual_knowledge/06_uav_rf_links/falco_xplorer_vs_bayraktar_tb2.svg",
    "/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json",
    "/trfmc_assets/visual_knowledge/visual_asset_registry_v35.json",
]

checks = []
for public_path in expected_paths:
    fs = PUBLIC / public_path.lstrip("/")
    checks.append(("OK" if fs.exists() and fs.stat().st_size > 0 else "MISS", public_path, fs.stat().st_size if fs.exists() else 0))

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {p} bytes={b}" for s,p,b in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s,_,_ in checks if s == "MISS")

# HTTP gate
http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/02_antennas_microstrip/microstrip_patch_antenna_5g.svg",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/03_antennas_types/beamwidth_narrow_wide.svg",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg",
    "http://127.0.0.1:4181/api/mission/status",
]
lines = ["url\tstatus\tbytes"]
for url in urls:
    pr = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}\t%{size_download}", "--connect-timeout", "2", "--max-time", "8", url],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if pr.returncode != 0:
        code, size = "000", "0"
    else:
        parts = pr.stdout.strip().split()
        code = parts[0] if len(parts) > 0 else "000"
        size = parts[1] if len(parts) > 1 else "0"
    lines.append(f"{url}\t{code}\t{size}")
http_tsv.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(http_tsv.read_text())

http_non_200 = sum(1 for line in lines[1:] if line.split("\t")[1] != "200")
http_zero_bytes = sum(1 for line in lines[1:] if line.split("\t")[2] == "0")

asset_inventory = RDIR / "visual_asset_scaffold_inventory_v41b.tsv"
with asset_inventory.open("w", encoding="utf-8") as f:
    f.write("public_path\tsize_bytes\ttype\n")
    for p in sorted(ASSET_ROOT.rglob("*")):
        if p.is_file():
            f.write(f"/{p.relative_to(PUBLIC)}\t{p.stat().st_size}\t{p.suffix.lower()}\n")

manifest = RDIR / "visual_asset_scaffold_manifest_v41b.json"
summary = QDIR / "summary.json"

result = "PASS"
if miss_count != 0 or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_SCAFFOLD_V41B",
    "strategy": "create_static_visual_asset_root_with_svg_fallback_registry",
    "frontend_mutation": False,
    "static_public_asset_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "asset_root": str(ASSET_ROOT),
    "registry_v41": str(REGISTRY_V41),
    "registry_v35_compat": str(REGISTRY_V35_COMPAT),
    "created_count": len(created),
    "pre_freeze": str(pre_freeze),
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_VISUAL_ASSET_SCAFFOLD_V41B",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "asset_inventory": str(asset_inventory),
    "asset_root": str(ASSET_ROOT),
    "registry_v41": str(REGISTRY_V41),
    "registry_v35_compat": str(REGISTRY_V35_COMPAT),
    "fallback_assets_count": len(assets),
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/public/trfmc_assets/visual_knowledge",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_visual_asset_scaffold_v41b"
latest_r = ROOT / "runtime/releases/latest_visual_asset_scaffold_v41b"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
