#!/usr/bin/env bash
set -Eeuo pipefail
set +H

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$BASE/runtime/reports/TRFMC_VISUAL_STYLE_FORENSIC_AUDIT_$TS"

mkdir -p "$OUT"

echo "============================================================"
echo "TRFMC VISUAL / STYLE / SHELL FORENSIC AUDIT V1"
echo "READ-ONLY · nessuna modifica al portale"
echo "============================================================"
echo "Base: $BASE"
echo "Output: $OUT"
echo

python3 - "$BASE" "$OUT" <<'PY'
import os, re, sys, json, hashlib
from pathlib import Path
from datetime import datetime
from collections import Counter, defaultdict

BASE = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()

ROOTS = [
    BASE,
    BASE / "runtime/backups/final_unified_console_20260521_140553",
    BASE / "runtime/backups/final_unified_console_20260521_140132",
    BASE / "runtime/backups/v586_fullband_cursor_20260521_082942",
    BASE / "runtime/backups/v585_realtime_ui_20260521_082240",
    BASE / "runtime/backups/v584_uav_fhss_20260521_074500",
    BASE / "runtime/backups/v583_master_integration_20260521_072448",
    BASE / "runtime/backups/v582_restore_layout_20260520_182118",
    Path("/home/sentinel/5g_lab_portal_spatial"),
    Path("/home/sentinel/Scaricati/hackrf_lab_portal"),
]

CSS_PROP_RE = re.compile(r'([a-zA-Z-]+)\s*:\s*([^;{}]+);')
STYLE_BLOCK_RE = re.compile(r'<style[^>]*>(.*?)</style>', re.I | re.S)
LINK_CSS_RE = re.compile(r'<link[^>]+href=["\']([^"\']+\.css[^"\']*)["\']', re.I)
TITLE_RE = re.compile(r'<title[^>]*>(.*?)</title>', re.I | re.S)
CLASS_RE = re.compile(r'class=["\']([^"\']+)["\']', re.I)
ID_RE = re.compile(r'id=["\']([^"\']+)["\']', re.I)
COLOR_RE = re.compile(r'#[0-9a-fA-F]{3,8}|rgba?\([^)]+\)|hsla?\([^)]+\)')
CSS_VAR_RE = re.compile(r'--[a-zA-Z0-9_-]+\s*:\s*[^;{}]+;')
FONT_RE = re.compile(r'font-family\s*:\s*([^;{}]+)', re.I)

BAD_SHELL_TOKENS = [
    "<iframe",
    "window.open",
    "location.href",
]

NAV_TOKENS = [
    "<nav", "class=\"nav", "class='nav", "navbar", "topbar", "side-nav",
    "sidebar", "menu", "header", "command-bar", "toolbar"
]

PREMIUM_TOKENS = [
    "webgl", "three", "canvas", "hud", "cockpit", "mission", "command",
    "gpu", "renderer", "shader", "glow", "radial-gradient", "backdrop-filter",
    "transform: perspective", "box-shadow", "linear-gradient", "animation",
    "keyframes", "glass", "instrument", "telemetry", "spectrum", "waterfall"
]

DOMAIN_TOKENS = {
    "V6R3_BASELINE": ["v6r3", "safe_entrypoint", "command_center"],
    "RF_PRO_SDR": ["rfpro", "sdr", "hackrf", "fft", "waterfall", "iq"],
    "WEBGL_3D_RF": ["webgl", "3d_rf_asset", "renderer", "three"],
    "ANTENNA_RRU_RET": ["antenna", "rru", "ret", "aisg", "sector", "mimo"],
    "RF_MICROWAVE": ["microwave", "smith", "vswr", "s11", "metrology", "impedance"],
    "CORE_5G": ["open5gs", "ueransim", "core_network", "amf", "smf", "upf", "ngap", "pfcp"],
    "DATA_CENTER_POWER": ["data_center", "rack", "pdu", "ups", "power"],
    "LEGACY_SERVICE": ["reset", "emergency", "legacy", "service"],
}

def read_text(p, limit=4_000_000):
    try:
        b = p.read_bytes()
        if len(b) > limit:
            b = b[:limit]
        return b.decode("utf-8", "ignore")
    except Exception:
        return ""

def sha(s):
    return hashlib.sha256(s.encode("utf-8", "ignore")).hexdigest()

def clean(s):
    return re.sub(r'\s+', ' ', s or '').strip()

def extract_title(txt):
    m = TITLE_RE.search(txt)
    return clean(m.group(1)) if m else ""

def count_token(txt, token):
    return txt.lower().count(token.lower())

def extract_style(txt):
    blocks = STYLE_BLOCK_RE.findall(txt)
    return "\n".join(blocks)

def linked_css_paths(root, html_path, txt):
    links = []
    for href in LINK_CSS_RE.findall(txt):
        href_clean = href.split("?")[0].split("#")[0]
        if href_clean.startswith(("http://", "https://", "//")):
            links.append(("external", href_clean, None))
        else:
            candidate = None
            if href_clean.startswith("/"):
                candidate = root / "frontend/public" / href_clean.lstrip("/")
                if not candidate.exists():
                    candidate = root / href_clean.lstrip("/")
            else:
                candidate = html_path.parent / href_clean
            links.append(("local", href_clean, candidate if candidate and candidate.exists() else None))
    return links

def css_from_links(root, html_path, txt):
    css = []
    for kind, href, p in linked_css_paths(root, html_path, txt):
        if kind == "local" and p and p.exists():
            css.append(read_text(p, 1_000_000))
    return "\n".join(css)

def css_fingerprint(css):
    # Normalizza per confrontare famiglie stilistiche.
    css_norm = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    css_norm = re.sub(r'\s+', ' ', css_norm).strip()
    return hashlib.sha256(css_norm.encode("utf-8", "ignore")).hexdigest()

def detect_domain(name, title, txt):
    low = " ".join([name, title, txt[:20000]]).lower()
    hits = []
    for domain, toks in DOMAIN_TOKENS.items():
        if any(t in low for t in toks):
            hits.append(domain)
    return "|".join(hits) if hits else "UNCLASSIFIED"

def visual_family(name, title, txt, css):
    low = " ".join([name, title, txt[:50000], css[:50000]]).lower()
    if "v6r3" in low or "command center" in low:
        return "V6R3_COMMAND_CENTER_FAMILY"
    if "webgl" in low or "three" in low or "renderer" in low:
        return "WEBGL_3D_GPU_FAMILY"
    if "rf pro" in low or "sdr" in low or "waterfall" in low or "fft" in low:
        return "RF_PRO_SIGNAL_INTELLIGENCE_FAMILY"
    if "antenna" in low or "rru" in low or "ret" in low:
        return "ANTENNA_RRU_FIELD_ENGINEERING_FAMILY"
    if "metrology" in low or "smith" in low or "vswr" in low or "s11" in low:
        return "RF_MICROWAVE_METROLOGY_FAMILY"
    if "core network" in low or "open5gs" in low or "ueransim" in low:
        return "5G_CORE_LIVE_OPS_FAMILY"
    if "legacy" in low or "reset" in low or "emergency" in low:
        return "SERVICE_LEGACY_FAMILY"
    return "MISC_OR_UNSTABLE_FAMILY"

def risk_notes(txt, css):
    notes = []
    low = txt.lower()
    if "<iframe" in low:
        notes.append("IFRAME")
    if re.search(r'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs', txt, re.I):
        notes.append("EXTERNAL_REF")
    if sum(count_token(txt, t) for t in ["<nav", "navbar", "topbar", "sidebar", "toolbar"]) >= 4:
        notes.append("MULTIPLE_NAV_OR_TOOLBAR")
    if "position:fixed" in css.lower() and ("top:" in css.lower() or "bottom:" in css.lower()):
        notes.append("FIXED_LAYER")
    if css.lower().count("z-index") > 8:
        notes.append("MANY_Z_INDEX")
    if "body{" in css.replace(" ", "").lower() and css.lower().count("body") > 2:
        notes.append("MULTIPLE_BODY_STYLE")
    return "|".join(notes)

def score_visual(txt, css, name):
    low = (txt + "\n" + css).lower()
    score = 0

    # qualità grafica / premium
    for t in PREMIUM_TOKENS:
        if t in low:
            score += 4

    # GPU / 3D
    if "webgl" in low: score += 20
    if "canvas" in low: score += 10
    if "three" in low: score += 20
    if "shader" in low: score += 12
    if "requestanimationframe" in low: score += 10

    # design system
    if ":root" in css: score += 10
    if len(CSS_VAR_RE.findall(css)) >= 8: score += 12
    if "backdrop-filter" in low: score += 8
    if "radial-gradient" in low: score += 8
    if "box-shadow" in low: score += 6
    if "@keyframes" in low: score += 6

    # penalità confusione
    nav_count = sum(count_token(txt, t) for t in NAV_TOKENS)
    if nav_count > 10: score -= 15
    if "<iframe" in low: score -= 30
    if re.search(r'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs', txt, re.I): score -= 20
    if css.lower().count("position:fixed") > 4: score -= 10
    if css.lower().count("z-index") > 12: score -= 8

    # v6r3 e moduli importanti
    if "v6r3" in name.lower(): score += 25
    if "webgl_v2r2_reality" in name.lower(): score += 25
    if "rfpro_unified" in name.lower(): score += 20
    if "metrology" in name.lower(): score += 18
    if "signal_intelligence" in name.lower(): score += 18

    return score

def find_html(root):
    if not root.exists():
        return []
    paths = []
    patterns = [
        "frontend/public/*.html",
        "frontend/public/**/*.html",
        "frontend/*.html",
        "public/*.html",
        "*.html",
    ]
    seen = set()
    for pat in patterns:
        for p in root.glob(pat):
            if p.is_file():
                rp = str(p.resolve())
                if rp not in seen:
                    seen.add(rp)
                    paths.append(p)
    return paths

pages = []
css_families = defaultdict(list)
color_counter = Counter()
font_counter = Counter()
css_var_counter = Counter()

for root in ROOTS:
    if not root.exists():
        continue
    for p in find_html(root):
        txt = read_text(p)
        title = extract_title(txt)
        inline_css = extract_style(txt)
        linked_css = css_from_links(root, p, txt)
        css = inline_css + "\n" + linked_css

        classes = CLASS_RE.findall(txt)
        class_tokens = []
        for c in classes:
            class_tokens.extend(c.split())

        ids = ID_RE.findall(txt)
        colors = COLOR_RE.findall(css)
        fonts = FONT_RE.findall(css)
        css_vars = CSS_VAR_RE.findall(css)

        for c in colors:
            color_counter[c.strip()] += 1
        for f in fonts:
            font_counter[clean(f)] += 1
        for v in css_vars:
            css_var_counter[v.split(":")[0].strip()] += 1

        nav_count = sum(count_token(txt, t) for t in NAV_TOKENS)
        iframe_count = count_token(txt, "<iframe")
        canvas_count = count_token(txt, "<canvas")
        webgl_hint = bool(re.search(r'webgl|webgl2|three|WebGLRenderer|requestAnimationFrame', txt, re.I))
        external_refs = len(re.findall(r'https://|http://|cdn\.|unpkg|jsdelivr|cdnjs', txt, re.I))
        fixed_count = css.lower().count("position:fixed")
        sticky_count = css.lower().count("position:sticky")
        zindex_count = css.lower().count("z-index")
        style_hash = css_fingerprint(css)
        css_families[style_hash].append(str(p))

        try:
            rel = str(p.relative_to(root))
        except Exception:
            rel = str(p)

        rec = {
            "root": str(root),
            "relpath": rel,
            "name": p.name,
            "title": title,
            "size": p.stat().st_size,
            "mtime": datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M:%S"),
            "domain": detect_domain(p.name, title, txt),
            "visual_family": visual_family(p.name, title, txt, css),
            "visual_score": score_visual(txt, css, p.name),
            "nav_count": nav_count,
            "iframe_count": iframe_count,
            "canvas_count": canvas_count,
            "webgl_hint": webgl_hint,
            "external_refs": external_refs,
            "fixed_count": fixed_count,
            "sticky_count": sticky_count,
            "zindex_count": zindex_count,
            "css_bytes": len(css),
            "style_hash": style_hash,
            "class_count": len(class_tokens),
            "unique_class_count": len(set(class_tokens)),
            "id_count": len(ids),
            "color_count": len(colors),
            "font_count": len(fonts),
            "css_var_count": len(css_vars),
            "risk_notes": risk_notes(txt, css),
        }
        pages.append(rec)

pages_sorted = sorted(pages, key=lambda x: (x["visual_score"], -x["external_refs"], -x["iframe_count"]), reverse=True)

def write_tsv(path, rows, fields):
    with open(path, "w", encoding="utf-8") as f:
        f.write("\t".join(fields) + "\n")
        for r in rows:
            vals = []
            for k in fields:
                v = r.get(k, "")
                vals.append(str(v).replace("\t", " ").replace("\n", " "))
            f.write("\t".join(vals) + "\n")

fields = [
    "visual_score","root","relpath","name","title","mtime","size",
    "domain","visual_family","nav_count","iframe_count","canvas_count","webgl_hint",
    "external_refs","fixed_count","sticky_count","zindex_count","css_bytes",
    "class_count","unique_class_count","id_count","color_count","font_count",
    "css_var_count","style_hash","risk_notes"
]

write_tsv(OUT / "01_pages_visual_style_inventory.tsv", pages_sorted, fields)

# collisioni nav/header
collision_rows = [p for p in pages_sorted if p["nav_count"] >= 6 or p["fixed_count"] >= 3 or "MULTIPLE_NAV_OR_TOOLBAR" in p["risk_notes"]]
write_tsv(OUT / "02_navbar_header_collision_risk.tsv", collision_rows, fields)

# pagine pulite e premium
premium_rows = [
    p for p in pages_sorted
    if p["visual_score"] >= 40 and p["iframe_count"] == 0 and p["external_refs"] == 0
]
write_tsv(OUT / "03_premium_visual_candidates_no_iframe_no_cdn.tsv", premium_rows, fields)

# pagine rischiose
risky_rows = [
    p for p in pages_sorted
    if p["iframe_count"] > 0 or p["external_refs"] > 0 or p["nav_count"] >= 8 or p["fixed_count"] >= 4
]
write_tsv(OUT / "04_risky_pages_do_not_promote_directly.tsv", risky_rows, fields)

# famiglie CSS
family_rows = []
for h, items in css_families.items():
    family_rows.append({
        "style_hash": h,
        "count": len(items),
        "examples": "|".join(items[:20])
    })
family_rows.sort(key=lambda x: x["count"], reverse=True)
write_tsv(OUT / "05_style_families_by_css_hash.tsv", family_rows, ["style_hash","count","examples"])

# palette, fonts, variables
with open(OUT / "06_palette_colors_top.tsv", "w", encoding="utf-8") as f:
    f.write("color\tcount\n")
    for c,n in color_counter.most_common(300):
        f.write(f"{c}\t{n}\n")

with open(OUT / "07_fonts_top.tsv", "w", encoding="utf-8") as f:
    f.write("font_family\tcount\n")
    for c,n in font_counter.most_common(200):
        f.write(f"{c}\t{n}\n")

with open(OUT / "08_css_variables_top.tsv", "w", encoding="utf-8") as f:
    f.write("css_variable\tcount\n")
    for c,n in css_var_counter.most_common(300):
        f.write(f"{c}\t{n}\n")

# raggruppamento visual family
vf = defaultdict(list)
for p in pages_sorted:
    vf[p["visual_family"]].append(p)

vf_rows = []
for fam, arr in vf.items():
    vf_rows.append({
        "visual_family": fam,
        "count": len(arr),
        "top_score": arr[0]["visual_score"] if arr else 0,
        "top_examples": "|".join([x["name"] for x in arr[:12]])
    })
vf_rows.sort(key=lambda x: (x["top_score"], x["count"]), reverse=True)
write_tsv(OUT / "09_visual_families_summary.tsv", vf_rows, ["visual_family","count","top_score","top_examples"])

# confronto V6R3
v6r3 = [p for p in pages_sorted if "trfmc_official_safe_entrypoint_v6r3_command_center.html" in p["name"]]
write_tsv(OUT / "10_v6r3_baseline_style_records.tsv", v6r3, fields)

# decisione
decision = []
decision.append("# TRFMC Visual / Style Forensic Audit V1")
decision.append("")
decision.append(f"- Base: `{BASE}`")
decision.append(f"- Output: `{OUT}`")
decision.append(f"- HTML analizzati: `{len(pages)}`")
decision.append("")
decision.append("## Verdetto operativo")
decision.append("")
decision.append("Questo audit non modifica il portale. Serve a decidere quale stile deve diventare master e quali pagine non devono essere promosse direttamente.")
decision.append("")
decision.append("## Regole anti-frammentazione")
decision.append("")
decision.append("1. La V6R3 resta shell ufficiale.")
decision.append("2. Nessuna pagina con molte navbar/header/fixed layer va promossa direttamente.")
decision.append("3. Nessuna pagina con iframe va usata come shell nuova.")
decision.append("4. Le pagine GPU/WebGL migliori vanno trasformate in moduli leaf, non in portali paralleli.")
decision.append("5. Lo stile master va estratto da poche pagine premium, poi applicato tramite design tokens condivisi.")
decision.append("")
decision.append("## File principali da leggere")
decision.append("")
decision.append("- `01_pages_visual_style_inventory.tsv`")
decision.append("- `02_navbar_header_collision_risk.tsv`")
decision.append("- `03_premium_visual_candidates_no_iframe_no_cdn.tsv`")
decision.append("- `04_risky_pages_do_not_promote_directly.tsv`")
decision.append("- `05_style_families_by_css_hash.tsv`")
decision.append("- `09_visual_families_summary.tsv`")
decision.append("- `10_v6r3_baseline_style_records.tsv`")
decision.append("")
decision.append("## Prime pagine premium candidate")
decision.append("")
for p in premium_rows[:20]:
    decision.append(f"- score={p['visual_score']} `{p['name']}` family={p['visual_family']} risks={p['risk_notes'] or 'none'}")
decision.append("")
decision.append("## Pagine rischiose da non promuovere direttamente")
decision.append("")
for p in risky_rows[:20]:
    decision.append(f"- score={p['visual_score']} `{p['name']}` nav={p['nav_count']} iframe={p['iframe_count']} ext={p['external_refs']} fixed={p['fixed_count']} risks={p['risk_notes']}")
decision.append("")

(OUT / "00_VISUAL_STYLE_VERDICT.md").write_text("\n".join(decision), encoding="utf-8")

summary = {
    "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "base": str(BASE),
    "output": str(OUT),
    "html_analyzed": len(pages),
    "premium_candidates_no_iframe_no_cdn": len(premium_rows),
    "navbar_header_collision_risk": len(collision_rows),
    "risky_do_not_promote_directly": len(risky_rows),
    "style_families": len(css_families),
    "visual_families": len(vf_rows),
}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

print(json.dumps(summary, indent=2, ensure_ascii=False))
PY

echo
echo "============================================================"
echo "AUDIT VISUALE COMPLETATO"
echo "Output:"
echo "$OUT"
echo
echo "Leggi:"
echo "cat \"$OUT/00_VISUAL_STYLE_VERDICT.md\""
echo "column -t -s \$'\\t' \"$OUT/03_premium_visual_candidates_no_iframe_no_cdn.tsv\" | sed -n '1,80p'"
echo "column -t -s \$'\\t' \"$OUT/02_navbar_header_collision_risk.tsv\" | sed -n '1,80p'"
echo "column -t -s \$'\\t' \"$OUT/09_visual_families_summary.tsv\""
echo "============================================================"
