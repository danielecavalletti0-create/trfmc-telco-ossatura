#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_CHUNK_OBSERVATORY_V16_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_CHUNK_OBSERVATORY_V16_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF CHUNK OBSERVATORY V16"
echo "Lazy module runtime monitor · PerformanceResourceTiming"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/telemetry src/rf_instruments/instruments

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFOperationalDeckV15Lazy.tsx || {
  echo "ERRORE: RFOperationalDeckV15Lazy.tsx mancante. Prima completare V15."
  exit 1
}

grep -q "RFOperationalDeckV15Lazy" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta RFOperationalDeckV15Lazy. Non procedo."
  exit 1
}

echo "OK: V15 Lazy presente e montato"

echo
echo "=== BACKUP STATO V15 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_chunk_observatory_v16_${TS}"
cp src/styles.css "src/styles.css.bak_rf_chunk_observatory_v16_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== APPENDO CSS V16 ==="

if ! grep -q "TRFMC_RF_CHUNK_OBSERVATORY_V16_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_CHUNK_OBSERVATORY_V16_STYLE */
.rf-chunk-v16{
  margin-bottom:12px;
  border:1px solid rgba(125,255,178,.34);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 84% 0%,rgba(125,255,178,.14),transparent 34%),
    radial-gradient(circle at 12% 100%,rgba(57,215,255,.08),transparent 30%),
    linear-gradient(145deg,rgba(4,28,24,.96),rgba(0,4,9,.99));
  box-shadow:
    0 28px 100px rgba(0,0,0,.66),
    inset 0 0 48px rgba(125,255,178,.035);
}

.rf-chunk-v16-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:14px;
  padding:14px;
  border-bottom:1px solid rgba(125,255,178,.22);
  background:linear-gradient(180deg,rgba(8,38,32,.96),rgba(2,9,16,.98));
}

.rf-chunk-v16-title{
  color:#efffff;
  font-size:17px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.12em;
  text-shadow:0 0 18px rgba(125,255,178,.45);
}

.rf-chunk-v16-sub{
  margin-top:5px;
  color:#9bc7bd;
  font-size:11px;
}

.rf-chunk-v16-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-chunk-v16-badges span{
  border:1px solid rgba(125,255,178,.28);
  background:rgba(125,255,178,.07);
  color:#7dffb2;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-chunk-v16-actions{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  padding:10px;
  border-bottom:1px solid rgba(125,255,178,.14);
}

.rf-chunk-v16-grid{
  padding:10px;
  display:grid;
  grid-template-columns:repeat(6,minmax(145px,1fr));
  gap:10px;
}

.rf-chunk-v16-card{
  border:1px solid rgba(125,255,178,.22);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(8,28,25,.90),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(125,255,178,.08),transparent 35%);
}

.rf-chunk-v16-card b{
  display:block;
  color:#7dffb2;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-chunk-v16-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:15px;
  font-weight:850;
}

.rf-chunk-v16-card small{
  display:block;
  color:#9bc7bd;
  margin-top:6px;
  line-height:1.45;
  word-break:break-all;
}

.rf-chunk-v16-table-wrap{
  padding:0 10px 10px;
  max-height:300px;
  overflow:auto;
}

.rf-chunk-v16-table{
  width:100%;
  border-collapse:collapse;
  font-family:ui-monospace,Consolas,monospace;
  font-size:12px;
}

.rf-chunk-v16-table th,
.rf-chunk-v16-table td{
  border-bottom:1px solid rgba(125,255,178,.14);
  padding:8px 9px;
  text-align:left;
  vertical-align:top;
}

.rf-chunk-v16-table th{
  color:#7dffb2;
  background:rgba(125,255,178,.055);
  text-transform:uppercase;
  letter-spacing:.08em;
  font-size:10px;
  position:sticky;
  top:0;
  z-index:2;
}

.rf-chunk-v16-table td small{
  color:#9bc7bd;
  word-break:break-all;
}

.rf-chunk-ok{ color:#7dffb2; }
.rf-chunk-warn{ color:#ffd166; }
.rf-chunk-bad{ color:#ff5f7a; }

@media(max-width:1500px){
  .rf-chunk-v16-grid{ grid-template-columns:repeat(3,minmax(145px,1fr)); }
  .rf-chunk-v16-header{ grid-template-columns:1fr; }
  .rf-chunk-v16-badges{ justify-content:flex-start; }
}

@media(max-width:760px){
  .rf-chunk-v16-grid{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO RFChunkObservatoryV16.tsx ==="

cat > src/rf_instruments/telemetry/RFChunkObservatoryV16.tsx <<'TSX'
import React, { useEffect, useMemo, useState } from "react";

type ChunkEntry = {
  name: string;
  shortName: string;
  initiatorType: string;
  duration: number;
  transferSize: number;
  encodedBodySize: number;
  decodedBodySize: number;
  startTime: number;
};

function isRelevantResource(entry: PerformanceResourceTiming) {
  const name = entry.name;

  return (
    name.includes("/src/") ||
    name.includes("/assets/") ||
    name.includes("node_modules") ||
    name.endsWith(".js") ||
    name.endsWith(".tsx") ||
    name.endsWith(".ts") ||
    name.includes("?t=")
  );
}

function shortName(name: string) {
  try {
    const url = new URL(name);
    return url.pathname.split("/").slice(-4).join("/") + url.search;
  } catch {
    return name.split("/").slice(-4).join("/");
  }
}

function collectEntries(): ChunkEntry[] {
  return performance
    .getEntriesByType("resource")
    .filter((entry): entry is PerformanceResourceTiming => entry.entryType === "resource")
    .filter(isRelevantResource)
    .map((entry) => ({
      name: entry.name,
      shortName: shortName(entry.name),
      initiatorType: entry.initiatorType || "unknown",
      duration: Math.round(entry.duration * 10) / 10,
      transferSize: entry.transferSize || 0,
      encodedBodySize: entry.encodedBodySize || 0,
      decodedBodySize: entry.decodedBodySize || 0,
      startTime: Math.round(entry.startTime * 10) / 10
    }))
    .sort((a, b) => b.startTime - a.startTime);
}

function formatBytes(bytes: number) {
  if (!bytes) return "0 / cached / unknown";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 102.4) / 10} KB`;
  return `${Math.round(bytes / 1024 / 102.4) / 10} MB`;
}

export function RFChunkObservatoryV16() {
  const [entries, setEntries] = useState<ChunkEntry[]>(() => collectEntries());
  const [observerState, setObserverState] = useState("BOOT");
  const [lastRefresh, setLastRefresh] = useState("—");

  useEffect(() => {
    let observer: PerformanceObserver | null = null;

    try {
      observer = new PerformanceObserver(() => {
        setEntries(collectEntries());
        setLastRefresh(new Date().toLocaleTimeString());
      });

      observer.observe({ type: "resource", buffered: true });
      setObserverState("ONLINE");
    } catch {
      setObserverState("FALLBACK");
    }

    const timer = window.setInterval(() => {
      setEntries(collectEntries());
      setLastRefresh(new Date().toLocaleTimeString());
    }, 1500);

    return () => {
      observer?.disconnect();
      window.clearInterval(timer);
    };
  }, []);

  const summary = useMemo(() => {
    const total = entries.length;
    const scripts = entries.filter((entry) =>
      entry.initiatorType === "script" ||
      entry.shortName.endsWith(".js") ||
      entry.shortName.includes(".tsx") ||
      entry.shortName.includes(".ts")
    ).length;

    const styles = entries.filter((entry) => entry.initiatorType === "css" || entry.shortName.endsWith(".css")).length;
    const transfer = entries.reduce((sum, entry) => sum + entry.transferSize, 0);
    const decoded = entries.reduce((sum, entry) => sum + entry.decodedBodySize, 0);
    const slowest = entries.reduce<ChunkEntry | null>((max, entry) => !max || entry.duration > max.duration ? entry : max, null);

    return {
      total,
      scripts,
      styles,
      transfer,
      decoded,
      slowest
    };
  }, [entries]);

  function refresh() {
    setEntries(collectEntries());
    setLastRefresh(new Date().toLocaleTimeString());
  }

  function clearResourceBuffer() {
    performance.clearResourceTimings();
    setEntries([]);
    setLastRefresh(new Date().toLocaleTimeString());
  }

  const cards = [
    {
      label: "Observer",
      value: observerState,
      detail: `Last refresh ${lastRefresh}`
    },
    {
      label: "Resources",
      value: String(summary.total),
      detail: "Relevant Vite/module resources observed"
    },
    {
      label: "Scripts",
      value: String(summary.scripts),
      detail: "JS/TS/module-like resource entries"
    },
    {
      label: "Styles",
      value: String(summary.styles),
      detail: "CSS/style resource entries"
    },
    {
      label: "Transfer",
      value: formatBytes(summary.transfer),
      detail: "May be 0 for cache/local/CORS cases"
    },
    {
      label: "Slowest",
      value: summary.slowest ? `${summary.slowest.duration} ms` : "—",
      detail: summary.slowest?.shortName ?? "No resource yet"
    }
  ];

  return (
    <section className="rf-chunk-v16">
      <header className="rf-chunk-v16-header">
        <div>
          <div className="rf-chunk-v16-title">TRFMC RF Chunk Observatory V16</div>
          <div className="rf-chunk-v16-sub">
            Runtime chunk/resource monitor · validates lazy loading behavior · PerformanceResourceTiming evidence
          </div>
        </div>

        <div className="rf-chunk-v16-badges">
          <span>RESOURCE TIMING</span>
          <span>PERFORMANCE OBSERVER</span>
          <span>VITE LAZY AUDIT</span>
          <span>READ ONLY</span>
        </div>
      </header>

      <div className="rf-chunk-v16-actions">
        <button onClick={refresh}>Refresh chunk table</button>
        <button onClick={clearResourceBuffer}>Clear resource timing buffer</button>
      </div>

      <div className="rf-chunk-v16-grid">
        {cards.map((card) => (
          <div className="rf-chunk-v16-card" key={card.label}>
            <b>{card.label}</b>
            <span>{card.value}</span>
            <small>{card.detail}</small>
          </div>
        ))}
      </div>

      <div className="rf-chunk-v16-table-wrap">
        <table className="rf-chunk-v16-table">
          <thead>
            <tr>
              <th>Resource</th>
              <th>Initiator</th>
              <th>Start</th>
              <th>Duration</th>
              <th>Transfer</th>
              <th>Decoded</th>
            </tr>
          </thead>
          <tbody>
            {entries.slice(0, 80).map((entry) => (
              <tr key={`${entry.name}-${entry.startTime}`}>
                <td>
                  {entry.shortName}
                  <br />
                  <small>{entry.name}</small>
                </td>
                <td>{entry.initiatorType}</td>
                <td>{entry.startTime} ms</td>
                <td className={entry.duration > 250 ? "rf-chunk-bad" : entry.duration > 100 ? "rf-chunk-warn" : "rf-chunk-ok"}>
                  {entry.duration} ms
                </td>
                <td>{formatBytes(entry.transferSize)}</td>
                <td>{formatBytes(entry.decodedBodySize)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
TSX

echo
echo "=== CREO WRAPPER V16 ==="

cat > src/rf_instruments/instruments/RFOperationalDeckV16ChunkObservatory.tsx <<'TSX'
import React from "react";

import { RFOperationalDeckV15Lazy } from "./RFOperationalDeckV15Lazy";
import { RFChunkObservatoryV16 } from "../telemetry/RFChunkObservatoryV16";

export function RFOperationalDeckV16ChunkObservatory() {
  return (
    <section>
      <RFChunkObservatoryV16 />
      <RFOperationalDeckV15Lazy />
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V15 -> V16 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFOperationalDeckV15Lazy\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFOperationalDeckV15Lazy['\"];?\n",
    "import { RFOperationalDeckV16ChunkObservatory } from '../rf_instruments/instruments/RFOperationalDeckV16ChunkObservatory'\n",
    s,
    count=1
)

if "RFOperationalDeckV16ChunkObservatory" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFOperationalDeckV16ChunkObservatory } from '../rf_instruments/instruments/RFOperationalDeckV16ChunkObservatory'\n")
    s = "".join(lines)

s = s.replace("<RFOperationalDeckV15Lazy />", "<RFOperationalDeckV16ChunkObservatory />")

p.write_text(s)
print("OK: main.tsx patched to RFOperationalDeckV16ChunkObservatory")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v16_chunk_observatory.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_chunk_observatory_v16_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_chunk_observatory_v16_${TS}" src/styles.css
echo "Rollback V16 Chunk Observatory completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v16_chunk_observatory.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_CHUNK_OBSERVATORY_V16",
  "created": [
    "src/rf_instruments/telemetry/RFChunkObservatoryV16.tsx",
    "src/rf_instruments/instruments/RFOperationalDeckV16ChunkObservatory.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "features": [
    "PerformanceResourceTiming",
    "PerformanceObserver_resource",
    "runtime_chunk_table",
    "transfer_size_when_available",
    "slowest_resource_detection",
    "lazy_loading_runtime_audit",
    "read_only"
  ],
  "preserves_v15_lazy_deck": true,
  "pre_patch_freeze": "${FREEZE}",
  "rollback": "${QUALITY_DIR}/rollback_v16_chunk_observatory.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_chunk_observatory_v16

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFOperationalDeckV16ChunkObservatory\\|RFOperationalDeckV15Lazy" src/app/main.tsx || true

echo
echo "=== FILES V16 ==="
ls -lh \
  src/rf_instruments/telemetry/RFChunkObservatoryV16.tsx \
  src/rf_instruments/instruments/RFOperationalDeckV16ChunkObservatory.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_chunk_observatory_v16/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V16 CHUNK OBSERVATORY CREATO. RIAVVIA VITE."
echo "============================================================"
