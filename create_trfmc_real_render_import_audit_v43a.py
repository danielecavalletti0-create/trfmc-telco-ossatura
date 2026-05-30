from pathlib import Path
import json
import re
import subprocess
import time

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")

QDIR = ROOT / f"runtime/quality/TRFMC_REAL_RENDER_IMPORT_AUDIT_V43A_{TS}"
RDIR = ROOT / f"runtime/releases/TRFMC_REAL_RENDER_IMPORT_AUDIT_V43A_{TS}"
FREEZE = ROOT / f"runtime/freezes/TRFMC_REAL_RENDER_IMPORT_AUDIT_V43A_{TS}.tar.gz"

PUBLIC = ROOT / "frontend/public"
ASSET_ROOT = PUBLIC / "trfmc_assets/visual_knowledge"
REGISTRY_V41 = ASSET_ROOT / "visual_asset_registry_v41_fallback.json"

QDIR.mkdir(parents=True, exist_ok=True)
RDIR.mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

print("=" * 60)
print("TRFMC REAL RENDER IMPORT AUDIT V43A")
print("read-only · candidate render discovery · replacement matrix")
print("=" * 60)

for rel in [
    "runtime/quality/latest_runtime_visual_qa_v42r1/summary.json",
    "runtime/quality/latest_mission_layout_orchestrator_v42/summary.json",
    "runtime/quality/latest_visual_asset_runtime_binding_v41r1/summary.json",
    "runtime/quality/latest_visual_asset_scaffold_v41b/summary.json",
]:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

if not REGISTRY_V41.exists():
    raise SystemExit("ERRORE: registry V41 fallback mancante")

probe = subprocess.run(
    ["curl", "-fsS", "--connect-timeout", "2", "--max-time", "8", "http://127.0.0.1:5173/trfmc_assets/visual_knowledge/visual_asset_registry_v41_fallback.json"],
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
if probe.returncode != 0 or "TRFMC_VISUAL_ASSET_SCAFFOLD_V41B" not in probe.stdout:
    raise SystemExit("ERRORE: registry V41 non servito correttamente da Vite")

print("OK: V42/V41 PASS e registry asset servito")

registry = json.loads(REGISTRY_V41.read_text(encoding="utf-8"))
registry_assets = registry.get("assets", [])

image_ext = {".jpg", ".jpeg", ".png", ".webp"}
model_ext = {".glb", ".gltf", ".obj"}

search_roots = [
    ROOT / "frontend/public",
    ROOT / "frontend/src",
    ROOT / "runtime",
    ROOT / "assets",
    ROOT / "images",
    ROOT / "renders",
    Path.home() / "Scaricati",
    Path("/mnt/data"),
]

ignore_parts = {
    "node_modules",
    ".git",
    "dist",
    "__pycache__",
}

def is_ignored(path: Path) -> bool:
    return any(part in ignore_parts for part in path.parts)

def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except Exception:
        return str(path)

def tokenize(text: str):
    tokens = re.split(r"[^a-z0-9]+", text.lower())
    return {t for t in tokens if len(t) >= 3}

asset_keywords = {
    "electronics_symbols_basic_concepts": ["electronics", "symbols", "circuit", "component", "resistor", "capacitor", "diode", "logic"],
    "microstrip_patch_antenna_5g": ["microstrip", "patch", "antenna", "substrate", "feed", "s11", "5g"],
    "types_of_telecom_antennas": ["antenna", "antennas", "sector", "dish", "mimo", "yagi", "horn", "telecom"],
    "beamwidth_narrow_wide": ["beamwidth", "beam", "narrow", "wide", "coverage", "hpbw", "lobe"],
    "telecom_towers_arabic_overview": ["tower", "towers", "telecom", "cellular", "site", "macro", "radome", "pole"],
    "cellular_satellite_site_photo": ["cellular", "satellite", "site", "satcom", "dish", "outdoor", "rru"],
    "rf_microwave_engineering_lab": ["rf", "microwave", "lab", "vna", "vsa", "spectrum", "smith", "sparameter", "dut"],
    "falco_xplorer_vs_bayraktar_tb2": ["uav", "drone", "isr", "falco", "bayraktar", "telemetry", "payload", "gcs"],
}

candidates = []
for base in search_roots:
    if not base.exists():
        continue
    try:
        iterator = base.rglob("*")
    except Exception:
        continue

    for p in iterator:
        if not p.is_file() or is_ignored(p):
            continue
        ext = p.suffix.lower()
        if ext not in image_ext | model_ext:
            continue

        # avoid fallback SVG and generated QA screenshots as replacement candidates
        low_path = str(p).lower()
        if "runtime_visual_qa" in low_path or "screenshots/trfmc_" in low_path:
            continue
        if "visual_knowledge" in low_path and ext == ".svg":
            continue

        try:
            size = p.stat().st_size
        except Exception:
            size = 0

        if size < 2048:
            continue

        name_tokens = tokenize(p.stem + " " + str(p.parent))
        scored = []
        for asset_id, kws in asset_keywords.items():
            score = sum(1 for kw in kws if kw.lower() in name_tokens or kw.lower() in low_path)
            if score:
                scored.append({"asset_id": asset_id, "score": score})
        scored.sort(key=lambda x: x["score"], reverse=True)

        candidates.append({
            "path": str(p),
            "relative": rel(p),
            "size_bytes": size,
            "ext": ext,
            "is_3d_model": ext in model_ext,
            "best_match_asset_id": scored[0]["asset_id"] if scored else "",
            "best_match_score": scored[0]["score"] if scored else 0,
            "scores": scored[:5],
        })

candidates.sort(key=lambda x: (-x["best_match_score"], -x["size_bytes"], x["relative"]))

matrix = []
for asset in registry_assets:
    asset_id = asset.get("id", "")
    matches = [c for c in candidates if c["best_match_asset_id"] == asset_id and c["best_match_score"] > 0]
    best = matches[0] if matches else None
    matrix.append({
        "asset_id": asset_id,
        "title": asset.get("title", ""),
        "fallback_path": asset.get("fallback_path", ""),
        "expected_real_render_path": asset.get("expected_real_render_path", ""),
        "candidate_found": bool(best),
        "candidate_path": best["relative"] if best else "",
        "candidate_abs_path": best["path"] if best else "",
        "candidate_score": best["best_match_score"] if best else 0,
        "candidate_size_bytes": best["size_bytes"] if best else 0,
        "candidate_ext": best["ext"] if best else "",
        "replacement_recommendation": "copy_candidate_to_expected_path" if best else "keep_fallback_until_real_render_available",
    })

candidate_count = len(candidates)
matched_count = sum(1 for item in matrix if item["candidate_found"])
missing_count = len(matrix) - matched_count

candidates_json = RDIR / "real_render_candidates_v43a.json"
matrix_json = RDIR / "real_render_replacement_matrix_v43a.json"
candidates_tsv = RDIR / "real_render_candidates_v43a.tsv"
matrix_tsv = RDIR / "real_render_replacement_matrix_v43a.tsv"

candidates_json.write_text(json.dumps(candidates, indent=2, ensure_ascii=False), encoding="utf-8")
matrix_json.write_text(json.dumps(matrix, indent=2, ensure_ascii=False), encoding="utf-8")

with candidates_tsv.open("w", encoding="utf-8") as f:
    f.write("best_match_asset_id\tscore\text\tsize_bytes\trelative_path\n")
    for c in candidates[:300]:
        f.write(f"{c['best_match_asset_id']}\t{c['best_match_score']}\t{c['ext']}\t{c['size_bytes']}\t{c['relative']}\n")

with matrix_tsv.open("w", encoding="utf-8") as f:
    f.write("asset_id\ttitle\tcandidate_found\tcandidate_score\tcandidate_ext\tcandidate_size_bytes\tcandidate_path\trecommendation\n")
    for m in matrix:
        f.write(
            f"{m['asset_id']}\t{m['title']}\t{m['candidate_found']}\t{m['candidate_score']}\t"
            f"{m['candidate_ext']}\t{m['candidate_size_bytes']}\t{m['candidate_path']}\t{m['replacement_recommendation']}\n"
        )

plan = RDIR / "real_render_import_plan_v43a.md"
with plan.open("w", encoding="utf-8") as f:
    f.write("# TRFMC V43A Real Render Import Audit\n\n")
    f.write("## Obiettivo\n\n")
    f.write("Individuare immagini/render/modelli reali già disponibili e mappabili sugli asset fallback V41.\n\n")
    f.write("## Risultato sintetico\n\n")
    f.write(f"- Candidate files found: `{candidate_count}`\n")
    f.write(f"- Registry assets: `{len(matrix)}`\n")
    f.write(f"- Matched assets: `{matched_count}`\n")
    f.write(f"- Missing real render assets: `{missing_count}`\n\n")
    f.write("## Strategia V43R1\n\n")
    if matched_count:
        f.write("1. Copiare solo i candidati con match score sufficiente nei path `expected_real_render_path`.\n")
        f.write("2. Aggiornare/creare `visual_asset_registry_v43.json` con `real_render_path` quando presente.\n")
        f.write("3. Lasciare fallback SVG per gli asset senza render reale.\n")
        f.write("4. Non rimuovere mai i fallback.\n")
        f.write("5. Eseguire build gate, HTTP gate e visual QA.\n\n")
    else:
        f.write("1. Nessun candidato affidabile trovato: mantenere fallback SVG.\n")
        f.write("2. Importare manualmente immagini/render reali in una cartella staging.\n")
        f.write("3. Rieseguire V43A oppure creare V43R1 manual mapping.\n\n")
    f.write("## Matrice asset\n\n")
    for m in matrix:
        f.write(
            f"- `{m['asset_id']}`: candidate `{m['candidate_found']}`, "
            f"score `{m['candidate_score']}`, path `{m['candidate_path'] or '-'}`\n"
        )

summary_data = {
    "timestamp": TS,
    "operation": "TRFMC_REAL_RENDER_IMPORT_AUDIT_V43A",
    "release_dir": str(RDIR),
    "freeze": str(FREEZE),
    "frontend_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "registry": str(REGISTRY_V41),
    "candidate_count": candidate_count,
    "registry_assets_count": len(matrix),
    "matched_count": matched_count,
    "missing_count": missing_count,
    "candidates_tsv": str(candidates_tsv),
    "matrix_tsv": str(matrix_tsv),
    "candidates_json": str(candidates_json),
    "matrix_json": str(matrix_json),
    "plan": str(plan),
    "result": "PASS",
}

summary = QDIR / "summary.json"
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_real_render_import_audit_v43a"
latest_r = ROOT / "runtime/releases/latest_real_render_import_audit_v43a"
if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()
latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print(json.dumps(summary_data, indent=2, ensure_ascii=False))
