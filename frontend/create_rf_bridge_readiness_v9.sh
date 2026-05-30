#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_BRIDGE_READINESS_V9_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_BRIDGE_READINESS_V9_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF BRIDGE READINESS V9"
echo "Read-only local probe gate · Vite/API/RF bridge/OpenAPI"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/telemetry

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime.tsx || { echo "ERRORE: RFInstrumentSuiteV8SourceRuntime.tsx mancante"; exit 1; }

grep -q "RFInstrumentSuiteV8SourceRuntime" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V8. Non procedo."
  exit 1
}

echo "OK: V8 presente e montato"

echo
echo "=== BACKUP STATO V8 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_bridge_readiness_v9_${TS}"
cp src/styles.css "src/styles.css.bak_rf_bridge_readiness_v9_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== APPENDO CSS V9 ==="

if ! grep -q "TRFMC_RF_BRIDGE_READINESS_V9_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_BRIDGE_READINESS_V9_STYLE */
.rf-bridge-v9{
  margin-bottom:12px;
  border:1px solid rgba(125,255,178,.30);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 86% 0%,rgba(125,255,178,.12),transparent 34%),
    linear-gradient(145deg,rgba(4,23,20,.96),rgba(0,4,9,.99));
  box-shadow:
    0 26px 95px rgba(0,0,0,.62),
    inset 0 0 48px rgba(125,255,178,.035);
}

.rf-bridge-v9-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:14px;
  padding:14px;
  border-bottom:1px solid rgba(125,255,178,.20);
  background:linear-gradient(180deg,rgba(8,38,32,.95),rgba(2,9,16,.98));
}

.rf-bridge-v9-title{
  color:#efffff;
  font-size:17px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.12em;
  text-shadow:0 0 18px rgba(125,255,178,.42);
}

.rf-bridge-v9-sub{
  margin-top:5px;
  color:#8fb8c8;
  font-size:11px;
}

.rf-bridge-v9-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-bridge-v9-badges span{
  border:1px solid rgba(125,255,178,.25);
  background:rgba(125,255,178,.06);
  color:#7dffb2;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-bridge-v9-actions{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  padding:10px;
  border-bottom:1px solid rgba(125,255,178,.12);
}

.rf-bridge-v9-grid{
  padding:10px;
  display:grid;
  grid-template-columns:repeat(5,minmax(160px,1fr));
  gap:10px;
}

.rf-bridge-v9-card{
  border:1px solid rgba(125,255,178,.20);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(8,28,26,.88),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(125,255,178,.08),transparent 35%);
}

.rf-bridge-v9-card b{
  display:block;
  color:#7dffb2;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-bridge-v9-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:15px;
  font-weight:850;
}

.rf-bridge-v9-card small{
  display:block;
  color:#8fb8c8;
  margin-top:6px;
  line-height:1.45;
  word-break:break-all;
}

.rf-bridge-v9-table-wrap{
  padding:0 10px 10px;
}

.rf-bridge-v9-table{
  width:100%;
  border-collapse:collapse;
  font-family:ui-monospace,Consolas,monospace;
  font-size:12px;
  border:1px solid rgba(125,255,178,.16);
  border-radius:16px;
  overflow:hidden;
}

.rf-bridge-v9-table th,
.rf-bridge-v9-table td{
  border-bottom:1px solid rgba(125,255,178,.14);
  padding:8px 9px;
  text-align:left;
}

.rf-bridge-v9-table th{
  color:#7dffb2;
  background:rgba(125,255,178,.055);
  text-transform:uppercase;
  letter-spacing:.08em;
  font-size:10px;
}

.rf-bridge-ok{ color:#7dffb2; }
.rf-bridge-warn{ color:#ffd166; }
.rf-bridge-bad{ color:#ff5f7a; }

@media(max-width:1500px){
  .rf-bridge-v9-grid{ grid-template-columns:repeat(2,minmax(160px,1fr)); }
  .rf-bridge-v9-header{ grid-template-columns:1fr; }
  .rf-bridge-v9-badges{ justify-content:flex-start; }
}

@media(max-width:760px){
  .rf-bridge-v9-grid{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO BRIDGE READINESS PANEL V9 ==="

cat > src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx <<'TSX'
import React, { useMemo, useState } from "react";

type ProbeStatus = "idle" | "ok" | "warn" | "error";

type ProbeTarget = {
  id: string;
  label: string;
  url: string;
  expected: string;
};

type ProbeResult = {
  id: string;
  status: ProbeStatus;
  httpStatus?: number;
  ms?: number;
  message: string;
  sample?: string;
};

const targets: ProbeTarget[] = [
  {
    id: "vite-root",
    label: "Vite Root",
    url: "http://127.0.0.1:5173/",
    expected: "React/Vite local root"
  },
  {
    id: "vite-openapi",
    label: "Vite Static Registry",
    url: "http://127.0.0.1:5173/trfmc_portal_registry_unified.json",
    expected: "Static portal registry"
  },
  {
    id: "api-8000-health",
    label: "Backend 8000 Health",
    url: "http://127.0.0.1:8000/api/health",
    expected: "FastAPI health endpoint"
  },
  {
    id: "api-8090-health",
    label: "Bridge 8090 Health",
    url: "http://127.0.0.1:8090/api/health",
    expected: "RF/bridge health endpoint"
  },
  {
    id: "api-8000-openapi",
    label: "Backend OpenAPI",
    url: "http://127.0.0.1:8000/openapi.json",
    expected: "OpenAPI schema"
  }
];

function statusClass(status: ProbeStatus) {
  if (status === "ok") return "rf-bridge-ok";
  if (status === "warn") return "rf-bridge-warn";
  if (status === "error") return "rf-bridge-bad";
  return "";
}

async function probe(target: ProbeTarget): Promise<ProbeResult> {
  const started = performance.now();

  try {
    const controller = new AbortController();
    const timer = window.setTimeout(() => controller.abort(), 1800);

    const res = await fetch(target.url, {
      method: "GET",
      cache: "no-store",
      signal: controller.signal
    });

    window.clearTimeout(timer);

    const ms = Math.round(performance.now() - started);
    const text = await res.text();
    const sample = text.slice(0, 160).replace(/\s+/g, " ");

    return {
      id: target.id,
      status: res.ok ? "ok" : "warn",
      httpStatus: res.status,
      ms,
      message: res.ok ? "reachable" : `HTTP ${res.status}`,
      sample
    };
  } catch (error) {
    const ms = Math.round(performance.now() - started);

    return {
      id: target.id,
      status: "error",
      ms,
      message: error instanceof Error ? error.message : "probe failed",
      sample: "—"
    };
  }
}

export function RFBridgeReadinessV9() {
  const [results, setResults] = useState<Record<string, ProbeResult>>({});
  const [running, setRunning] = useState(false);

  const summary = useMemo(() => {
    const values = Object.values(results);
    const ok = values.filter((r) => r.status === "ok").length;
    const warn = values.filter((r) => r.status === "warn").length;
    const error = values.filter((r) => r.status === "error").length;

    return {
      ok,
      warn,
      error,
      total: targets.length
    };
  }, [results]);

  async function runAll() {
    setRunning(true);

    const next: Record<string, ProbeResult> = {};

    for (const target of targets) {
      next[target.id] = {
        id: target.id,
        status: "idle",
        message: "running..."
      };

      setResults({ ...next });

      const result = await probe(target);
      next[target.id] = result;
      setResults({ ...next });
    }

    setRunning(false);
  }

  return (
    <section className="rf-bridge-v9">
      <header className="rf-bridge-v9-header">
        <div>
          <div className="rf-bridge-v9-title">TRFMC RF Bridge Readiness V9</div>
          <div className="rf-bridge-v9-sub">
            Read-only local probe gate · no SDR command · no Open5GS mutation · checks Vite/API/bridge availability
          </div>
        </div>

        <div className="rf-bridge-v9-badges">
          <span>GET ONLY</span>
          <span>NO COMMAND EXECUTION</span>
          <span>NO SDR TX</span>
          <span>NO CORE MUTATION</span>
        </div>
      </header>

      <div className="rf-bridge-v9-actions">
        <button onClick={runAll} disabled={running}>
          {running ? "Running probes..." : "Run read-only bridge probes"}
        </button>
      </div>

      <div className="rf-bridge-v9-grid">
        <div className="rf-bridge-v9-card">
          <b>Targets</b>
          <span>{summary.total}</span>
          <small>Local readiness checks</small>
        </div>
        <div className="rf-bridge-v9-card">
          <b>OK</b>
          <span className="rf-bridge-ok">{summary.ok}</span>
          <small>Reachable and HTTP OK</small>
        </div>
        <div className="rf-bridge-v9-card">
          <b>Warning</b>
          <span className="rf-bridge-warn">{summary.warn}</span>
          <small>Reachable but non-OK HTTP status</small>
        </div>
        <div className="rf-bridge-v9-card">
          <b>Error</b>
          <span className="rf-bridge-bad">{summary.error}</span>
          <small>Not reachable, timeout or CORS/browser block</small>
        </div>
        <div className="rf-bridge-v9-card">
          <b>Mode</b>
          <span>Read-only</span>
          <small>No write, no start, no stop, no SDR control</small>
        </div>
      </div>

      <div className="rf-bridge-v9-table-wrap">
        <table className="rf-bridge-v9-table">
          <thead>
            <tr>
              <th>Target</th>
              <th>Expected</th>
              <th>Status</th>
              <th>HTTP</th>
              <th>Latency</th>
              <th>URL / Sample</th>
            </tr>
          </thead>
          <tbody>
            {targets.map((target) => {
              const result = results[target.id];

              return (
                <tr key={target.id}>
                  <td>{target.label}</td>
                  <td>{target.expected}</td>
                  <td className={statusClass(result?.status ?? "idle")}>
                    {result?.status ?? "idle"} · {result?.message ?? "not tested"}
                  </td>
                  <td>{result?.httpStatus ?? "—"}</td>
                  <td>{result?.ms ? `${result.ms} ms` : "—"}</td>
                  <td>
                    {target.url}
                    <br />
                    <small>{result?.sample ?? "—"}</small>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </section>
  );
}
TSX

echo
echo "=== CREO WRAPPER V9 ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness.tsx <<'TSX'
import React from "react";

import { RFInstrumentSuiteV8SourceRuntime } from "./RFInstrumentSuiteV8SourceRuntime";
import { RFBridgeReadinessV9 } from "../telemetry/RFBridgeReadinessV9";

export function RFInstrumentSuiteV9BridgeReadiness() {
  return (
    <section>
      <RFBridgeReadinessV9 />
      <RFInstrumentSuiteV8SourceRuntime />
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V8 -> V9 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV8SourceRuntime\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV8SourceRuntime['\"];?\n",
    "import { RFInstrumentSuiteV9BridgeReadiness } from '../rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness'\n",
    s,
    count=1
)

if "RFInstrumentSuiteV9BridgeReadiness" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFInstrumentSuiteV9BridgeReadiness } from '../rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV8SourceRuntime />", "<RFInstrumentSuiteV9BridgeReadiness />")

p.write_text(s)
print("OK: main.tsx patched to V9 Bridge Readiness")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v9_bridge_readiness.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_bridge_readiness_v9_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_bridge_readiness_v9_${TS}" src/styles.css
echo "Rollback V9 Bridge Readiness completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v9_bridge_readiness.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_BRIDGE_READINESS_V9",
  "created": [
    "src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx",
    "src/rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "probe_mode": "read_only_get",
  "live_sdr_auto_connect": false,
  "open5gs_mutation": false,
  "preserves_v8_source_runtime": true,
  "rollback": "${QUALITY_DIR}/rollback_v9_bridge_readiness.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_bridge_readiness_v9

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV9BridgeReadiness\\|RFInstrumentSuiteV8SourceRuntime\\|RFInstrumentSuiteV7SourceBridge" src/app/main.tsx || true

echo
echo "=== FILES ==="
ls -lh \
  src/rf_instruments/telemetry/RFBridgeReadinessV9.tsx \
  src/rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_bridge_readiness_v9/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V9 BRIDGE READINESS CREATO. ORA RIAVVIA VITE."
echo "============================================================"
