from pathlib import Path
import json
import subprocess
import time
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_RF_MICROWAVE_LAB_RENDER_V43D_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_RF_MICROWAVE_LAB_RENDER_V43D_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_RF_MICROWAVE_LAB_RENDER_V43D_{TS}.tar.gz"

PUBLIC_ROOT = ROOT / "frontend/public/trfmc_assets/visual_knowledge"
ACTIVE_REGISTRY = PUBLIC_ROOT / "visual_asset_registry_active.json"
REGISTRY_V43D = PUBLIC_ROOT / "visual_asset_registry_v43d.json"
RF_DIR = PUBLIC_ROOT / "05_rf_lab_visuals"

TARGET_PNG = RF_DIR / "rf_microwave_engineering_lab.png"
TARGET_SVG = RF_DIR / "rf_microwave_engineering_lab.svg"

MAIN = ROOT / "frontend/src/app/main.tsx"
VISUAL_COMPONENT = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
RF_DIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC RF/MICROWAVE LAB RENDER V43D")
print("replace roadmap image · coherent RF bench render · registry promotion")
print("=" * 60)

for rel in [
    "runtime/quality/latest_promote_staged_renders_v43c/summary.json",
    "runtime/quality/latest_copy_candidate_set_to_staging_v43b2/summary.json",
    "runtime/quality/latest_mission_layout_orchestrator_v42/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not ACTIVE_REGISTRY.exists():
    raise SystemExit("ERRORE: active registry mancante")

if not MAIN.exists() or "RFOperationalDeckV42MissionLayoutOrchestrator" not in MAIN.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: main.tsx non monta V42")

if not VISUAL_COMPONENT.exists() or "visual_asset_registry_active.json" not in VISUAL_COMPONENT.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: VisualAssetRuntimeV41 non usa registry active")

print("OK: V43C/V42 PASS, registry attivo e runtime visual configurati")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_RF_MICROWAVE_LAB_RENDER_V43D_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "frontend/public/trfmc_assets/visual_knowledge/05_rf_lab_visuals",
    "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json",
    "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_v43.json",
    "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_v43c.json",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def font(size, bold=False):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for c in candidates:
        if Path(c).exists():
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()

W, H = 1672, 941
img = Image.new("RGB", (W, H), (2, 8, 18))
draw = ImageDraw.Draw(img)

# Background gradients
for y in range(H):
    for x in range(W):
        # efficient enough for 1.5M pixels
        nx = x / W
        ny = y / H
        r = int(2 + 8 * ny + 8 * (1 - nx) * (1 - ny))
        g = int(10 + 28 * (1 - ny) + 12 * nx)
        b = int(22 + 42 * (1 - ny) + 14 * nx)
        img.putpixel((x, y), (r, g, b))

# Grid overlay
draw = ImageDraw.Draw(img, "RGBA")
for x in range(0, W, 64):
    draw.line((x, 0, x, H), fill=(60, 220, 255, 22), width=1)
for y in range(0, H, 54):
    draw.line((0, y, W, y), fill=(60, 220, 255, 18), width=1)

# Glow blobs
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse((90, 40, 720, 460), fill=(0, 180, 255, 38))
gd.ellipse((920, 0, 1650, 540), fill=(70, 255, 190, 28))
gd.ellipse((580, 520, 1380, 1040), fill=(0, 110, 255, 28))
glow = glow.filter(ImageFilter.GaussianBlur(70))
img = Image.alpha_composite(img.convert("RGBA"), glow)
draw = ImageDraw.Draw(img, "RGBA")

# Header
draw.rounded_rectangle((50, 42, 1622, 148), radius=28, fill=(4, 19, 33, 210), outline=(90, 235, 255, 95), width=2)
draw.text((82, 62), "TRFMC RF & MICROWAVE ENGINEERING LAB", fill=(235, 252, 255, 255), font=font(40, True))
draw.text((84, 112), "VNA · Spectrum Analyzer · RF Signal Generator · DUT · S-Parameters · Smith Chart · Power Sensor", fill=(130, 230, 255, 230), font=font(22))

# Workbench
draw.polygon([(70, 750), (1602, 750), (1540, 885), (130, 885)], fill=(22, 30, 40, 235), outline=(85, 230, 255, 80))
draw.line((118, 760, 1548, 760), fill=(110, 255, 220, 120), width=3)

# Instrument helper
def instrument(x, y, w, h, title, subtitle, screen_type):
    draw.rounded_rectangle((x+8, y+12, x+w+8, y+h+12), radius=18, fill=(0, 0, 0, 85))
    draw.rounded_rectangle((x, y, x+w, y+h), radius=18, fill=(10, 21, 34, 245), outline=(70, 220, 255, 120), width=2)
    draw.rectangle((x+22, y+28, x+w-140, y+h-44), fill=(0, 13, 22, 255), outline=(50, 210, 255, 90), width=2)
    draw.text((x+24, y+8), title, fill=(240, 252, 255, 255), font=font(19, True))
    draw.text((x+24, y+h-32), subtitle, fill=(135, 225, 255, 220), font=font(14))

    sx0, sy0, sx1, sy1 = x+22, y+28, x+w-140, y+h-44
    # screen grid
    for gx in range(sx0+20, sx1, 42):
        draw.line((gx, sy0+8, gx, sy1-8), fill=(0, 160, 190, 38), width=1)
    for gy in range(sy0+18, sy1, 28):
        draw.line((sx0+8, gy, sx1-8, gy), fill=(0, 160, 190, 35), width=1)

    if screen_type == "spectrum":
        pts = []
        for i in range(0, sx1-sx0-30):
            xx = sx0 + 15 + i
            import math
            yy = sy1 - 22 - 18*math.sin(i/42) - 10*math.sin(i/17)
            for peakx, amp, width in [(135, 78, 18), (305, 55, 14), (485, 92, 20), (630, 48, 12)]:
                yy -= amp * max(0, 1 - abs(i-peakx)/width)
            pts.append((xx, yy))
        draw.line(pts, fill=(0, 255, 236, 255), width=4)
        draw.line((sx0+15, sy1-22, sx1-15, sy1-22), fill=(120, 255, 170, 90), width=2)
        draw.text((sx0+26, sy0+18), "CENTER 3.500 GHz  SPAN 200 MHz", fill=(0,255,236,240), font=font(13, True))
    elif screen_type == "vna":
        # S11/S21 traces
        import math
        pts1, pts2 = [], []
        for i in range(0, sx1-sx0-30):
            xx = sx0 + 15 + i
            yy1 = sy0 + 52 + 22*math.sin(i/53) + 9*math.sin(i/17)
            yy2 = sy1 - 50 - 24*math.sin(i/47)
            pts1.append((xx, yy1))
            pts2.append((xx, yy2))
        draw.line(pts1, fill=(255, 205, 90, 255), width=3)
        draw.line(pts2, fill=(0, 255, 190, 255), width=3)
        draw.text((sx0+26, sy0+18), "S11 / S21  10 MHz → 26.5 GHz", fill=(255,230,120,240), font=font(13, True))
    elif screen_type == "smith":
        cx, cy = (sx0+sx1)//2, (sy0+sy1)//2
        r = min((sx1-sx0), (sy1-sy0))//2 - 18
        for rr in [r, int(r*.72), int(r*.48), int(r*.25)]:
            draw.ellipse((cx-rr, cy-rr, cx+rr, cy+rr), outline=(95,220,255,80), width=2)
        draw.line((cx-r, cy, cx+r, cy), fill=(95,220,255,80), width=2)
        draw.line((cx, cy-r, cx, cy+r), fill=(95,220,255,65), width=1)
        pts = []
        import math
        for t in range(0, 360, 4):
            a = math.radians(t)
            rr = r * (.40 + .23*math.sin(3*a))
            pts.append((cx + rr*math.cos(a), cy + rr*math.sin(a)))
        draw.line(pts, fill=(0,255,190,255), width=4)
        draw.text((sx0+26, sy0+18), "SMITH CHART  Γ / Z0=50Ω", fill=(0,255,190,240), font=font(13, True))

    # knobs/buttons
    bx = x+w-105
    for j in range(4):
        cy = y+48+j*44
        draw.ellipse((bx, cy, bx+28, cy+28), fill=(32, 50, 66, 255), outline=(140, 235, 255, 130), width=2)
        draw.rectangle((bx+44, cy+7, bx+88, cy+20), fill=(25,45,55,255), outline=(100,220,255,80))
    draw.text((x+w-112, y+h-32), "RF I/O", fill=(120,255,220,220), font=font(14, True))

# Instruments
instrument(70, 190, 500, 250, "VECTOR NETWORK ANALYZER", "S11 / S21 / CAL KIT / 50 Ω", "vna")
instrument(605, 190, 500, 250, "SIGNAL & SPECTRUM ANALYZER", "EVM / ACPR / OCCUPANCY / FFT", "spectrum")
instrument(1140, 190, 450, 250, "SMITH / MATCHING VIEW", "Γ · VSWR · impedance transform", "smith")

# DUT fixture and RF chain
draw.rounded_rectangle((510, 570, 1160, 700), radius=20, fill=(8, 18, 28, 238), outline=(90, 235, 255, 100), width=2)
draw.text((540, 588), "DEVICE UNDER TEST — RF FRONT-END / FILTER / PATCH FEED NETWORK", fill=(235,252,255,245), font=font(20, True))

# PCB
draw.rounded_rectangle((665, 625, 1005, 675), radius=8, fill=(20, 88, 74, 255), outline=(130,255,210,150), width=2)
draw.rectangle((728, 637, 815, 663), fill=(205, 145, 65, 255), outline=(255,205,130,120))
draw.rectangle((852, 636, 965, 664), fill=(32, 54, 68, 255), outline=(150,230,255,120))
for px in range(690, 990, 28):
    draw.ellipse((px, 646, px+7, 653), fill=(255, 210, 120, 240))

# Connectors and cables
def cable(points, color=(0, 235, 255, 230), width=5):
    draw.line(points, fill=color, width=width, joint="curve")

cable([(555, 550), (610, 585), (665, 650)], (0,230,255,225), 6)
cable([(1105, 550), (1050, 585), (1005, 650)], (120,255,190,225), 6)
cable([(320, 440), (480, 520), (665, 650)], (255,205,90,210), 5)
cable([(860, 440), (920, 535), (1005, 650)], (0,255,236,220), 5)
cable([(1370, 440), (1245, 545), (1005, 650)], (180,135,255,220), 5)

# RF components along cable
components = [
    (475, 520, "20 dB\nATT"),
    (610, 585, "DIR\nCOUPLER"),
    (1115, 550, "PWR\nSENSOR"),
    (1230, 545, "LO\nREF"),
]
for x, y, txt in components:
    draw.rounded_rectangle((x-38, y-24, x+38, y+24), radius=10, fill=(18,35,48,255), outline=(120,235,255,130), width=2)
    draw.text((x-26, y-16), txt, fill=(235,252,255,245), font=font(12, True))

# Measurement badges
badges = [
    (90, 790, "VNA CAL: SOLT / TRL"),
    (300, 790, "S-PARAMETERS: S11 · S21 · S22"),
    (600, 790, "SPECTRUM: ACPR · OBW · EVM"),
    (900, 790, "POWER: dBm · VSWR · RL"),
    (1160, 790, "REFERENCE: 10 MHz · PPS"),
    (1410, 790, "SAFETY: RX ONLY"),
]
for x, y, t in badges:
    draw.rounded_rectangle((x, y, x+190, y+44), radius=14, fill=(5, 35, 42, 220), outline=(85,255,210,90), width=1)
    draw.text((x+12, y+13), t, fill=(165,255,230,240), font=font(13, True))

# Footer watermark
draw.text((70, 890), "TRFMC Visual Knowledge Asset · RF/Microwave coherent render · generated V43D", fill=(120, 220, 255, 185), font=font(16))
draw.text((1290, 890), "source_mode: real-render", fill=(255, 210, 90, 220), font=font(16, True))

# Export PNG
img = img.convert("RGB")
img.save(TARGET_PNG, "PNG", optimize=True)

# Also write a lightweight SVG descriptor fallback/companion
TARGET_SVG.write_text(f'''<svg xmlns="http://www.w3.org/2000/svg" width="1672" height="941" viewBox="0 0 1672 941">
  <rect width="1672" height="941" fill="#020812"/>
  <text x="70" y="90" fill="#75eaff" font-family="Arial" font-size="42" font-weight="700">TRFMC RF &amp; MICROWAVE ENGINEERING LAB</text>
  <text x="70" y="145" fill="#f1fbff" font-family="Arial" font-size="24">VNA · Spectrum Analyzer · RF Signal Generator · DUT · S-Parameters · Smith Chart · Power Sensor</text>
  <rect x="70" y="210" width="1532" height="520" rx="28" fill="#06111f" stroke="#75eaff"/>
  <text x="110" y="300" fill="#8dffbd" font-family="Arial" font-size="30">Generated coherent PNG render available:</text>
  <text x="110" y="350" fill="#f1fbff" font-family="Arial" font-size="24">/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png</text>
</svg>
''', encoding="utf-8")

# Registry update
registry = json.loads(ACTIVE_REGISTRY.read_text(encoding="utf-8"))
registry["timestamp"] = TS
registry["operation"] = "TRFMC_RF_MICROWAVE_LAB_RENDER_V43D"
registry["rf_lab_render_policy"] = "replace_non_semantic_roadmap_image_with_coherent_rf_microwave_lab_render"
registry["active_registry"] = "/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"

found = False
for asset in registry.get("assets", []):
    if asset.get("id") == "rf_microwave_engineering_lab":
        found = True
        asset["public_path"] = "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png"
        asset["real_render_path"] = "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png"
        asset["fallback_path"] = "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg"
        asset["source_mode"] = "real-render"
        asset["real_render_source"] = "generated_locally_by_TRFMC_RF_MICROWAVE_LAB_RENDER_V43D"
        asset["real_render_imported_at"] = TS
        asset["import_note"] = "Roadmap/table image replaced by coherent RF/microwave laboratory render."
        asset["tags"] = ["VNA", "VSA", "Spectrum Analyzer", "Signal Generator", "Smith Chart", "S11/S21", "DUT", "Power Sensor", "RF Bench"]
        break

if not found:
    raise SystemExit("ERRORE: rf_microwave_engineering_lab non trovato nel registry")

ACTIVE_REGISTRY.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")
REGISTRY_V43D.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")

# Keep v43/v43c aligned when they exist
for p in [PUBLIC_ROOT / "visual_asset_registry_v43.json", PUBLIC_ROOT / "visual_asset_registry_v43c.json"]:
    if p.exists():
        p.write_text(json.dumps(registry, indent=2, ensure_ascii=False), encoding="utf-8")

# Checks
checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

registry_now = json.loads(ACTIVE_REGISTRY.read_text(encoding="utf-8"))
rf = next((a for a in registry_now.get("assets", []) if a.get("id") == "rf_microwave_engineering_lab"), {})

ok("RF lab PNG generated", TARGET_PNG.exists() and TARGET_PNG.stat().st_size > 0)
ok("RF lab SVG companion exists", TARGET_SVG.exists() and TARGET_SVG.stat().st_size > 0)
ok("RF lab registry source_mode real-render", rf.get("source_mode") == "real-render")
ok("RF lab registry path points to PNG", rf.get("real_render_path") == "/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png")
ok("RF lab fallback preserved", rf.get("fallback_path", "").endswith("rf_microwave_engineering_lab.svg"))
ok("registry V43D exists", REGISTRY_V43D.exists() and REGISTRY_V43D.stat().st_size > 0)
ok("V42 still active", "RFOperationalDeckV42MissionLayoutOrchestrator" in MAIN.read_text(encoding="utf-8"))

real_count = sum(1 for a in registry_now.get("assets", []) if a.get("source_mode") == "real-render")
review_count = sum(1 for a in registry_now.get("assets", []) if a.get("source_mode") == "real-render-review")
fallback_count = sum(1 for a in registry_now.get("assets", []) if a.get("source_mode") == "fallback")

ok("registry all eight assets are real-render", real_count == 8)
ok("registry has zero review assets", review_count == 0)
ok("registry has zero fallback active modes", fallback_count == 0)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\\n".join(f"{s}: {n}" for s, n in checks) + "\\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

# Build gate
build_log = RDIR / "npm_build_v43d.log"
with build_log.open("w") as f:
    build = subprocess.run(["npm", "run", "build"], cwd=ROOT / "frontend", stdout=f, stderr=subprocess.STDOUT)
build_result = "PASS" if build.returncode == 0 else "FAIL"
print(f"Build result: {build_result}")
if build_result == "FAIL":
    print(build_log.read_text(errors="ignore")[-6000:])

# HTTP gate
http_tsv = RDIR / "http.tsv"
urls = [
    "http://127.0.0.1:5173/",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v43d.json",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.png",
    "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/05_rf_lab_visuals/rf_microwave_engineering_lab.svg",
    "http://127.0.0.1:4181/api/mission/status",
]

lines = ["url\\tstatus\\tbytes"]
for url in urls:
    pr = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}\\t%{size_download}", "--connect-timeout", "2", "--max-time", "8", url],
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
    lines.append(f"{url}\\t{code}\\t{size}")

http_tsv.write_text("\\n".join(lines) + "\\n", encoding="utf-8")
print(http_tsv.read_text())

http_non_200 = sum(1 for line in lines[1:] if line.split("\\t")[1] != "200")
http_zero_bytes = sum(1 for line in lines[1:] if line.split("\\t")[2] == "0")

rollback = RDIR / "rollback_v43d_rf_microwave_lab_render.sh"
rollback.write_text(f'''#!/usr/bin/env bash
set -Eeuo pipefail
cd "{ROOT}"
tar -xzf "{pre_freeze}" -C /
echo "Rollback V43D completato usando pre-freeze: {pre_freeze}"
''', encoding="utf-8")
rollback.chmod(0o755)

result = "PASS"
if miss_count != 0 or build_result == "FAIL" or http_non_200 != 0:
    result = "FAIL"
elif http_zero_bytes != 0:
    result = "WARN"

manifest = RDIR / "rf_microwave_lab_render_manifest_v43d.json"
summary = QDIR / "summary.json"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_RF_MICROWAVE_LAB_RENDER_V43D",
    "strategy": "generate_coherent_rf_microwave_lab_render_and_replace_non_semantic_roadmap",
    "frontend_mutation": False,
    "static_public_asset_mutation": True,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "target_png": str(TARGET_PNG),
    "target_svg": str(TARGET_SVG),
    "registry_active": str(ACTIVE_REGISTRY),
    "registry_v43d": str(REGISTRY_V43D),
    "pre_freeze": str(pre_freeze),
    "rollback": str(rollback),
    "real_render_count": real_count,
    "review_count": review_count,
    "fallback_count": fallback_count,
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_RF_MICROWAVE_LAB_RENDER_V43D",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "build_log": str(build_log),
    "rollback": str(rollback),
    "target_png": str(TARGET_PNG),
    "target_svg": str(TARGET_SVG),
    "registry_active": str(ACTIVE_REGISTRY),
    "registry_v43d": str(REGISTRY_V43D),
    "active_mount": "RFOperationalDeckV42MissionLayoutOrchestrator",
    "real_render_count": real_count,
    "review_count": review_count,
    "fallback_count": fallback_count,
    "miss_count": miss_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "build_result": build_result,
    "result": result
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "frontend/public/trfmc_assets/visual_knowledge/05_rf_lab_visuals",
    "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json",
    "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_v43d.json",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_rf_microwave_lab_render_v43d"
latest_r = ROOT / "runtime/releases/latest_rf_microwave_lab_render_v43d"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
