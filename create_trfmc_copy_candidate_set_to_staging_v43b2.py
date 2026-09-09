from pathlib import Path
import csv
import json
import shutil
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_COPY_CANDIDATE_SET_TO_STAGING_V43B2_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_COPY_CANDIDATE_SET_TO_STAGING_V43B2_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_COPY_CANDIDATE_SET_TO_STAGING_V43B2_{TS}.tar.gz"

CANDIDATE_TSV = ROOT / "runtime/releases/latest_candidate_image_review_v43b1/candidate_images_v43b1.tsv"
STAGING_ROOT = ROOT / "runtime/staging/visual_renders_v43"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC COPY CANDIDATE SET TO STAGING V43B2")
print("selected candidate images · staging only · no portal promotion")
print("=" * 60)

for rel in [
    "runtime/quality/latest_candidate_image_review_v43b1/summary.json",
    "runtime/quality/latest_manual_render_staging_v43b/summary.json",
    "runtime/quality/latest_real_render_visual_qa_v43r1r1/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not CANDIDATE_TSV.exists():
    raise SystemExit(f"ERRORE: candidate TSV mancante: {CANDIDATE_TSV}")

if not STAGING_ROOT.exists():
    raise SystemExit(f"ERRORE: staging root mancante: {STAGING_ROOT}")

print("OK: V43B1/V43B/V43R1R1 PASS, staging disponibile")

selected_indices = [1, 5, 7, 8, 10, 11, 12, 14, 15, 16, 17]

asset_order = [
    {
        "asset_id": "electronics_symbols_basic_concepts",
        "category": "01_electronics_symbols",
        "folder": STAGING_ROOT / "01_electronics_symbols/electronics_symbols_basic_concepts",
    },
    {
        "asset_id": "microstrip_patch_antenna_5g",
        "category": "02_antennas_microstrip",
        "folder": STAGING_ROOT / "02_antennas_microstrip/microstrip_patch_antenna_5g",
    },
    {
        "asset_id": "types_of_telecom_antennas",
        "category": "03_antennas_types",
        "folder": STAGING_ROOT / "03_antennas_types/types_of_telecom_antennas",
    },
    {
        "asset_id": "beamwidth_narrow_wide",
        "category": "03_antennas_types",
        "folder": STAGING_ROOT / "03_antennas_types/beamwidth_narrow_wide",
    },
    {
        "asset_id": "telecom_towers_arabic_overview",
        "category": "04_telco_infrastructure",
        "folder": STAGING_ROOT / "04_telco_infrastructure/telecom_towers_arabic_overview",
    },
    {
        "asset_id": "cellular_satellite_site_photo",
        "category": "04_telco_infrastructure",
        "folder": STAGING_ROOT / "04_telco_infrastructure/cellular_satellite_site_photo",
    },
    {
        "asset_id": "falco_xplorer_vs_bayraktar_tb2",
        "category": "06_uav_rf_links",
        "folder": STAGING_ROOT / "06_uav_rf_links/falco_xplorer_vs_bayraktar_tb2",
    },
]

assigned_indices = selected_indices[:7]
alternative_indices = selected_indices[7:]

candidates = {}
with CANDIDATE_TSV.open("r", encoding="utf-8", errors="ignore") as f:
    reader = csv.DictReader(f, delimiter="\t")
    for row in reader:
        try:
            idx = int(row["index"])
        except Exception:
            continue
        candidates[idx] = row

missing_indices = [idx for idx in selected_indices if idx not in candidates]
if missing_indices:
    raise SystemExit(f"ERRORE: indici candidati non trovati nel TSV: {missing_indices}")

pre_freeze = ROOT / f"runtime/freezes/TRFMC_BEFORE_COPY_CANDIDATE_SET_TO_STAGING_V43B2_{TS}.tar.gz"
subprocess.run([
    "tar", "-czf", str(pre_freeze),
    "runtime/staging/visual_renders_v43",
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

assignments = []
alternatives = []
accepted_ext = {".png", ".jpg", ".jpeg", ".webp"}

for asset, idx in zip(asset_order, assigned_indices):
    folder = asset["folder"]
    folder.mkdir(parents=True, exist_ok=True)

    # Pulizia controllata: elimina solo immagini già presenti nella cartella asset,
    # non README né marker.
    for p in folder.iterdir():
        if p.is_file() and p.suffix.lower() in accepted_ext:
            p.unlink()

    row = candidates[idx]
    src = Path(row["path"])
    if not src.exists():
        raise SystemExit(f"ERRORE: source candidate non trovato: {src}")

    ext = src.suffix.lower()
    if ext not in accepted_ext:
        raise SystemExit(f"ERRORE: estensione non accettata per {src}")

    dst = folder / f"{asset['asset_id']}{ext}"
    shutil.copy2(src, dst)

    assignments.append({
        "asset_id": asset["asset_id"],
        "category": asset["category"],
        "candidate_index": idx,
        "source_path": str(src),
        "target_staging_path": str(dst),
        "target_filename": dst.name,
        "size_bytes": dst.stat().st_size,
        "width": row.get("width"),
        "height": row.get("height"),
        "ratio": row.get("ratio"),
        "notes": row.get("notes"),
        "decision": "assigned_to_staging",
    })

alt_root = STAGING_ROOT / "_alternatives_v43b2"
alt_root.mkdir(parents=True, exist_ok=True)

for idx in alternative_indices:
    row = candidates[idx]
    src = Path(row["path"])
    if not src.exists():
        raise SystemExit(f"ERRORE: alternative source candidate non trovato: {src}")

    dst = alt_root / f"candidate_{idx:03d}_{src.name}"
    shutil.copy2(src, dst)

    alternatives.append({
        "candidate_index": idx,
        "source_path": str(src),
        "alternative_path": str(dst),
        "size_bytes": dst.stat().st_size,
        "width": row.get("width"),
        "height": row.get("height"),
        "ratio": row.get("ratio"),
        "notes": row.get("notes"),
        "decision": "alternative_not_promoted",
    })

assignment_json = RDIR / "candidate_assignments_v43b2.json"
assignment_tsv = RDIR / "candidate_assignments_v43b2.tsv"
alternatives_json = RDIR / "candidate_alternatives_v43b2.json"
scan_tsv = RDIR / "staging_scan_after_v43b2.tsv"
scan_json = RDIR / "staging_scan_after_v43b2.json"

assignment_json.write_text(json.dumps(assignments, indent=2, ensure_ascii=False), encoding="utf-8")
alternatives_json.write_text(json.dumps(alternatives, indent=2, ensure_ascii=False), encoding="utf-8")

with assignment_tsv.open("w", encoding="utf-8") as f:
    f.write("asset_id\tcandidate_index\tsource_path\ttarget_staging_path\tsize_bytes\twidth\theight\tratio\tnotes\n")
    for a in assignments:
        f.write(
            f"{a['asset_id']}\t{a['candidate_index']}\t{a['source_path']}\t{a['target_staging_path']}\t"
            f"{a['size_bytes']}\t{a['width']}\t{a['height']}\t{a['ratio']}\t{a['notes']}\n"
        )

scan_rows = []
for asset in asset_order:
    folder = asset["folder"]
    found = []

    for p in sorted(folder.iterdir()):
        if p.is_file() and p.suffix.lower() in accepted_ext:
            found.append({
                "path": str(p),
                "filename": p.name,
                "size_bytes": p.stat().st_size,
            })

    scan_rows.append({
        "asset_id": asset["asset_id"],
        "folder": str(folder),
        "found_count": len(found),
        "ready_for_promotion": len(found) == 1,
        "ambiguous": len(found) > 1,
        "found": found,
    })

scan_json.write_text(json.dumps(scan_rows, indent=2, ensure_ascii=False), encoding="utf-8")

with scan_tsv.open("w", encoding="utf-8") as f:
    f.write("asset_id\tfound_count\tready_for_promotion\tambiguous\tfolder\n")
    for r in scan_rows:
        f.write(f"{r['asset_id']}\t{r['found_count']}\t{r['ready_for_promotion']}\t{r['ambiguous']}\t{r['folder']}\n")

ready_count = sum(1 for r in scan_rows if r["ready_for_promotion"])
ambiguous_count = sum(1 for r in scan_rows if r["ambiguous"])
missing_count = sum(1 for r in scan_rows if r["found_count"] == 0)

checks = []
def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

ok("seven assignments created", len(assignments) == 7)
ok("four alternatives copied", len(alternatives) == 4)
ok("ready_for_promotion_count is 7", ready_count == 7)
ok("ambiguous_count is 0", ambiguous_count == 0)
ok("missing_count is 0", missing_count == 0)
ok("assignment TSV exists", assignment_tsv.exists() and assignment_tsv.stat().st_size > 0)
ok("scan TSV exists", scan_tsv.exists() and scan_tsv.stat().st_size > 0)

for a in assignments:
    path = Path(a["target_staging_path"])
    ok(f"staging file exists for {a['asset_id']}", path.exists() and path.stat().st_size > 0)

content_checks = RDIR / "content_checks.txt"
content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")

manifest = RDIR / "copy_candidate_set_to_staging_manifest_v43b2.json"
summary = QDIR / "summary.json"

result = "PASS" if miss_count == 0 else "FAIL"

manifest_data = {
    "timestamp": TS,
    "operation": "TRFMC_COPY_CANDIDATE_SET_TO_STAGING_V43B2",
    "strategy": "copy_operator_selected_candidate_indices_to_render_staging_only",
    "frontend_mutation": False,
    "static_public_asset_mutation": False,
    "runtime_staging_mutation": True,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "selected_indices": selected_indices,
    "assigned_indices": assigned_indices,
    "alternative_indices": alternative_indices,
    "pre_freeze": str(pre_freeze),
    "assignment_tsv": str(assignment_tsv),
    "assignment_json": str(assignment_json),
    "alternatives_json": str(alternatives_json),
    "scan_tsv": str(scan_tsv),
    "scan_json": str(scan_json),
    "ready_for_promotion_count": ready_count,
    "ambiguous_count": ambiguous_count,
    "missing_count": missing_count,
    "miss_count": miss_count,
    "result": result,
}

manifest.write_text(json.dumps(manifest_data, indent=2, ensure_ascii=False), encoding="utf-8")

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_COPY_CANDIDATE_SET_TO_STAGING_V43B2",
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "pre_freeze": str(pre_freeze),
    "content_checks": str(content_checks),
    "assignment_tsv": str(assignment_tsv),
    "assignment_json": str(assignment_json),
    "alternatives_json": str(alternatives_json),
    "scan_tsv": str(scan_tsv),
    "scan_json": str(scan_json),
    "selected_indices": selected_indices,
    "assigned_indices": assigned_indices,
    "alternative_indices": alternative_indices,
    "ready_for_promotion_count": ready_count,
    "ambiguous_count": ambiguous_count,
    "missing_count": missing_count,
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

latest_q = ROOT / "runtime/quality/latest_copy_candidate_set_to_staging_v43b2"
latest_r = ROOT / "runtime/releases/latest_copy_candidate_set_to_staging_v43b2"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result != "PASS":
    raise SystemExit(1)
