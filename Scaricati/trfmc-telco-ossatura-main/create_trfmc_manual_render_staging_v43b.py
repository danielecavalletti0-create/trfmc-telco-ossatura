from pathlib import Path
import json
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_MANUAL_RENDER_STAGING_V43B_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_MANUAL_RENDER_STAGING_V43B_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_MANUAL_RENDER_STAGING_V43B_{TS}.tar.gz"

STAGING_ROOT = ROOT / "runtime/staging/visual_renders_v43"
PUBLIC_ASSET_ROOT = ROOT / "frontend/public/trfmc_assets/visual_knowledge"
ACTIVE_REGISTRY = PUBLIC_ASSET_ROOT / "visual_asset_registry_active.json"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC MANUAL RENDER STAGING V43B")
print("staging folders · naming matrix · no active portal mutation")
print("=" * 60)

for rel in [
    "runtime/quality/latest_real_render_visual_qa_v43r1r1/summary.json",
    "runtime/quality/latest_safe_single_render_import_v43r1/summary.json",
    "runtime/quality/latest_mission_layout_orchestrator_v42/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not ACTIVE_REGISTRY.exists():
    raise SystemExit("ERRORE: visual_asset_registry_active.json mancante")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_active.json"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0 or "TRFMC_SAFE_SINGLE_RENDER_IMPORT_V43R1" not in probe.stdout:
    raise SystemExit("ERRORE: registry active non servito o non aggiornato a V43R1")

print("OK: V43R1R1/V43R1/V42 PASS e active registry servito")

registry = json.loads(ACTIVE_REGISTRY.read_text(encoding="utf-8"))
assets = registry.get("assets", [])

missing_assets = [
    asset for asset in assets
    if asset.get("source_mode") != "real-render"
]

# Conservative: expected missing count is 7 because one real render is already imported.
if len(missing_assets) != 7:
    print(f"ATTENZIONE: numero missing assets diverso da 7: {len(missing_assets)}")

# Target filenames are stable and explicit. We accept common image formats in staging.
accepted_ext = [".png", ".jpg", ".jpeg", ".webp"]

staging_items = []
for asset in missing_assets:
    asset_id = asset.get("id", "")
    category = asset.get("category", "uncategorized")
    title = asset.get("title", asset_id)
    folder = STAGING_ROOT / category / asset_id
    folder.mkdir(parents=True, exist_ok=True)

    target_public_path = asset.get("expected_real_render_path") or asset.get("real_render_path") or ""
    if not target_public_path:
        target_public_path = f"/trfmc_assets/visual_knowledge/{category}/{asset_id}.png"

    basename = Path(target_public_path).stem

    readme = folder / "README_RENDER_REQUIREMENTS.md"
    readme.write_text(f"""# Render staging: {title}

Asset ID: `{asset_id}`  
Category: `{category}`  
Current mode: `{asset.get("source_mode", "fallback")}`  
Fallback: `{asset.get("fallback_path", "")}`  
Target public path: `{target_public_path}`

## File da inserire qui

Inserisci **uno** dei seguenti file, preferibilmente PNG o WEBP:

- `{basename}.png`
- `{basename}.webp`
- `{basename}.jpg`
- `{basename}.jpeg`

## Requisiti consigliati

- Risoluzione minima: 1600x900
- Rapporto consigliato: 16:9
- Stile: tecnico, realistico, coerente con portale TRFMC
- No loghi casuali, no screenshot non pertinenti, no watermark
- Deve rappresentare il concetto dell’asset, non una generica immagine decorativa

## Promozione

Quando il file è presente, la fase `V43C Promote Staged Renders` copierà il render nel path pubblico stabile e aggiornerà il registry attivo.
""", encoding="utf-8")

    staging_items.append({
        "asset_id": asset_id,
        "title": title,
        "category": category,
        "staging_folder": str(folder),
        "accepted_filenames": [f"{basename}{ext}" for ext in accepted_ext],
        "target_public_path": target_public_path,
        "fallback_path": asset.get("fallback_path", ""),
        "current_source_mode": asset.get("source_mode", ""),
        "readme": str(readme),
    })

# Create master README
STAGING_ROOT.mkdir(parents=True, exist_ok=True)
master_readme = STAGING_ROOT / "README_VISUAL_RENDER_STAGING_V43.md"
master_readme.write_text("""# TRFMC V43 Manual Render Staging

Questa cartella serve a inserire i render reali mancanti prima della promozione nel portale.

## Regola operativa

Non copiare immagini direttamente in `frontend/public/trfmc_assets/visual_knowledge`.
Metti i file nelle sottocartelle di staging. La fase V43C farà:

1. validazione presenza file;
2. copia controllata nel path pubblico stabile;
3. aggiornamento registry;
4. build gate;
5. HTTP gate;
6. visual QA.

## Asset già reale

- `rf_microwave_engineering_lab` è già in modalità `real-render`.

## Asset ancora da popolare

Vedi `manual_render_staging_matrix_v43b.tsv`.

## Formati accettati

- `.png`
- `.webp`
- `.jpg`
- `.jpeg`

Consigliato: 1600x900 o superiore.
""", encoding="utf-8")

# Write staging matrix
matrix_tsv = RDIR / "manual_render_staging_matrix_v43b.tsv"
matrix_json = RDIR / "manual_render_staging_matrix_v43b.json"

with matrix_tsv.open("w", encoding="utf-8") as f:
    f.write("asset_id\ttitle\tcategory\tstaging_folder\taccepted_filenames\ttarget_public_path\tfallback_path\n")
    for item in staging_items:
        f.write(
            f"{item['asset_id']}\t{item['title']}\t{item['category']}\t{item['staging_folder']}\t"
            f"{','.join(item['accepted_filenames'])}\t{item['target_public_path']}\t{item['fallback_path']}\n"
        )

matrix_json.write_text(json.dumps(staging_items, indent=2, ensure_ascii=False), encoding="utf-8")

# Create empty placeholder marker, not an image, to avoid accidental promotion.
for item in staging_items:
    marker = Path(item["staging_folder"]) / ".put_real_render_here"
    marker.write_text(
        "Place one accepted real render file in this folder. Do not rename this marker as an image.\n",
        encoding="utf-8",
    )

# Scan staging current status
scan_rows = []
for item in staging_items:
    folder = Path(item["staging_folder"])
    found = []
    for name in item["accepted_filenames"]:
        p = folder / name
        if p.exists() and p.is_file() and p.stat().st_size > 0:
            found.append({
                "filename": name,
                "path": str(p),
                "size_bytes": p.stat().st_size,
            })
    scan_rows.append({
        "asset_id": item["asset_id"],
        "staging_folder": item["staging_folder"],
        "found_count": len(found),
        "found": found,
        "ready_for_promotion": len(found) == 1,
        "ambiguous": len(found) > 1,
    })

scan_json = RDIR / "manual_render_staging_scan_v43b.json"
scan_tsv = RDIR / "manual_render_staging_scan_v43b.tsv"

scan_json.write_text(json.dumps(scan_rows, indent=2, ensure_ascii=False), encoding="utf-8")
with scan_tsv.open("w", encoding="utf-8") as f:
    f.write("asset_id\tfound_count\tready_for_promotion\tambiguous\tstaging_folder\n")
    for row in scan_rows:
        f.write(f"{row['asset_id']}\t{row['found_count']}\t{row['ready_for_promotion']}\t{row['ambiguous']}\t{row['staging_folder']}\n")

ready_count = sum(1 for row in scan_rows if row["ready_for_promotion"])
ambiguous_count = sum(1 for row in scan_rows if row["ambiguous"])
missing_count = len(scan_rows) - ready_count - ambiguous_count

content_checks = RDIR / "content_checks.txt"
checks = []

def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

ok("staging root exists", STAGING_ROOT.exists())
ok("master README exists", master_readme.exists() and master_readme.stat().st_size > 0)
ok("staging matrix JSON exists", matrix_json.exists() and matrix_json.stat().st_size > 0)
ok("staging matrix TSV exists", matrix_tsv.exists() and matrix_tsv.stat().st_size > 0)
ok("active registry exists", ACTIVE_REGISTRY.exists())
ok("seven fallback assets staged", len(staging_items) == 7)

for item in staging_items:
    ok(f"folder exists for {item['asset_id']}", Path(item["staging_folder"]).exists())
    ok(f"README exists for {item['asset_id']}", Path(item["readme"]).exists())

content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

manifest = RDIR / "manual_render_staging_manifest_v43b.json"
summary = QDIR / "summary.json"

result = "PASS" if miss_count == 0 else "FAIL"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_MANUAL_RENDER_STAGING_V43B",
    "strategy": "create_manual_staging_folders_for_missing_real_renders_without_active_portal_mutation",
    "frontend_mutation": False,
    "static_public_asset_mutation": False,
    "runtime_staging_mutation": True,
    "backend_mutation": False,
    "dist_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "staging_root": str(STAGING_ROOT),
    "master_readme": str(master_readme),
    "matrix_tsv": str(matrix_tsv),
    "matrix_json": str(matrix_json),
    "scan_tsv": str(scan_tsv),
    "scan_json": str(scan_json),
    "staged_assets_count": len(staging_items),
    "ready_for_promotion_count": ready_count,
    "ambiguous_count": ambiguous_count,
    "missing_staged_files_count": missing_count,
    "miss_count": miss_count,
    "result": result,
}
manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_MANUAL_RENDER_STAGING_V43B",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "content_checks": str(content_checks),
    "staging_root": str(STAGING_ROOT),
    "master_readme": str(master_readme),
    "matrix_tsv": str(matrix_tsv),
    "matrix_json": str(matrix_json),
    "scan_tsv": str(scan_tsv),
    "scan_json": str(scan_json),
    "staged_assets_count": len(staging_items),
    "ready_for_promotion_count": ready_count,
    "ambiguous_count": ambiguous_count,
    "missing_staged_files_count": missing_count,
    "miss_count": miss_count,
    "result": result,
}
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    "runtime/staging/visual_renders_v43",
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_manual_render_staging_v43b"
latest_r = ROOT / "runtime/releases/latest_manual_render_staging_v43b"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
