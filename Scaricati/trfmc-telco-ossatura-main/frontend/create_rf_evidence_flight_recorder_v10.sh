#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_EVIDENCE_FLIGHT_RECORDER_V10_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_EVIDENCE_FLIGHT_RECORDER_V10_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF EVIDENCE FLIGHT RECORDER V10"
echo "Runtime evidence · localStorage snapshot · JSON dossier export"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/evidence

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness.tsx || { echo "ERRORE: V9 mancante. Prima completare V9."; exit 1; }

grep -q "RFInstrumentSuiteV9BridgeReadiness" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V9 Bridge Readiness. Non procedo."
  exit 1
}

echo "OK: V9 presente e montato"

echo
echo "=== BACKUP STATO V9 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_evidence_v10_${TS}"
cp src/styles.css "src/styles.css.bak_rf_evidence_v10_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== APPENDO CSS V10 ==="

if ! grep -q "TRFMC_RF_EVIDENCE_FLIGHT_RECORDER_V10_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_EVIDENCE_FLIGHT_RECORDER_V10_STYLE */
.rf-evidence-v10{
  margin-bottom:12px;
  border:1px solid rgba(180,120,255,.32);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 84% 0%,rgba(180,120,255,.15),transparent 34%),
    radial-gradient(circle at 12% 100%,rgba(0,229,255,.08),transparent 30%),
    linear-gradient(145deg,rgba(18,9,34,.96),rgba(0,4,9,.99));
  box-shadow:
    0 26px 95px rgba(0,0,0,.66),
    inset 0 0 48px rgba(180,120,255,.035);
}

.rf-evidence-v10-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:14px;
  padding:14px;
  border-bottom:1px solid rgba(180,120,255,.22);
  background:linear-gradient(180deg,rgba(28,15,50,.96),rgba(2,9,16,.98));
}

.rf-evidence-v10-title{
  color:#f6edff;
  font-size:17px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.12em;
  text-shadow:0 0 18px rgba(180,120,255,.45);
}

.rf-evidence-v10-sub{
  margin-top:5px;
  color:#bda8d8;
  font-size:11px;
}

.rf-evidence-v10-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-evidence-v10-badges span{
  border:1px solid rgba(180,120,255,.28);
  background:rgba(180,120,255,.07);
  color:#dcbcff;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-evidence-v10-actions{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  padding:10px;
  border-bottom:1px solid rgba(180,120,255,.14);
}

.rf-evidence-v10-grid{
  padding:10px;
  display:grid;
  grid-template-columns:repeat(5,minmax(160px,1fr));
  gap:10px;
}

.rf-evidence-v10-card{
  border:1px solid rgba(180,120,255,.22);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(22,13,39,.90),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(180,120,255,.08),transparent 35%);
}

.rf-evidence-v10-card b{
  display:block;
  color:#dcbcff;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-evidence-v10-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:15px;
  font-weight:850;
}

.rf-evidence-v10-card small{
  display:block;
  color:#bda8d8;
  margin-top:6px;
  line-height:1.45;
  word-break:break-all;
}

.rf-evidence-v10-pre{
  margin:0 10px 10px;
  border:1px solid rgba(180,120,255,.18);
  border-radius:16px;
  background:#02060c;
  color:#eafbff;
  padding:10px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:11px;
  max-height:240px;
  overflow:auto;
}

.rf-evidence-v10-ok{ color:#7dffb2; }
.rf-evidence-v10-warn{ color:#ffd166; }
.rf-evidence-v10-bad{ color:#ff5f7a; }

@media(max-width:1500px){
  .rf-evidence-v10-grid{ grid-template-columns:repeat(2,minmax(160px,1fr)); }
  .rf-evidence-v10-header{ grid-template-columns:1fr; }
  .rf-evidence-v10-badges{ justify-content:flex-start; }
}

@media(max-width:760px){
  .rf-evidence-v10-grid{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO EVIDENCE FLIGHT RECORDER V10 ==="

cat > src/rf_instruments/evidence/RFEvidenceFlightRecorderV10.tsx <<'TSX'
import React, { useMemo, useState } from "react";

type ProbeStatus = "ok" | "warn" | "error";

type ProbeTarget = {
  id: string;
  label: string;
  url: string;
  domain: "frontend" | "registry" | "backend" | "bridge" | "openapi";
};

type ProbeResult = {
  id: string;
  label: string;
  domain: string;
  url: string;
  status: ProbeStatus;
  httpStatus?: number;
  latencyMs: number;
  message: string;
  sample: string;
};

type EvidenceSnapshot = {
  recorder: "TRFMC_RF_EVIDENCE_FLIGHT_RECORDER_V10";
  timestamp: string;
  href: string;
  userAgent: string;
  result: "PASS" | "PARTIAL" | "FAIL";
  counters: {
    total: number;
    ok: number;
    warn: number;
    error: number;
  };
  targets: ProbeResult[];
  doctrine: {
    readOnly: true;
    noSdrControl: true;
    noOpen5gsMutation: true;
    noExternalDependency: true;
  };
};

const STORAGE_KEY = "TRFMC_RF_EVIDENCE_FLIGHT_RECORDER_V10_LAST";

const targets: ProbeTarget[] = [
  {
    id: "vite-root",
    label: "Vite / React root",
    url: "http://127.0.0.1:5173/",
    domain: "frontend"
  },
  {
    id: "portal-registry",
    label: "Unified portal registry",
    url: "http://127.0.0.1:5173/trfmc_portal_registry_unified.json",
    domain: "registry"
  },
  {
    id: "v6r3-entrypoint",
    label: "Protected V6R3 entrypoint",
    url: "http://127.0.0.1:5173/trfmc_official_safe_entrypoint_v6r3_command_center.html",
    domain: "frontend"
  },
  {
    id: "backend-health",
    label: "Backend 8000 health",
    url: "http://127.0.0.1:8000/api/health",
    domain: "backend"
  },
  {
    id: "bridge-health",
    label: "Bridge 8090 health",
    url: "http://127.0.0.1:8090/api/health",
    domain: "bridge"
  },
  {
    id: "backend-openapi",
    label: "Backend OpenAPI schema",
    url: "http://127.0.0.1:8000/openapi.json",
    domain: "openapi"
  }
];

async function runProbe(target: ProbeTarget): Promise<ProbeResult> {
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

    const latencyMs = Math.round(performance.now() - started);
    const text = await res.text();
    const sample = text.slice(0, 180).replace(/\s+/g, " ");

    return {
      id: target.id,
      label: target.label,
      domain: target.domain,
      url: target.url,
      status: res.ok ? "ok" : "warn",
      httpStatus: res.status,
      latencyMs,
      message: res.ok ? "reachable" : `HTTP ${res.status}`,
      sample
    };
  } catch (error) {
    return {
      id: target.id,
      label: target.label,
      domain: target.domain,
      url: target.url,
      status: "error",
      latencyMs: Math.round(performance.now() - started),
      message: error instanceof Error ? error.message : "probe failed",
      sample: "—"
    };
  }
}

function buildSnapshot(results: ProbeResult[]): EvidenceSnapshot {
  const ok = results.filter((r) => r.status === "ok").length;
  const warn = results.filter((r) => r.status === "warn").length;
  const error = results.filter((r) => r.status === "error").length;

  const result =
    error === 0 && warn === 0
      ? "PASS"
      : ok > 0
        ? "PARTIAL"
        : "FAIL";

  return {
    recorder: "TRFMC_RF_EVIDENCE_FLIGHT_RECORDER_V10",
    timestamp: new Date().toISOString(),
    href: window.location.href,
    userAgent: navigator.userAgent,
    result,
    counters: {
      total: results.length,
      ok,
      warn,
      error
    },
    targets: results,
    doctrine: {
      readOnly: true,
      noSdrControl: true,
      noOpen5gsMutation: true,
      noExternalDependency: true
    }
  };
}

function downloadJson(snapshot: EvidenceSnapshot) {
  const blob = new Blob([JSON.stringify(snapshot, null, 2)], {
    type: "application/json"
  });

  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `trfmc_evidence_flight_recorder_v10_${snapshot.timestamp.replace(/[:.]/g, "-")}.json`;
  a.click();
  URL.revokeObjectURL(url);
}

export function RFEvidenceFlightRecorderV10() {
  const [running, setRunning] = useState(false);
  const [snapshot, setSnapshot] = useState<EvidenceSnapshot | null>(() => {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;

    try {
      return JSON.parse(raw) as EvidenceSnapshot;
    } catch {
      return null;
    }
  });

  const counters = useMemo(
    () => snapshot?.counters ?? { total: targets.length, ok: 0, warn: 0, error: 0 },
    [snapshot]
  );

  async function capture() {
    setRunning(true);

    const results: ProbeResult[] = [];

    for (const target of targets) {
      const result = await runProbe(target);
      results.push(result);

      const partial = buildSnapshot([...results]);
      setSnapshot(partial);
    }

    const finalSnapshot = buildSnapshot(results);
    setSnapshot(finalSnapshot);
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(finalSnapshot));
    setRunning(false);
  }

  function clearSnapshot() {
    window.localStorage.removeItem(STORAGE_KEY);
    setSnapshot(null);
  }

  return (
    <section className="rf-evidence-v10">
      <header className="rf-evidence-v10-header">
        <div>
          <div className="rf-evidence-v10-title">TRFMC RF Evidence Flight Recorder V10</div>
          <div className="rf-evidence-v10-sub">
            Runtime black box · read-only probes · localStorage snapshot · exportable JSON dossier
          </div>
        </div>

        <div className="rf-evidence-v10-badges">
          <span>READ ONLY</span>
          <span>LOCAL STORAGE</span>
          <span>JSON DOSSIER</span>
          <span>NO SDR CONTROL</span>
          <span>NO CORE MUTATION</span>
        </div>
      </header>

      <div className="rf-evidence-v10-actions">
        <button onClick={capture} disabled={running}>
          {running ? "Capturing evidence..." : "Capture runtime evidence"}
        </button>

        <button onClick={() => snapshot && downloadJson(snapshot)} disabled={!snapshot}>
          Download JSON dossier
        </button>

        <button onClick={clearSnapshot} disabled={!snapshot || running}>
          Clear snapshot
        </button>
      </div>

      <div className="rf-evidence-v10-grid">
        <div className="rf-evidence-v10-card">
          <b>Result</b>
          <span className={
            snapshot?.result === "PASS"
              ? "rf-evidence-v10-ok"
              : snapshot?.result === "PARTIAL"
                ? "rf-evidence-v10-warn"
                : snapshot?.result === "FAIL"
                  ? "rf-evidence-v10-bad"
                  : ""
          }>
            {snapshot?.result ?? "IDLE"}
          </span>
          <small>{snapshot?.timestamp ?? "No evidence captured yet"}</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>Total</b>
          <span>{counters.total}</span>
          <small>Read-only probe targets</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>OK</b>
          <span className="rf-evidence-v10-ok">{counters.ok}</span>
          <small>HTTP reachable and OK</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>Warn</b>
          <span className="rf-evidence-v10-warn">{counters.warn}</span>
          <small>Reachable but non-OK HTTP</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>Error</b>
          <span className="rf-evidence-v10-bad">{counters.error}</span>
          <small>Offline, timeout, CORS or unavailable</small>
        </div>
      </div>

      <pre className="rf-evidence-v10-pre">
        {snapshot
          ? JSON.stringify(snapshot, null, 2)
          : "No snapshot. Press Capture runtime evidence."}
      </pre>
    </section>
  );
}
TSX

echo
echo "=== CREO WRAPPER V10 ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV10EvidenceRecorder.tsx <<'TSX'
import React from "react";

import { RFInstrumentSuiteV9BridgeReadiness } from "./RFInstrumentSuiteV9BridgeReadiness";
import { RFEvidenceFlightRecorderV10 } from "../evidence/RFEvidenceFlightRecorderV10";

export function RFInstrumentSuiteV10EvidenceRecorder() {
  return (
    <section>
      <RFEvidenceFlightRecorderV10 />
      <RFInstrumentSuiteV9BridgeReadiness />
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V9 -> V10 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV9BridgeReadiness\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV9BridgeReadiness['\"];?\n",
    "import { RFInstrumentSuiteV10EvidenceRecorder } from '../rf_instruments/instruments/RFInstrumentSuiteV10EvidenceRecorder'\n",
    s,
    count=1
)

if "RFInstrumentSuiteV10EvidenceRecorder" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFInstrumentSuiteV10EvidenceRecorder } from '../rf_instruments/instruments/RFInstrumentSuiteV10EvidenceRecorder'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV9BridgeReadiness />", "<RFInstrumentSuiteV10EvidenceRecorder />")

p.write_text(s)
print("OK: main.tsx patched to V10 Evidence Recorder")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v10_evidence_recorder.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_evidence_v10_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_evidence_v10_${TS}" src/styles.css
echo "Rollback V10 Evidence Flight Recorder completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v10_evidence_recorder.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_EVIDENCE_FLIGHT_RECORDER_V10",
  "created": [
    "src/rf_instruments/evidence/RFEvidenceFlightRecorderV10.tsx",
    "src/rf_instruments/instruments/RFInstrumentSuiteV10EvidenceRecorder.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "features": [
    "read_only_runtime_probes",
    "localStorage_snapshot",
    "json_dossier_download",
    "no_sdr_control",
    "no_open5gs_mutation"
  ],
  "preserves_v9_bridge_readiness": true,
  "rollback": "${QUALITY_DIR}/rollback_v10_evidence_recorder.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_evidence_flight_recorder_v10

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV10EvidenceRecorder\\|RFInstrumentSuiteV9BridgeReadiness\\|RFInstrumentSuiteV8SourceRuntime" src/app/main.tsx || true

echo
echo "=== FILES ==="
ls -lh \
  src/rf_instruments/evidence/RFEvidenceFlightRecorderV10.tsx \
  src/rf_instruments/instruments/RFInstrumentSuiteV10EvidenceRecorder.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_evidence_flight_recorder_v10/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V10 EVIDENCE FLIGHT RECORDER CREATO. ORA RIAVVIA VITE."
echo "============================================================"
