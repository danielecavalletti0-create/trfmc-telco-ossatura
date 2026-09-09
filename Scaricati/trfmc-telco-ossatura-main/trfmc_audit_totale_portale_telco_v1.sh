#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/reports/TRFMC_AUDIT_TOTALE_PORTALE_TELCO_$TS"
CUTOFF="${1:-2026-05-21 18:00:00}"
CUTOFF="$(printf '%s' "$CUTOFF" | sed 's/[~[:space:]]*$//')"

mkdir -p "$OUT"

echo "============================================================"
echo "TRFMC / PORTALE TELCO - AUDIT TOTALE READ-ONLY"
echo "Data: $(date)"
echo "Base: $BASE"
echo "Cutoff riferimento: $CUTOFF"
echo "Output: $OUT"
echo "============================================================"

{
  echo "date=$(date)"
  echo "host=$(hostname)"
  echo "user=$(whoami)"
  echo "pwd=$(pwd)"
  echo "cutoff=$CUTOFF"
  echo "base=$BASE"
} > "$OUT/00_env.txt"

echo
echo "1) Stato processi/porte"
{
  echo "=== ss 5173/8000/8090/8080/5174 ==="
  ss -ltnp | grep -E ':5173|:8000|:8090|:8080|:5174' || true
  echo
  echo "=== curl health 5173 ==="
  curl -sS http://127.0.0.1:5173/api/health || true
  echo
  echo "=== curl frontend ==="
  curl -I http://127.0.0.1:5173 2>/dev/null | head || true
} > "$OUT/01_runtime_state.txt"

echo
echo "2) Git status/log"
{
  cd "$BASE"
  echo "=== git status ==="
  git status --short || true
  echo
  echo "=== git branch ==="
  git branch -vv || true
  echo
  echo "=== git log last 30 ==="
  git log --oneline --decorate -n 30 || true
} > "$OUT/02_git_state.txt"

echo
echo "3) Analisi filesystem completa con Python"

python3 - "$BASE" "$OUT" "$CUTOFF" <<'PY'
import os, sys, json, hashlib, re, subprocess
from pathlib import Path
from datetime import datetime

base = Path(sys.argv[1]).expanduser().resolve()
out = Path(sys.argv[2]).expanduser().resolve()
cutoff_s = sys.argv[3]
cutoff = datetime.strptime(cutoff_s, "%Y-%m-%d %H:%M:%S").timestamp()
home = Path.home()

EXCLUDE_DIRS = {
    "node_modules", ".git", ".venv", "venv", "__pycache__", ".cache",
    "dist", "build", ".npm", ".local", ".config", ".mozilla", ".vscode",
    "Downloads", "Immagini", "Video", "Musica"
}
ROOT_PATTERNS = [
    "trfmc", "telco", "portale", "portal", "5g_lab", "5g-portal",
    "5g_portal", "open5gs", "rf", "spatial"
]
TOKENS = [
    "trfmc_home_v87g",
    "trfmc_home.html",
    "trfmc.html",
    "v6r1",
    "v6r2",
    "v6r3",
    "v6r4",
    "webgl_rf_physics_engine",
    "rf_physics_sapienza_console",
    "rf_microwave_engineering",
    "Smith Chart",
    "signal_intelligence",
    "realtime_fft",
    "rf_metrology",
    "3d_rf_asset",
    "core_live",
    "Open5GS",
    "UERANSIM",
    "HackRF",
    "SDR",
    "VSA",
    "waterfall",
    "mission_control",
    "single-port-portal"
]
KEY_EXT = {
    ".html", ".htm", ".js", ".jsx", ".ts", ".tsx", ".css",
    ".py", ".sh", ".json", ".md", ".yaml", ".yml", ".txt"
}

def safe_text(p, limit=250000):
    try:
        b = p.read_bytes()[:limit]
        return b.decode("utf-8", "ignore")
    except Exception:
        return ""

def sha256_file(p):
    try:
        h = hashlib.sha256()
        with p.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return ""

def title_h1(text):
    title = ""
    h1 = ""
    m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    if m:
        title = re.sub(r"\s+", " ", m.group(1)).strip()
    m = re.search(r"<h1[^>]*>(.*?)</h1>", text, re.I | re.S)
    if m:
        h1 = re.sub(r"<[^>]+>", " ", m.group(1))
        h1 = re.sub(r"\s+", " ", h1).strip()
    return title, h1

def is_candidate_dir(p):
    name = p.name.lower()
    if any(x in name for x in ROOT_PATTERNS):
        return True
    try:
        names = {x.name for x in p.iterdir()}
        if "frontend" in names and ("backend" in names or "runtime" in names):
            return True
        if "package.json" in names and ("src" in names or "public" in names):
            return True
    except Exception:
        pass
    return False

def score_root(p):
    score = 0
    checks = []
    def add(cond, points, label):
        nonlocal score
        if cond:
            score += points
            checks.append(label)
    add((p/"frontend/package.json").exists(), 160, "frontend/package.json")
    add((p/"frontend/public").exists(), 120, "frontend/public")
    add((p/"frontend/src").exists(), 90, "frontend/src")
    add((p/"backend").exists(), 80, "backend")
    add((p/"runtime").exists(), 70, "runtime")
    add((p/"start_portale_5173.sh").exists(), 90, "start_portale_5173.sh")
    add((p/"status_portale_5173.sh").exists(), 70, "status_portale_5173.sh")
    add((p/"frontend/public/trfmc_home_v87g.html").exists(), 120, "trfmc_home_v87g.html")
    add((p/"frontend/public/rf_physics_sapienza_console_v86a.html").exists(), 80, "rf_physics_sapienza_console")
    add((p/"frontend/public/webgl_rf_physics_engine_v85e_viewport_discipline.html").exists(), 80, "webgl_rf_physics_engine")
    add((p/".git").exists(), 40, ".git")
    try:
        sh_count = len(list(p.glob("*.sh")))
        score += min(sh_count, 50)
        if sh_count:
            checks.append(f"{sh_count}_root_scripts")
    except Exception:
        pass
    return score, ",".join(checks)

roots = set()
seed_dirs = [
    base,
    home / "Scaricati",
    home / "5g_lab_portal_spatial",
    home / "Portale_Telco",
    home / "Portale_telco",
    home / "portale_telco",
    home / "lab",
]
for s in seed_dirs:
    if s.exists():
        roots.add(s.resolve())

for start in [home, home / "Scaricati"]:
    if not start.exists():
        continue
    for dirpath, dirnames, filenames in os.walk(start):
        p = Path(dirpath)
        rel_depth = len(p.relative_to(start).parts)
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS and not d.startswith(".")]
        if rel_depth > 5:
            dirnames[:] = []
            continue
        if is_candidate_dir(p):
            roots.add(p.resolve())

ranked = []
for r in sorted(roots):
    sc, why = score_root(r)
    if sc > 0 or r == base:
        try:
            latest = max((x.stat().st_mtime for x in r.rglob("*") if x.is_file() and "node_modules" not in x.parts and ".git" not in x.parts), default=0)
        except Exception:
            latest = 0
        ranked.append((sc, latest, str(r), why))

ranked.sort(key=lambda x: (x[0], x[1]), reverse=True)

with (out/"03_roots_ranked.tsv").open("w", encoding="utf-8") as f:
    f.write("score\tlatest_mtime\troot\twhy\n")
    for sc, latest, r, why in ranked:
        lm = datetime.fromtimestamp(latest).strftime("%Y-%m-%d %H:%M:%S") if latest else ""
        f.write(f"{sc}\t{lm}\t{r}\t{why}\n")

scan_roots = [Path(r[2]) for r in ranked[:20]]
if base not in scan_roots:
    scan_roots.insert(0, base)

html_rows = []
src_rows = []
cut_rows = []
token_rows = []
dupe = {}

for root in scan_roots:
    for dirpath, dirnames, filenames in os.walk(root):
        pdir = Path(dirpath)
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS and d != "freezes"]
        for fn in filenames:
            p = pdir / fn
            try:
                st = p.stat()
            except Exception:
                continue
            ext = p.suffix.lower()
            rel = str(p.relative_to(root)) if p.is_relative_to(root) else str(p)
            mtime = datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            status = "POST_CUTOFF" if st.st_mtime > cutoff else "PRE_OR_AT_CUTOFF"
            if ext in KEY_EXT:
                src_rows.append((str(root), rel, ext, st.st_size, mtime, status))
                if status == "POST_CUTOFF":
                    cut_rows.append((status, mtime, st.st_size, str(root), rel))
                text = safe_text(p, 180000)
                for tok in TOKENS:
                    if tok.lower() in text.lower():
                        token_rows.append((tok, str(root), rel, mtime))
            if ext in {".html", ".htm"}:
                text = safe_text(p, 250000)
                title, h1 = title_h1(text)
                sh = sha256_file(p)
                html_rows.append((str(root), rel, st.st_size, mtime, status, sh, title, h1))
                dupe.setdefault(sh, []).append((str(root), rel, st.st_size, mtime))

with (out/"04_html_pages.tsv").open("w", encoding="utf-8") as f:
    f.write("root\trelpath\tsize\tmtime\tcutoff_status\tsha256\ttitle\th1\n")
    for row in sorted(html_rows, key=lambda x: x[3], reverse=True):
        f.write("\t".join(map(lambda v: str(v).replace("\t"," "), row)) + "\n")

with (out/"05_source_files.tsv").open("w", encoding="utf-8") as f:
    f.write("root\trelpath\text\tsize\tmtime\tcutoff_status\n")
    for row in sorted(src_rows, key=lambda x: x[4], reverse=True):
        f.write("\t".join(map(lambda v: str(v).replace("\t"," "), row)) + "\n")

with (out/"06_post_cutoff_changed_files.tsv").open("w", encoding="utf-8") as f:
    f.write("status\tmtime\tsize\troot\trelpath\n")
    for row in sorted(cut_rows, key=lambda x: x[1], reverse=True):
        f.write("\t".join(map(lambda v: str(v).replace("\t"," "), row)) + "\n")

with (out/"07_token_hits.tsv").open("w", encoding="utf-8") as f:
    f.write("token\troot\trelpath\tmtime\n")
    for row in sorted(token_rows, key=lambda x: (x[0], x[3], x[2])):
        f.write("\t".join(map(lambda v: str(v).replace("\t"," "), row)) + "\n")

with (out/"08_duplicate_html_groups.tsv").open("w", encoding="utf-8") as f:
    f.write("sha256\tcount\tsize\tmtime\troot\trelpath\n")
    for sh, items in sorted(dupe.items(), key=lambda kv: len(kv[1]), reverse=True):
        if sh and len(items) > 1:
            for root, rel, size, mtime in items:
                f.write(f"{sh}\t{len(items)}\t{size}\t{mtime}\t{root}\t{rel}\n")

# public current root detail
cur_public = base / "frontend" / "public"
with (out/"09_current_public_tree.txt").open("w", encoding="utf-8") as f:
    if cur_public.exists():
        for p in sorted(cur_public.rglob("*")):
            if p.is_file():
                try:
                    st = p.stat()
                    f.write(f"{datetime.fromtimestamp(st.st_mtime).strftime('%Y-%m-%d %H:%M:%S')}\t{st.st_size}\t{p.relative_to(cur_public)}\n")
                except Exception:
                    pass

# package and vite detail
with (out/"10_frontend_config_extract.txt").open("w", encoding="utf-8") as f:
    for p in [
        base/"frontend/package.json",
        base/"frontend/vite.config.js",
        base/"frontend/vite.config.ts",
        base/"frontend/src/App.jsx",
        base/"frontend/src/App.tsx",
        base/"frontend/src/main.jsx",
        base/"frontend/src/main.tsx",
    ]:
        if p.exists():
            f.write(f"\n===== {p} =====\n")
            txt = safe_text(p, 50000)
            f.write(txt[:50000])

summary = []
summary.append("TRFMC / PORTALE TELCO AUDIT TOTALE")
summary.append(f"created_at={datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
summary.append(f"base={base}")
summary.append(f"cutoff={cutoff_s}")
summary.append("")
summary.append("TOP ROOTS:")
for sc, latest, r, why in ranked[:10]:
    lm = datetime.fromtimestamp(latest).strftime("%Y-%m-%d %H:%M:%S") if latest else ""
    summary.append(f"- score={sc} latest={lm} root={r} why={why}")
summary.append("")
summary.append(f"html_pages={len(html_rows)}")
summary.append(f"source_files={len(src_rows)}")
summary.append(f"post_cutoff_files={len(cut_rows)}")
summary.append(f"token_hits={len(token_rows)}")
summary.append("")
summary.append("READ THESE FILES FIRST:")
summary.append("03_roots_ranked.tsv")
summary.append("04_html_pages.tsv")
summary.append("06_post_cutoff_changed_files.tsv")
summary.append("07_token_hits.tsv")
summary.append("10_frontend_config_extract.txt")

(out/"AUDIT_SUMMARY.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
print("\n".join(summary))
PY

echo
echo "4) Creo pacchetto report"
tar -czf "$BASE/runtime/reports/TRFMC_AUDIT_TOTALE_PORTALE_TELCO_$TS.tar.gz" -C "$BASE/runtime/reports" "TRFMC_AUDIT_TOTALE_PORTALE_TELCO_$TS"

echo
echo "============================================================"
echo "AUDIT COMPLETATO"
echo "Cartella:"
echo "$OUT"
echo
echo "Pacchetto:"
echo "$BASE/runtime/reports/TRFMC_AUDIT_TOTALE_PORTALE_TELCO_$TS.tar.gz"
echo
echo "Anteprima:"
echo "cat '$OUT/AUDIT_SUMMARY.txt'"
echo "column -t -s \$'\t' '$OUT/03_roots_ranked.tsv' | sed -n '1,40p'"
echo "column -t -s \$'\t' '$OUT/06_post_cutoff_changed_files.tsv' | sed -n '1,80p'"
echo "============================================================"
