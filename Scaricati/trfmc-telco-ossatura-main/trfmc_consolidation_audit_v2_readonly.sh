#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="${1:-$HOME/Scaricati/trfmc_full_telco_ossatura_v0_2}"
CUTOFF="${2:-2026-05-21 18:00:00}"
CUTOFF="$(printf '%s' "$CUTOFF" | sed 's/[~[:space:]]*$//')"

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/reports/TRFMC_CONSOLIDATION_AUDIT_V2_$TS"

mkdir -p "$OUT"

echo "============================================================"
echo "TRFMC / PORTALE TELCO - CONSOLIDATION AUDIT V2 READ-ONLY"
echo "Data: $(date)"
echo "Base: $BASE"
echo "Cutoff: $CUTOFF"
echo "Output: $OUT"
echo "============================================================"

python3 - "$BASE" "$OUT" "$CUTOFF" <<'PY'
import os, sys, re, json, hashlib, html
from pathlib import Path
from datetime import datetime

BASE = Path(sys.argv[1]).expanduser().resolve()
OUT = Path(sys.argv[2]).expanduser().resolve()
CUTOFF_STR = sys.argv[3].strip()
CUTOFF = datetime.strptime(CUTOFF_STR, "%Y-%m-%d %H:%M:%S")
HOME = Path.home()

OUT.mkdir(parents=True, exist_ok=True)

KNOWN_ROOTS = [
    BASE,
    BASE / "runtime" / "backups",
    HOME / "5g_lab_portal_spatial",
    HOME / "5G_PORTAL_RECOVERY_ARCHIVE",
    HOME / "Scaricati",
]

ROOT_MARKERS = [
    "frontend/package.json",
    "frontend/public",
    "frontend/src",
    "backend",
    "runtime",
    "start_portale_5173.sh",
    "status_portale_5173.sh",
    "trfmc_home_v87g.html",
    "rf_physics_sapienza_console",
    "webgl_rf_physics_engine",
    ".git",
]

FEATURE_GROUPS = {
    "HOME / MISSION CONTROL": [
        "trfmc_home", "mission", "command center", "dashboard", "noc", "mission control"
    ],
    "RF PHYSICS / WEBGL": [
        "rf_physics", "webgl_rf_physics", "maxwell", "electromagnetic", "quantum", "coherence", "fourier"
    ],
    "SIGNAL INTELLIGENCE / SDR": [
        "signal_intelligence", "signal analyzer", "fft", "waterfall", "iq", "sdr", "hackrf", "sigint"
    ],
    "RF MICROWAVE / SMITH": [
        "microwave", "smith", "vswr", "return loss", "impedance", "stub", "s11", "matching"
    ],
    "ANTENNA / RRU / RET": [
        "antenna", "rru", "ret", "panel", "mimo", "beam", "sector", "azimuth", "tilt"
    ],
    "FIBER / CPRI / FRONTHAUL": [
        "fiber", "optic", "cpri", "ecpri", "lc connector", "sc connector", "sfp", "fronthaul"
    ],
    "5G CORE / RAN / IDENTITY": [
        "open5gs", "ueransim", "amf", "smf", "upf", "ausf", "udm", "supi", "suci", "aka", "ngap", "pfcp", "gtp-u"
    ],
    "CYBER RF / RED BLUE / JAMMING": [
        "jamming", "spoofing", "red team", "blue team", "cyber rf", "evil twin", "pmkid", "uav", "mavlink"
    ],
    "DATA CENTER / POWER / INFRA": [
        "data center", "rack", "pdu", "ups", "power", "environmental", "storage", "switch"
    ],
    "MICROWAVE LINK / BACKHAUL": [
        "backhaul", "microwave link", "mw link", "e-band", "rsl", "ber", "fade margin", "alignment", "odu", "idu"
    ],
}

HTML_LINK_RE = re.compile(r'''(?:href|src)\s*=\s*["']([^"']+)["']''', re.I)
TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.I | re.S)

def safe_rel(path, root):
    try:
        return str(path.relative_to(root))
    except Exception:
        return str(path)

def sha256_file(p):
    h = hashlib.sha256()
    try:
        with p.open("rb") as f:
            for chunk in iter(lambda: f.read(1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return "ERROR"

def read_text_limited(p, limit=2_000_000):
    try:
        data = p.read_bytes()
        if len(data) > limit:
            data = data[:limit]
        return data.decode("utf-8", errors="replace")
    except Exception:
        return ""

def file_mtime_dt(p):
    try:
        return datetime.fromtimestamp(p.stat().st_mtime)
    except Exception:
        return datetime.fromtimestamp(0)

def discover_roots():
    candidates = set()

    if BASE.exists():
        candidates.add(BASE)

    backups = BASE / "runtime" / "backups"
    if backups.exists():
        for d in backups.iterdir():
            if d.is_dir():
                candidates.add(d)

    for r in [HOME / "5g_lab_portal_spatial", HOME / "5G_PORTAL_RECOVERY_ARCHIVE"]:
        if r.exists():
            candidates.add(r)

    # Cerca root addizionali solo entro limiti ragionevoli.
    for parent in [HOME, HOME / "Scaricati"]:
        if parent.exists():
            try:
                for p in parent.iterdir():
                    if p.is_dir() and any(k in p.name.lower() for k in ["trfmc", "5g", "portal", "telco"]):
                        candidates.add(p)
            except Exception:
                pass

    roots = []
    for root in sorted(candidates, key=lambda x: str(x)):
        score = 0
        why = []
        for m in ROOT_MARKERS:
            hits = list(root.glob(m)) if any(ch in m for ch in "*?[]") else []
            direct = root / m
            if direct.exists() or hits:
                score += 100 if m in ["frontend/public", "frontend/src", "backend"] else 50
                why.append(m)
        script_count = len(list(root.glob("*.sh"))) if root.exists() else 0
        if script_count:
            score += min(script_count, 100)
            why.append(f"{script_count}_root_scripts")
        latest = datetime.fromtimestamp(0)
        try:
            for p in root.rglob("*"):
                try:
                    if p.is_file():
                        mt = file_mtime_dt(p)
                        if mt > latest:
                            latest = mt
                except Exception:
                    continue
        except Exception:
            pass
        if score > 0:
            roots.append({
                "root": str(root),
                "score": score,
                "latest": latest,
                "why": ",".join(why)
            })
    roots.sort(key=lambda x: (x["score"], x["latest"]), reverse=True)
    return roots

def collect_html_pages(root):
    root = Path(root)
    pages = []
    patterns = [
        "frontend/public/**/*.html",
        "frontend/**/*.html",
        "*.html",
        "public/**/*.html",
    ]
    seen = set()
    for pat in patterns:
        try:
            for p in root.glob(pat):
                if not p.is_file():
                    continue
                rp = str(p.resolve())
                if rp in seen:
                    continue
                seen.add(rp)
                txt = read_text_limited(p)
                title = ""
                m = TITLE_RE.search(txt)
                if m:
                    title = re.sub(r"\s+", " ", m.group(1)).strip()
                links = []
                for lm in HTML_LINK_RE.finditer(txt):
                    val = lm.group(1).strip()
                    if val and not val.startswith(("http://", "https://", "mailto:", "tel:", "data:", "#")):
                        links.append(val.split("#")[0].split("?")[0])
                low = txt.lower()
                groups = []
                for g, toks in FEATURE_GROUPS.items():
                    if any(t.lower() in low or t.lower() in p.name.lower() for t in toks):
                        groups.append(g)
                pages.append({
                    "root": str(root),
                    "path": str(p),
                    "relpath": safe_rel(p, root),
                    "basename": p.name,
                    "size": p.stat().st_size,
                    "mtime": file_mtime_dt(p),
                    "hash": sha256_file(p),
                    "title": title,
                    "links": sorted(set([x for x in links if x])),
                    "groups": groups,
                    "post_cutoff": file_mtime_dt(p) > CUTOFF
                })
        except Exception:
            continue
    return pages

def write_tsv(path, rows, fields):
    with open(path, "w", encoding="utf-8") as f:
        f.write("\t".join(fields) + "\n")
        for r in rows:
            vals = []
            for k in fields:
                v = r.get(k, "")
                if isinstance(v, datetime):
                    v = v.strftime("%Y-%m-%d %H:%M:%S")
                elif isinstance(v, list):
                    v = "|".join(map(str, v))
                else:
                    v = str(v)
                vals.append(v.replace("\t", " ").replace("\n", " "))
            f.write("\t".join(vals) + "\n")

roots = discover_roots()
write_tsv(
    OUT / "01_roots_ranked.tsv",
    roots,
    ["score", "latest", "root", "why"]
)

all_pages = []
for r in roots:
    all_pages.extend(collect_html_pages(r["root"]))

write_tsv(
    OUT / "02_all_html_pages.tsv",
    all_pages,
    ["root", "relpath", "basename", "size", "mtime", "post_cutoff", "hash", "title", "groups"]
)

current_pages = [p for p in all_pages if Path(p["root"]).resolve() == BASE]
write_tsv(
    OUT / "03_current_html_pages.tsv",
    current_pages,
    ["relpath", "basename", "size", "mtime", "post_cutoff", "hash", "title", "groups"]
)

# Link graph corrente
current_by_name = {p["basename"]: p for p in current_pages}
referenced = set()
entry_names = [
    "index.html",
    "trfmc.html",
    "trfmc_home.html",
    "trfmc_home_v87g.html",
    "trfmc_master_structure_v1.json",
    "trfmc_registry.json",
    "trfmc_portal_registry.json",
]
for p in current_pages:
    if p["basename"] in entry_names or "home" in p["basename"].lower() or "master" in p["basename"].lower():
        for l in p["links"]:
            referenced.add(Path(l).name)

# Cerca anche riferimenti dentro JSON/JS/CSS della public corrente
for pat in ["frontend/public/**/*.json", "frontend/public/**/*.js", "frontend/public/**/*.css", "frontend/src/**/*.*"]:
    for fp in BASE.glob(pat):
        if not fp.is_file():
            continue
        txt = read_text_limited(fp)
        for name in current_by_name:
            if name in txt:
                referenced.add(name)

orphans = []
for p in current_pages:
    if p["basename"] not in referenced and p["basename"] not in entry_names:
        orphans.append({
            **p,
            "reason": "HTML presente in current root ma non referenziato direttamente da home/master/registry/src"
        })

write_tsv(
    OUT / "04_current_orphan_html_candidates.tsv",
    orphans,
    ["relpath", "basename", "mtime", "post_cutoff", "size", "hash", "title", "groups", "reason"]
)

# Candidati nei backup migliori mancanti dal current.
current_hashes = {p["hash"] for p in current_pages}
current_names = {p["basename"] for p in current_pages}

backup_candidates = []
for p in all_pages:
    if Path(p["root"]).resolve() == BASE:
        continue
    missing_name = p["basename"] not in current_names
    missing_hash = p["hash"] not in current_hashes
    if missing_name or missing_hash:
        score = 0
        if "final_unified_console_20260521_140553" in p["root"]:
            score += 100
        if "final_unified_console_20260521_140132" in p["root"]:
            score += 90
        if "v586" in p["root"]:
            score += 85
        if "v585" in p["root"]:
            score += 80
        if "v584" in p["root"]:
            score += 75
        if "v583" in p["root"]:
            score += 70
        if "v582" in p["root"]:
            score += 65
        if p["groups"]:
            score += 20
        if missing_name:
            score += 10
        backup_candidates.append({
            **p,
            "merge_score": score,
            "missing_name": missing_name,
            "missing_hash": missing_hash,
            "action": "REVIEW_PROMOTE" if score >= 80 else "CATALOG_ONLY"
        })

backup_candidates.sort(key=lambda x: (x["merge_score"], x["mtime"]), reverse=True)

write_tsv(
    OUT / "05_backup_pages_missing_or_different.tsv",
    backup_candidates,
    ["merge_score", "action", "root", "relpath", "basename", "mtime", "size", "missing_name", "missing_hash", "hash", "title", "groups"]
)

# Duplicati per hash e per nome
by_hash = {}
by_name = {}
for p in all_pages:
    by_hash.setdefault(p["hash"], []).append(p)
    by_name.setdefault(p["basename"], []).append(p)

dups_hash = []
for h, items in by_hash.items():
    if len(items) > 1 and h != "ERROR":
        dups_hash.append({
            "hash": h,
            "count": len(items),
            "basenames": "|".join(sorted(set(x["basename"] for x in items))),
            "locations": "|".join(sorted(set(x["root"] + "/" + x["relpath"] for x in items))[:20])
        })

dups_name = []
for name, items in by_name.items():
    hashes = sorted(set(x["hash"] for x in items))
    if len(items) > 1 and len(hashes) > 1:
        dups_name.append({
            "basename": name,
            "variants": len(hashes),
            "count": len(items),
            "groups": "|".join(sorted(set(g for x in items for g in x["groups"]))),
            "locations": "|".join(sorted(set(x["root"] + "/" + x["relpath"] for x in items))[:20])
        })

write_tsv(OUT / "06_duplicate_same_hash.tsv", dups_hash, ["hash", "count", "basenames", "locations"])
write_tsv(OUT / "07_duplicate_same_name_different_content.tsv", dups_name, ["basename", "variants", "count", "groups", "locations"])

# Matrice feature
feature_rows = []
for group in FEATURE_GROUPS:
    cur = [p for p in current_pages if group in p["groups"]]
    bkp = [p for p in backup_candidates if group in p["groups"]]
    feature_rows.append({
        "feature_group": group,
        "current_pages": len(cur),
        "current_orphans": len([p for p in orphans if group in p["groups"]]),
        "backup_missing_or_different": len(bkp),
        "top_current_examples": "|".join([p["basename"] for p in cur[:8]]),
        "top_backup_examples": "|".join([p["basename"] for p in bkp[:8]]),
    })

write_tsv(
    OUT / "08_feature_integration_matrix.tsv",
    feature_rows,
    ["feature_group", "current_pages", "current_orphans", "backup_missing_or_different", "top_current_examples", "top_backup_examples"]
)

# Post cutoff
post_cutoff = []
for root in [BASE]:
    for p in root.rglob("*"):
        try:
            if p.is_file() and file_mtime_dt(p) > CUTOFF:
                post_cutoff.append({
                    "mtime": file_mtime_dt(p),
                    "size": p.stat().st_size,
                    "relpath": safe_rel(p, root),
                    "hash": sha256_file(p),
                })
        except Exception:
            continue
post_cutoff.sort(key=lambda x: x["mtime"], reverse=True)
write_tsv(OUT / "09_post_cutoff_files_current_root.tsv", post_cutoff, ["mtime", "size", "relpath", "hash"])

# Executive decision
decision = []
decision.append("# TRFMC / PORTALE TELCO - DECISIONE TECNICA CONSOLIDAMENTO V2")
decision.append("")
decision.append(f"- Base corrente: `{BASE}`")
decision.append(f"- Cutoff: `{CUTOFF_STR}`")
decision.append(f"- Root analizzati: `{len(roots)}`")
decision.append(f"- HTML totali trovati: `{len(all_pages)}`")
decision.append(f"- HTML nel current root: `{len(current_pages)}`")
decision.append(f"- Candidati orfani nel current root: `{len(orphans)}`")
decision.append(f"- Pagine backup mancanti/differenti: `{len(backup_candidates)}`")
decision.append(f"- File post-cutoff nel current root: `{len(post_cutoff)}`")
decision.append("")
decision.append("## Verdetto")
decision.append("")
decision.append("Il portale non va ricostruito da zero e non va sovrascritto. Va consolidato con una strategia a registry unico.")
decision.append("")
decision.append("La directory corrente è il runtime vivo; i backup `final_unified_console_20260521_140553`, `final_unified_console_20260521_140132`, `v586`, `v585`, `v584`, `v583`, `v582` devono essere trattati come sorgenti di recupero selettivo.")
decision.append("")
decision.append("## Regola operativa")
decision.append("")
decision.append("1. Non cancellare pagine.")
decision.append("2. Non promuovere più moduli standalone senza registrarli nella mappa.")
decision.append("3. Ogni nuova pagina deve avere: entry nel registry, link nella shell, test HTTP, test contenuto, snapshot pre-modifica.")
decision.append("4. Le pagine orfane vanno catalogate prima e integrate poi.")
decision.append("5. Le pagine post-cutoff vanno marcate come nuove, non come base storica.")
decision.append("")
decision.append("## File da leggere subito")
decision.append("")
for f in [
    "01_roots_ranked.tsv",
    "04_current_orphan_html_candidates.tsv",
    "05_backup_pages_missing_or_different.tsv",
    "08_feature_integration_matrix.tsv",
    "09_post_cutoff_files_current_root.tsv",
]:
    decision.append(f"- `{f}`")
decision.append("")
decision.append("## Prossima azione corretta")
decision.append("")
decision.append("Creare un `trfmc_portal_registry_unified.json` generato da questa matrice e poi una pagina `trfmc_integration_control_room.html` che mostri tutti i moduli: integrati, orfani, backup-promotable, post-cutoff, legacy.")
decision.append("")
(OUT / "00_EXECUTIVE_DECISION.md").write_text("\n".join(decision), encoding="utf-8")

# Manifest machine-readable
manifest = {
    "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "base": str(BASE),
    "cutoff": CUTOFF_STR,
    "roots_count": len(roots),
    "html_total": len(all_pages),
    "current_html": len(current_pages),
    "current_orphan_candidates": len(orphans),
    "backup_missing_or_different": len(backup_candidates),
    "post_cutoff_current_files": len(post_cutoff),
    "output": str(OUT),
}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

print(json.dumps(manifest, indent=2, ensure_ascii=False))
PY

echo
echo "============================================================"
echo "AUDIT COMPLETATO"
echo "Output:"
echo "$OUT"
echo
echo "Leggi subito:"
echo "cat \"$OUT/00_EXECUTIVE_DECISION.md\""
echo "column -t -s \$'\\t' \"$OUT/01_roots_ranked.tsv\" | sed -n '1,80p'"
echo "column -t -s \$'\\t' \"$OUT/08_feature_integration_matrix.tsv\""
echo "column -t -s \$'\\t' \"$OUT/04_current_orphan_html_candidates.tsv\" | sed -n '1,120p'"
echo "column -t -s \$'\\t' \"$OUT/05_backup_pages_missing_or_different.tsv\" | sed -n '1,160p'"
echo "============================================================"
