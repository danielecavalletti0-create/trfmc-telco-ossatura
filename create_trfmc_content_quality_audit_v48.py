from pathlib import Path
import json
import re
import subprocess
import time
import shutil

ROOT = Path.cwd()
TS = time.strftime("%Y%m%d_%H%M%S")
OP = "TRFMC_CONTENT_QUALITY_AUDIT_V48"

QDIR = ROOT / f"runtime/quality/{OP}_{TS}"
RDIR = ROOT / f"runtime/releases/{OP}_{TS}"
FREEZE = ROOT / f"runtime/freezes/{OP}_{TS}.tar.gz"

QDIR.mkdir(parents=True, exist_ok=True)
(RDIR / "dom").mkdir(parents=True, exist_ok=True)
(RDIR / "screenshots").mkdir(parents=True, exist_ok=True)
(ROOT / "runtime/freezes").mkdir(parents=True, exist_ok=True)

MAIN = ROOT / "frontend/src/app/main.tsx"
V42 = ROOT / "frontend/src/layout_orchestrator/MissionLayoutOrchestratorV42.tsx"
VISUAL = ROOT / "frontend/src/visual_assets/VisualAssetRuntimeV41.tsx"

print("=" * 60)
print(OP)
print("read-only section quality audit · placeholder/thin-content/live-binding classification")
print("=" * 60)

print("\n=== PREFLIGHT ===")

required_summaries = [
    "runtime/quality/latest_full_section_coverage_runtime_qa_v47/summary.json",
    "runtime/quality/latest_navigation_deeplink_runtime_qa_v46r1/summary.json",
    "runtime/quality/latest_visual_assets_runtime_qa_v45b1/summary.json",
]

for rel in required_summaries:
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERRORE: summary mancante: {rel}")
    d = json.loads(p.read_text())
    if d.get("result") != "PASS":
        raise SystemExit(f"ERRORE: {rel} non PASS: {d.get('result')}")

for p in [MAIN, V42, VISUAL]:
    if not p.exists():
        raise SystemExit(f"ERRORE: file mancante: {p}")

if "<MissionLayoutOrchestratorV42 />" not in MAIN.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: main.tsx non monta MissionLayoutOrchestratorV42")

if "data-trfmc-v46-deeplink-index" not in V42.read_text(encoding="utf-8"):
    raise SystemExit("ERRORE: V46 deeplink index non presente in V42")

print("OK: V47/V46R1/V45B1 PASS, root V42, navigation index presente")

sections = [
    {
        "id": "mission-overview",
        "url": "http://127.0.0.1:5173/#mission-overview",
        "expected_labels": ["Mission Overview", "Mission", "Runtime"],
        "technical_terms": ["mission", "backend", "runtime", "api", "status", "health", "bridge", "telemetry"],
    },
    {
        "id": "visual-assets",
        "url": "http://127.0.0.1:5173/#visual-assets",
        "expected_labels": ["Visual Assets", "Visual Knowledge", "Interactive Asset Viewer"],
        "technical_terms": ["visual", "asset", "render", "zoom", "fit", "rf_microwave", "registry", "fallback"],
    },
    {
        "id": "scenario-knowledge",
        "url": "http://127.0.0.1:5173/#scenario-knowledge",
        "expected_labels": ["Scenario Knowledge", "Knowledge"],
        "technical_terms": ["scenario", "knowledge", "binding", "rf", "telco", "core", "spectrum", "antenna"],
    },
    {
        "id": "navigation-architecture",
        "url": "http://127.0.0.1:5173/#navigation-architecture",
        "expected_labels": ["Navigation Architecture", "Navigation"],
        "technical_terms": ["navigation", "architecture", "domain", "mission", "signal", "core", "knowledge", "runtime"],
    },
    {
        "id": "command-center",
        "url": "http://127.0.0.1:5173/#command-center",
        "expected_labels": ["Command Center", "Mission Control"],
        "technical_terms": ["command", "mission", "backend", "open5gs", "ueransim", "spectrum", "soc", "noc"],
    },
    {
        "id": "dynamic-scenarios",
        "url": "http://127.0.0.1:5173/#dynamic-scenarios",
        "expected_labels": ["Dynamic Scenarios", "Scenarios"],
        "technical_terms": ["dynamic", "scenario", "rf", "telco", "uav", "antenna", "spectrum", "runtime"],
    },
    {
        "id": "full-engineering-stack",
        "url": "http://127.0.0.1:5173/#full-engineering-stack",
        "expected_labels": ["Full Engineering Stack", "Engineering"],
        "technical_terms": ["engineering", "stack", "visual", "scenario", "navigation", "command", "runtime", "core"],
    },
]

placeholder_patterns = [
    r"\blorem ipsum\b",
    r"\bplaceholder\b",
    r"\btodo\b",
    r"\btbd\b",
    r"\bcoming soon\b",
    r"\bunder construction\b",
    r"\bmock only\b",
    r"\bdummy\b",
    r"\bexample only\b",
    r"\bnot implemented\b",
]

thin_patterns = [
    r"\bloading\b",
    r"\bwaiting\b",
    r"\bno data\b",
    r"\bempty\b",
    r"\bunavailable\b",
]

live_binding_patterns = [
    r"/api/",
    r"TRFMC_READONLY_BACKEND_BRIDGE",
    r"contract_version",
    r"source_mode",
    r"real-render",
    r"readiness",
    r"open5gs",
    r"ueransim",
    r"bandplan",
    r"spectrum",
    r"mission/status",
    r"registry",
]

def strip_html(html: str) -> str:
    html = re.sub(r"<script[\s\S]*?</script>", " ", html, flags=re.I)
    html = re.sub(r"<style[\s\S]*?</style>", " ", html, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", html)
    text = text.replace("&nbsp;", " ").replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">")
    return re.sub(r"\s+", " ", text).strip()

def count_patterns(text: str, patterns) -> int:
    total = 0
    for pat in patterns:
        total += len(re.findall(pat, text, flags=re.I))
    return total

def term_hits(text: str, terms) -> list[str]:
    low = text.lower()
    return [t for t in terms if t.lower() in low]

print("\n=== HTTP GATE ===")

http_tsv = RDIR / "http.tsv"
http_lines = ["url\tstatus\tbytes"]

for item in sections + [{"id": "backend-health", "url": "http://127.0.0.1:4181/api/health"}]:
    pr = subprocess.run(
        ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}\t%{size_download}", "--connect-timeout", "2", "--max-time", "8", item["url"]],
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
    http_lines.append(f"{item['url']}\t{code}\t{size}")

http_tsv.write_text("\n".join(http_lines) + "\n", encoding="utf-8")
print(http_tsv.read_text())

http_non_200 = sum(1 for line in http_lines[1:] if line.split("\t")[1] != "200")
http_zero_bytes = sum(1 for line in http_lines[1:] if line.split("\t")[2] == "0")

print("\n=== DOM / SCREENSHOT CAPTURE ===")

chrome = None
for name in ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"]:
    found = shutil.which(name)
    if found:
        chrome = found
        break

metadata = {
    "chrome_found": bool(chrome),
    "chrome_path": chrome,
    "sections": [],
}

if not chrome:
    raise SystemExit("ERRORE: Chrome/Chromium non trovato per QA runtime")

base_cmd = [
    chrome,
    "--headless=new",
    "--disable-gpu",
    "--disable-dev-shm-usage",
    "--no-sandbox",
    "--window-size=1920,1800",
    "--virtual-time-budget=9000",
]

audit_rows = []

for item in sections:
    slug = item["id"]
    url = item["url"]
    dom_file = RDIR / "dom" / f"trfmc_v48_{slug}_dom.html"
    shot_file = RDIR / "screenshots" / f"trfmc_v48_{slug}_5173.png"

    capture = {
        "section": slug,
        "url": url,
        "dom_path": str(dom_file),
        "screenshot_path": str(shot_file),
        "dom_written": False,
        "screenshot_written": False,
        "errors": [],
    }

    try:
        proc = subprocess.run(
            base_cmd + ["--dump-dom", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=50,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            dom_file.write_text(proc.stdout, encoding="utf-8", errors="ignore")
            capture["dom_written"] = True
        else:
            capture["errors"].append("dump-dom failed: " + proc.stderr[-1600:])
    except Exception as exc:
        capture["errors"].append("dump-dom exception: " + str(exc))

    try:
        proc = subprocess.run(
            base_cmd + [f"--screenshot={shot_file}", url],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=55,
        )
        if proc.returncode == 0 and shot_file.exists() and shot_file.stat().st_size > 0:
            capture["screenshot_written"] = True
            capture["screenshot_size_bytes"] = shot_file.stat().st_size
            try:
                from PIL import Image
                img = Image.open(shot_file)
                capture["screenshot_width"] = img.width
                capture["screenshot_height"] = img.height
                capture["screenshot_png"] = img.format == "PNG"
            except Exception as exc:
                capture["errors"].append("PIL metadata exception: " + str(exc))
        else:
            capture["errors"].append("screenshot failed: " + proc.stderr[-1600:])
    except Exception as exc:
        capture["errors"].append("screenshot exception: " + str(exc))

    metadata["sections"].append(capture)

    html = dom_file.read_text(encoding="utf-8", errors="ignore") if dom_file.exists() else ""
    text = strip_html(html)

    label_hits = term_hits(text, item["expected_labels"])
    tech_hits = term_hits(text, item["technical_terms"])
    placeholder_count = count_patterns(text, placeholder_patterns)
    thin_count = count_patterns(text, thin_patterns)
    live_binding_count = count_patterns(html + " " + text, live_binding_patterns)

    text_chars = len(text)
    word_count = len(re.findall(r"\b[\w/.-]+\b", text))
    unique_words = len(set(w.lower() for w in re.findall(r"\b[a-zA-Z][\w.-]+\b", text)))
    duplicate_ratio = 0 if word_count == 0 else round(1 - (unique_words / word_count), 4)

    # Score leggibile ma severo.
    score = 100
    if not capture["dom_written"]:
        score -= 45
    if not capture["screenshot_written"]:
        score -= 20
    if not label_hits:
        score -= 15
    if len(tech_hits) < 3:
        score -= 20
    if text_chars < 1400:
        score -= 20
    if word_count < 180:
        score -= 15
    if placeholder_count > 0:
        score -= min(35, placeholder_count * 10)
    if thin_count > 6:
        score -= 10
    if live_binding_count == 0:
        score -= 12
    if duplicate_ratio > 0.78:
        score -= 8

    score = max(0, min(100, score))

    if placeholder_count > 0:
        classification = "placeholder"
    elif score < 55:
        classification = "thin"
    elif score < 75:
        classification = "needs_depth"
    else:
        classification = "solid"

    audit_rows.append({
        "section": slug,
        "url": url,
        "classification": classification,
        "quality_score": score,
        "text_chars": text_chars,
        "word_count": word_count,
        "unique_words": unique_words,
        "duplicate_ratio": duplicate_ratio,
        "label_hits": label_hits,
        "technical_hits": tech_hits,
        "technical_hit_count": len(tech_hits),
        "placeholder_count": placeholder_count,
        "thin_signal_count": thin_count,
        "live_binding_count": live_binding_count,
        "dom_written": capture["dom_written"],
        "screenshot_written": capture["screenshot_written"],
        "screenshot_size_bytes": capture.get("screenshot_size_bytes", 0),
        "errors": capture["errors"],
    })

metadata_path = RDIR / "content_quality_capture_metadata_v48.json"
metadata_path.write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")

audit_json = RDIR / "content_quality_audit_v48.json"
audit_tsv = RDIR / "content_quality_audit_v48.tsv"

audit_json.write_text(json.dumps(audit_rows, indent=2, ensure_ascii=False), encoding="utf-8")

with audit_tsv.open("w", encoding="utf-8") as f:
    f.write("section\tclassification\tquality_score\ttext_chars\tword_count\ttechnical_hit_count\tplaceholder_count\tthin_signal_count\tlive_binding_count\tduplicate_ratio\tscreenshot_size_bytes\n")
    for r in audit_rows:
        f.write(
            f"{r['section']}\t{r['classification']}\t{r['quality_score']}\t{r['text_chars']}\t{r['word_count']}\t"
            f"{r['technical_hit_count']}\t{r['placeholder_count']}\t{r['thin_signal_count']}\t{r['live_binding_count']}\t"
            f"{r['duplicate_ratio']}\t{r['screenshot_size_bytes']}\n"
        )

print("\n=== AUDIT MATRIX ===")
print(audit_tsv.read_text())

solid_count = sum(1 for r in audit_rows if r["classification"] == "solid")
needs_depth_count = sum(1 for r in audit_rows if r["classification"] == "needs_depth")
thin_count = sum(1 for r in audit_rows if r["classification"] == "thin")
placeholder_count_total = sum(1 for r in audit_rows if r["classification"] == "placeholder")
no_live_binding_count = sum(1 for r in audit_rows if r["live_binding_count"] == 0)
low_technical_count = sum(1 for r in audit_rows if r["technical_hit_count"] < 3)

content_checks = RDIR / "content_checks.txt"
checks = []

def ok(name, cond):
    checks.append(("OK" if cond else "MISS", name))

ok("seven sections audited", len(audit_rows) == 7)
ok("all DOM captures written", all(r["dom_written"] for r in audit_rows))
ok("all screenshots written", all(r["screenshot_written"] for r in audit_rows))
ok("no placeholder-classified sections", placeholder_count_total == 0)
ok("no thin-classified sections", thin_count == 0)
ok("all sections have >=3 technical hits", low_technical_count == 0)
ok("all sections have live-binding or registry/runtime signal", no_live_binding_count == 0)
ok("HTTP all 200", http_non_200 == 0)
ok("HTTP no zero bytes", http_zero_bytes == 0)

content_checks.write_text("\n".join(f"{s}: {n}" for s, n in checks) + "\n", encoding="utf-8")
print("\n=== CONTENT CHECKS ===")
print(content_checks.read_text())

miss_count = sum(1 for s, _ in checks if s == "MISS")
warn_count = needs_depth_count

recommendations_md = RDIR / "content_quality_recommendations_v48.md"

priority = sorted(
    audit_rows,
    key=lambda r: (
        0 if r["classification"] in ("placeholder", "thin") else 1 if r["classification"] == "needs_depth" else 2,
        r["quality_score"]
    )
)

lines = [
    "# TRFMC V48 Content Quality Recommendations",
    "",
    "## Executive summary",
    "",
    f"- Sections audited: {len(audit_rows)}",
    f"- Solid: {solid_count}",
    f"- Needs depth: {needs_depth_count}",
    f"- Thin: {thin_count}",
    f"- Placeholder: {placeholder_count_total}",
    f"- Sections without live/registry/runtime signal: {no_live_binding_count}",
    "",
    "## Priority order",
    "",
]

for r in priority:
    lines.append(f"### {r['section']} — {r['classification']} — score {r['quality_score']}")
    lines.append("")
    lines.append(f"- Text chars: {r['text_chars']}")
    lines.append(f"- Words: {r['word_count']}")
    lines.append(f"- Technical hits: {', '.join(r['technical_hits']) if r['technical_hits'] else 'none'}")
    lines.append(f"- Placeholder count: {r['placeholder_count']}")
    lines.append(f"- Thin signals: {r['thin_signal_count']}")
    lines.append(f"- Live/runtime signal count: {r['live_binding_count']}")
    lines.append("")
    if r["classification"] == "solid":
        lines.append("Action: preserve; only polish copy and normalize visual hierarchy.")
    elif r["classification"] == "needs_depth":
        lines.append("Action: add deeper engineering explanation, link to live contract/API state, add scenario-specific KPIs and operational meaning.")
    elif r["classification"] == "thin":
        lines.append("Action: expand section with concrete cards, live binding, technical summary, and operator workflow.")
    else:
        lines.append("Action: replace placeholder with real technical content before further UI polish.")
    lines.append("")

recommendations_md.write_text("\n".join(lines), encoding="utf-8")

result = "PASS"
if miss_count != 0:
    result = "FAIL"
elif warn_count != 0:
    result = "WARN"

manifest = RDIR / "content_quality_audit_manifest_v48.json"
summary = QDIR / "summary.json"

summary_data = {
    "timestamp": TS,
    "operation": OP,
    "frontend_mutation": False,
    "backend_mutation": False,
    "nginx_mutation": False,
    "systemd_mutation": False,
    "release_dir": str(RDIR),
    "manifest": str(manifest),
    "freeze": str(FREEZE),
    "content_checks": str(content_checks),
    "http_tsv": str(http_tsv),
    "audit_json": str(audit_json),
    "audit_tsv": str(audit_tsv),
    "capture_metadata": str(metadata_path),
    "recommendations": str(recommendations_md),
    "sections_audited": len(audit_rows),
    "solid_count": solid_count,
    "needs_depth_count": needs_depth_count,
    "thin_count": thin_count,
    "placeholder_count": placeholder_count_total,
    "no_live_binding_count": no_live_binding_count,
    "low_technical_count": low_technical_count,
    "miss_count": miss_count,
    "warn_count": warn_count,
    "http_non_200": http_non_200,
    "http_zero_bytes": http_zero_bytes,
    "result": result,
}

manifest.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")
summary.write_text(json.dumps(summary_data, indent=2, ensure_ascii=False), encoding="utf-8")

subprocess.run([
    "tar", "-czf", str(FREEZE),
    str(RDIR),
    str(summary),
], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

latest_q = ROOT / "runtime/quality/latest_content_quality_audit_v48"
latest_r = ROOT / "runtime/releases/latest_content_quality_audit_v48"

if latest_q.exists() or latest_q.is_symlink():
    latest_q.unlink()
if latest_r.exists() or latest_r.is_symlink():
    latest_r.unlink()

latest_q.symlink_to(QDIR)
latest_r.symlink_to(RDIR)

print("\n=== SUMMARY ===")
print(json.dumps(summary_data, indent=2, ensure_ascii=False))

if result == "FAIL":
    raise SystemExit(1)
