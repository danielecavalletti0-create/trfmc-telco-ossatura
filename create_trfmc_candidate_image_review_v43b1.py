from pathlib import Path
import json
import shutil
import subprocess
import time
from PIL import Image, ImageOps, ImageDraw, ImageFont

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_CANDIDATE_IMAGE_REVIEW_V43B1_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_CANDIDATE_IMAGE_REVIEW_V43B1_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_CANDIDATE_IMAGE_REVIEW_V43B1_{TS}.tar.gz"

SOURCE_DIRS = [
    Path("/home/sentinel/Scaricati"),
    Path("/mnt/data"),
]

STAGING_ROOT = ROOT / "runtime/staging/visual_renders_v43"
ACTIVE_REGISTRY = ROOT / "frontend/public/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC CANDIDATE IMAGE REVIEW V43B1")
print("read-only · existing image candidate review · no promotion")
print("=" * 60)

for rel in [
    "runtime/quality/latest_manual_render_staging_v43b/summary.json",
    "runtime/quality/latest_real_render_visual_qa_v43r1r1/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not ACTIVE_REGISTRY.exists():
    raise SystemExit("ERRORE: active registry mancante")

print("OK: V43B/V43R1R1 PASS, active registry presente")

image_ext = {".png", ".jpg", ".jpeg", ".webp"}
candidates = []

for base in SOURCE_DIRS:
    if not base.exists():
        continue

    for p in base.rglob("*"):
        if not p.is_file():
            continue

        if p.suffix.lower() not in image_ext:
            continue

        low = str(p).lower()

        # Evita screenshot/runtime già generati dal portale.
        if "trfmc_full_telco_ossatura" in low and "runtime/releases" in low:
            continue
        if "node_modules" in low or ".git" in low:
            continue

        try:
            size = p.stat().st_size
            if size < 50000:
                continue
        except Exception:
            continue

        meta = {
            "path": str(p),
            "filename": p.name,
            "ext": p.suffix.lower(),
            "size_bytes": size,
            "width": None,
            "height": None,
            "ratio": None,
            "valid_image": False,
            "notes": [],
        }

        try:
            with Image.open(p) as img:
                meta["width"] = img.width
                meta["height"] = img.height
                meta["ratio"] = round(img.width / img.height, 4) if img.height else None
                meta["valid_image"] = True
                if img.width >= 1400 and img.height >= 800:
                    meta["notes"].append("good_resolution")
                if 1.65 <= (img.width / img.height) <= 1.90:
                    meta["notes"].append("near_16_9")
                if "chatgpt image" in p.name.lower():
                    meta["notes"].append("chatgpt_generated_candidate")
        except Exception as exc:
            meta["notes"].append(f"image_open_error:{exc}")

        candidates.append(meta)

candidates.sort(key=lambda x: (-int(x["valid_image"]), -x["size_bytes"], x["filename"]))

# Crea contact sheet
thumb_dir = RDIR / "candidate_thumbnails"
thumb_dir.mkdir(parents=True, exist_ok=True)

thumbs = []
for idx, item in enumerate(candidates, start=1):
    if not item["valid_image"]:
        continue
    src = Path(item["path"])
    thumb_path = thumb_dir / f"{idx:03d}_{src.stem[:80]}.jpg"

    try:
        with Image.open(src) as img:
            img = img.convert("RGB")
            img = ImageOps.contain(img, (320, 180))
            canvas = Image.new("RGB", (320, 230), (5, 17, 31))
            x = (320 - img.width) // 2
            y = 8
            canvas.paste(img, (x, y))
            draw = ImageDraw.Draw(canvas)
            text = f"{idx:03d} · {src.name[:34]}"
            draw.text((10, 194), text, fill=(241, 251, 255))
            draw.text((10, 212), f"{item['width']}x{item['height']} · {item['size_bytes']//1024} KB", fill=(117, 234, 255))
            canvas.save(thumb_path, quality=88)
            thumbs.append((idx, item, thumb_path))
    except Exception:
        pass

cols = 4
rows = max(1, (len(thumbs) + cols - 1) // cols)
sheet = Image.new("RGB", (cols * 320, rows * 230), (2, 8, 18))

for n, (_, _, thumb_path) in enumerate(thumbs):
    with Image.open(thumb_path) as t:
        x = (n % cols) * 320
        y = (n // cols) * 230
        sheet.paste(t.convert("RGB"), (x, y))

contact_sheet = RDIR / "candidate_contact_sheet_v43b1.jpg"
sheet.save(contact_sheet, quality=90)

# Matrice manuale vuota da compilare
assets_missing = [
    "electronics_symbols_basic_concepts",
    "microstrip_patch_antenna_5g",
    "types_of_telecom_antennas",
    "beamwidth_narrow_wide",
    "telecom_towers_arabic_overview",
    "cellular_satellite_site_photo",
    "falco_xplorer_vs_bayraktar_tb2",
]

manual_mapping = RDIR / "manual_candidate_mapping_v43b1.tsv"
with manual_mapping.open("w", encoding="utf-8") as f:
    f.write("asset_id\tcandidate_index\tcandidate_path\tdecision\toperator_note\n")
    for asset_id in assets_missing:
        f.write(f"{asset_id}\t\t\tpending\t\n")

candidate_tsv = RDIR / "candidate_images_v43b1.tsv"
with candidate_tsv.open("w", encoding="utf-8") as f:
    f.write("index\tfilename\twidth\theight\tratio\tsize_bytes\tnotes\tpath\n")
    for idx, item in enumerate(candidates, start=1):
        f.write(
            f"{idx}\t{item['filename']}\t{item['width']}\t{item['height']}\t{item['ratio']}\t"
            f"{item['size_bytes']}\t{','.join(item['notes'])}\t{item['path']}\n"
        )

candidate_json = RDIR / "candidate_images_v43b1.json"
candidate_json.write_text(json.dumps(candidates, indent=2, ensure_ascii=False), encoding="utf-8")

plan = RDIR / "candidate_review_plan_v43b1.md"
plan.write_text(f"""# TRFMC V43B1 Candidate Image Review

## Stato

Candidate image count: `{len(candidates)}`  
Valid thumbnail count: `{len(thumbs)}`  
Contact sheet: `{contact_sheet}`

## Uso

1. Aprire il contact sheet.
2. Scegliere per ogni asset mancante il numero candidato corretto.
3. Compilare `manual_candidate_mapping_v43b1.tsv`.
4. Copiare manualmente le immagini approvate nelle cartelle staging V43B.
5. Eseguire V43C solo quando `ready_for_promotion_count > 0`.

## Asset mancanti

- electronics_symbols_basic_concepts
- microstrip_patch_antenna_5g
- types_of_telecom_antennas
- beamwidth_narrow_wide
- telecom_towers_arabic_overview
- cellular_satellite_site_photo
- falco_xplorer_vs_bayraktar_tb2

## Nota

Questa fase è read-only: non promuove immagini nel portale.
""", encoding="utf-8")

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

ok("candidate TSV exists", candidate_tsv.exists() and candidate_tsv.stat().st_size > 0)
ok("candidate JSON exists", candidate_json.exists() and candidate_json.stat().st_size > 0)
ok("contact sheet exists", contact_sheet.exists() and contact_sheet.stat().st_size > 0)
ok("manual mapping TSV exists", manual_mapping.exists() and manual_mapping.stat().st_size > 0)
ok("staging root exists", STAGING_ROOT.exists())

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_CANDIDATE_IMAGE_REVIEW_V43B1",
    "release_dir": str(RDIR),
    "freeze": str(FREEZE),
    "frontend_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "candidate_count": len(candidates),
    "thumbnail_count": len(thumbs),
    "contact_sheet": str(contact_sheet),
    "candidate_tsv": str(candidate_tsv),
    "candidate_json": str(candidate_json),
    "manual_mapping": str(manual_mapping),
    "plan": str(plan),
    "content_checks": str(content_checks),
    "miss_count": miss_count,
    "result": "PASS" if miss_count == 0 else "FAIL",
}

summary = QDIR / "summary.json"
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

manifest = RDIR / "candidate_image_review_manifest_v43b1.json"
manifest.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_candidate_image_review_v43b1"
latest_r = ROOT / "runtime/releases/latest_candidate_image_review_v43b1"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if summary_data["result"] != "PASS":
    raise SystemExit(1)
