#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_RENDER_GOVERNOR_V12_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_RENDER_GOVERNOR_V12_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF RENDER GOVERNOR V12"
echo "Adaptive rendering policy · FPS/Jitter/LongTask/Visibility"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/telemetry

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV11PerformanceTelemetry.tsx || { echo "ERRORE: V11 mancante. Prima completare V11."; exit 1; }

grep -q "RFInstrumentSuiteV11PerformanceTelemetry" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V11 Performance Telemetry. Non procedo."
  exit 1
}

echo "OK: V11 presente e montato"

echo
echo "=== BACKUP STATO V11 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_governor_v12_${TS}"
cp src/styles.css "src/styles.css.bak_rf_governor_v12_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== CREO GOVERNOR BUS V12 ==="

cat > src/rf_instruments/telemetry/RFRenderGovernorBusV12.ts <<'TS'
export type RFRenderProfileV12 =
  | "ULTRA"
  | "HIGH"
  | "BALANCED"
  | "SAFE"
  | "BACKGROUND";

export type RFRenderGovernorPolicyV12 = {
  profile: RFRenderProfileV12;
  fpsTarget: number;
  canvasScale: number;
  waterfallEveryNFrames: number;
  iqPointBudget: number;
  spectrumBins: number;
  animationEnabled: boolean;
  reason: string;
  timestamp: string;
};

export const RF_RENDER_GOVERNOR_EVENT_V12 = "trfmc:rf-render-governor:v12";
export const RF_RENDER_GOVERNOR_STORAGE_V12 = "TRFMC_RF_RENDER_GOVERNOR_V12_POLICY";

export function dispatchRFRenderGovernorPolicyV12(policy: RFRenderGovernorPolicyV12) {
  window.localStorage.setItem(RF_RENDER_GOVERNOR_STORAGE_V12, JSON.stringify(policy));

  window.dispatchEvent(
    new CustomEvent<RFRenderGovernorPolicyV12>(RF_RENDER_GOVERNOR_EVENT_V12, {
      detail: policy
    })
  );
}

export function readRFRenderGovernorPolicyV12(): RFRenderGovernorPolicyV12 | null {
  const raw = window.localStorage.getItem(RF_RENDER_GOVERNOR_STORAGE_V12);
  if (!raw) return null;

  try {
    return JSON.parse(raw) as RFRenderGovernorPolicyV12;
  } catch {
    return null;
  }
}
TS

echo
echo "=== APPENDO CSS V12 ==="

if ! grep -q "TRFMC_RF_RENDER_GOVERNOR_V12_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_RENDER_GOVERNOR_V12_STYLE */
.rf-governor-v12{
  margin-bottom:12px;
  border:1px solid rgba(125,255,178,.34);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 84% 0%,rgba(125,255,178,.14),transparent 34%),
    radial-gradient(circle at 12% 100%,rgba(57,215,255,.08),transparent 30%),
    linear-gradient(145deg,rgba(4,26,22,.96),rgba(0,4,9,.99));
  box-shadow:
    0 26px 95px rgba(0,0,0,.66),
    inset 0 0 48px rgba(125,255,178,.035);
}

.rf-governor-v12-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:14px;
  padding:14px;
  border-bottom:1px solid rgba(125,255,178,.22);
  background:linear-gradient(180deg,rgba(8,39,34,.96),rgba(2,9,16,.98));
}

.rf-governor-v12-title{
  color:#efffff;
  font-size:17px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.12em;
  text-shadow:0 0 18px rgba(125,255,178,.45);
}

.rf-governor-v12-sub{
  margin-top:5px;
  color:#9bc7bd;
  font-size:11px;
}

.rf-governor-v12-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-governor-v12-badges span{
  border:1px solid rgba(125,255,178,.28);
  background:rgba(125,255,178,.07);
  color:#7dffb2;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-governor-v12-actions{
  display:flex;
  flex-wrap:wrap;
  gap:8px;
  padding:10px;
  border-bottom:1px solid rgba(125,255,178,.14);
}

.rf-governor-v12-grid{
  padding:10px;
  display:grid;
  grid-template-columns:repeat(7,minmax(135px,1fr));
  gap:10px;
}

.rf-governor-v12-card{
  border:1px solid rgba(125,255,178,.22);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(8,28,25,.90),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(125,255,178,.08),transparent 35%);
}

.rf-governor-v12-card b{
  display:block;
  color:#7dffb2;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-governor-v12-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:15px;
  font-weight:850;
}

.rf-governor-v12-card small{
  display:block;
  color:#9bc7bd;
  margin-top:6px;
  line-height:1.45;
  word-break:break-all;
}

.rf-governor-v12-pre{
  margin:0 10px 10px;
  border:1px solid rgba(125,255,178,.18);
  border-radius:16px;
  background:#02060c;
  color:#eafbff;
  padding:10px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:11px;
  max-height:190px;
  overflow:auto;
}

.rf-gov-ultra{ color:#7dffb2; }
.rf-gov-high{ color:#39d7ff; }
.rf-gov-balanced{ color:#ffd166; }
.rf-gov-safe{ color:#ff9f6e; }
.rf-gov-background{ color:#ff5f7a; }

@media(max-width:1600px){
  .rf-governor-v12-grid{ grid-template-columns:repeat(3,minmax(135px,1fr)); }
  .rf-governor-v12-header{ grid-template-columns:1fr; }
  .rf-governor-v12-badges{ justify-content:flex-start; }
}

@media(max-width:760px){
  .rf-governor-v12-grid{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO RFRenderGovernorV12.tsx ==="

cat > src/rf_instruments/telemetry/RFRenderGovernorV12.tsx <<'TSX'
import React, { useEffect, useMemo, useRef, useState } from "react";

import {
  dispatchRFRenderGovernorPolicyV12,
  RFRenderGovernorPolicyV12,
  RFRenderProfileV12
} from "./RFRenderGovernorBusV12";

type IdleWindow = Window & {
  requestIdleCallback?: (
    callback: (deadline: { didTimeout: boolean; timeRemaining: () => number }) => void,
    options?: { timeout?: number }
  ) => number;
  cancelIdleCallback?: (handle: number) => void;
};

type GovernorStats = {
  fps: number;
  jitterMs: number;
  longTasks: number;
  visibility: DocumentVisibilityState;
  manualMode: "auto" | RFRenderProfileV12;
};

const defaultStats: GovernorStats = {
  fps: 0,
  jitterMs: 0,
  longTasks: 0,
  visibility: document.visibilityState,
  manualMode: "auto"
};

function policyFor(stats: GovernorStats): RFRenderGovernorPolicyV12 {
  let profile: RFRenderProfileV12 = "ULTRA";
  let reason = "headroom available";

  if (stats.visibility === "hidden") {
    profile = "BACKGROUND";
    reason = "document hidden";
  } else if (stats.manualMode !== "auto") {
    profile = stats.manualMode;
    reason = "manual override";
  } else if (stats.fps < 24 || stats.jitterMs > 42 || stats.longTasks > 35) {
    profile = "SAFE";
    reason = "severe UI pressure";
  } else if (stats.fps < 42 || stats.jitterMs > 28 || stats.longTasks > 12) {
    profile = "BALANCED";
    reason = "moderate UI pressure";
  } else if (stats.fps < 55 || stats.jitterMs > 18 || stats.longTasks > 4) {
    profile = "HIGH";
    reason = "minor UI pressure";
  }

  const map: Record<RFRenderProfileV12, Omit<RFRenderGovernorPolicyV12, "profile" | "reason" | "timestamp">> = {
    ULTRA: {
      fpsTarget: 60,
      canvasScale: 1,
      waterfallEveryNFrames: 1,
      iqPointBudget: 800,
      spectrumBins: 4096,
      animationEnabled: true
    },
    HIGH: {
      fpsTarget: 50,
      canvasScale: 0.9,
      waterfallEveryNFrames: 2,
      iqPointBudget: 500,
      spectrumBins: 2048,
      animationEnabled: true
    },
    BALANCED: {
      fpsTarget: 36,
      canvasScale: 0.75,
      waterfallEveryNFrames: 3,
      iqPointBudget: 320,
      spectrumBins: 1024,
      animationEnabled: true
    },
    SAFE: {
      fpsTarget: 24,
      canvasScale: 0.6,
      waterfallEveryNFrames: 5,
      iqPointBudget: 160,
      spectrumBins: 512,
      animationEnabled: true
    },
    BACKGROUND: {
      fpsTarget: 5,
      canvasScale: 0.5,
      waterfallEveryNFrames: 12,
      iqPointBudget: 64,
      spectrumBins: 256,
      animationEnabled: false
    }
  };

  return {
    profile,
    reason,
    timestamp: new Date().toISOString(),
    ...map[profile]
  };
}

function profileClass(profile: RFRenderProfileV12) {
  if (profile === "ULTRA") return "rf-gov-ultra";
  if (profile === "HIGH") return "rf-gov-high";
  if (profile === "BALANCED") return "rf-gov-balanced";
  if (profile === "SAFE") return "rf-gov-safe";
  return "rf-gov-background";
}

export function RFRenderGovernorV12() {
  const [stats, setStats] = useState<GovernorStats>(defaultStats);
  const [policy, setPolicy] = useState<RFRenderGovernorPolicyV12>(() => policyFor(defaultStats));
  const [idleSupport, setIdleSupport] = useState(false);
  const [idleTicks, setIdleTicks] = useState(0);

  const frameTimes = useRef<number[]>([]);
  const raf = useRef<number | null>(null);
  const lastDispatch = useRef(0);

  useEffect(() => {
    const idleWindow = window as IdleWindow;
    setIdleSupport(typeof idleWindow.requestIdleCallback === "function");

    let idleHandle: number | null = null;
    let interval: number | null = null;

    const idleLoop = () => {
      setIdleTicks((old) => old + 1);

      if (typeof idleWindow.requestIdleCallback === "function") {
        idleHandle = idleWindow.requestIdleCallback(idleLoop, { timeout: 1000 });
      }
    };

    if (typeof idleWindow.requestIdleCallback === "function") {
      idleHandle = idleWindow.requestIdleCallback(idleLoop, { timeout: 1000 });
    } else {
      interval = window.setInterval(() => setIdleTicks((old) => old + 1), 1000);
    }

    return () => {
      if (idleHandle !== null && idleWindow.cancelIdleCallback) {
        idleWindow.cancelIdleCallback(idleHandle);
      }

      if (interval !== null) {
        window.clearInterval(interval);
      }
    };
  }, []);

  useEffect(() => {
    const onVisibility = () => {
      setStats((old) => ({
        ...old,
        visibility: document.visibilityState
      }));
    };

    document.addEventListener("visibilitychange", onVisibility);
    return () => document.removeEventListener("visibilitychange", onVisibility);
  }, []);

  useEffect(() => {
    const loop = (t: number) => {
      const list = frameTimes.current;
      list.push(t);

      while (list.length > 90) list.shift();

      if (list.length > 8) {
        const deltas = list.slice(1).map((v, i) => v - list[i]);
        const avg = deltas.reduce((a, b) => a + b, 0) / deltas.length;
        const max = Math.max(...deltas);
        const min = Math.min(...deltas);

        setStats((old) => ({
          ...old,
          fps: Math.round(1000 / avg),
          jitterMs: Math.round((max - min) * 10) / 10,
          visibility: document.visibilityState
        }));
      }

      raf.current = requestAnimationFrame(loop);
    };

    raf.current = requestAnimationFrame(loop);

    return () => {
      if (raf.current !== null) cancelAnimationFrame(raf.current);
    };
  }, []);

  useEffect(() => {
    let observer: PerformanceObserver | null = null;

    try {
      observer = new PerformanceObserver((list) => {
        setStats((old) => ({
          ...old,
          longTasks: old.longTasks + list.getEntries().length
        }));
      });

      observer.observe({ type: "longtask", buffered: true } as PerformanceObserverInit);
    } catch {
      observer = null;
    }

    return () => observer?.disconnect();
  }, []);

  useEffect(() => {
    const next = policyFor(stats);
    setPolicy(next);

    const now = performance.now();
    if (now - lastDispatch.current > 750) {
      dispatchRFRenderGovernorPolicyV12(next);
      lastDispatch.current = now;
    }
  }, [stats]);

  function setManual(mode: GovernorStats["manualMode"]) {
    setStats((old) => ({
      ...old,
      manualMode: mode
    }));
  }

  function resetLongTasks() {
    setStats((old) => ({
      ...old,
      longTasks: 0
    }));
  }

  const cards = useMemo(
    () => [
      { label: "Profile", value: policy.profile, detail: policy.reason, cls: profileClass(policy.profile) },
      { label: "FPS Target", value: `${policy.fpsTarget}`, detail: "Governor target" },
      { label: "Live FPS", value: `${stats.fps}`, detail: "rAF estimate" },
      { label: "Jitter", value: `${stats.jitterMs} ms`, detail: "frame interval spread" },
      { label: "Canvas Scale", value: `${policy.canvasScale}`, detail: "future renderer multiplier" },
      { label: "IQ Budget", value: `${policy.iqPointBudget}`, detail: "future point budget" },
      { label: "Long Tasks", value: `${stats.longTasks}`, detail: "UI pressure counter" }
    ],
    [policy, stats]
  );

  return (
    <section className="rf-governor-v12">
      <header className="rf-governor-v12-header">
        <div>
          <div className="rf-governor-v12-title">TRFMC RF Adaptive Render Governor V12</div>
          <div className="rf-governor-v12-sub">
            Adaptive profile bus · FPS/Jitter/LongTask/Visibility · safe performance governor for RF/Telco rendering load
          </div>
        </div>

        <div className="rf-governor-v12-badges">
          <span>PROFILE {policy.profile}</span>
          <span>VISIBILITY {stats.visibility}</span>
          <span>IDLE {idleSupport ? "SUPPORTED" : "FALLBACK"}</span>
          <span>DISPATCH EVENT BUS</span>
        </div>
      </header>

      <div className="rf-governor-v12-actions">
        <button onClick={() => setManual("auto")}>Auto</button>
        <button onClick={() => setManual("ULTRA")}>Force Ultra</button>
        <button onClick={() => setManual("HIGH")}>Force High</button>
        <button onClick={() => setManual("BALANCED")}>Force Balanced</button>
        <button onClick={() => setManual("SAFE")}>Force Safe</button>
        <button onClick={() => setManual("BACKGROUND")}>Force Background</button>
        <button onClick={resetLongTasks}>Reset LongTask Counter</button>
      </div>

      <div className="rf-governor-v12-grid">
        {cards.map((card) => (
          <div className="rf-governor-v12-card" key={card.label}>
            <b>{card.label}</b>
            <span className={card.cls ?? ""}>{card.value}</span>
            <small>{card.detail}</small>
          </div>
        ))}
      </div>

      <pre className="rf-governor-v12-pre">
        {JSON.stringify(
          {
            policy,
            stats,
            idle: {
              supported: idleSupport,
              ticks: idleTicks
            },
            storageKey: "TRFMC_RF_RENDER_GOVERNOR_V12_POLICY",
            event: "trfmc:rf-render-governor:v12"
          },
          null,
          2
        )}
      </pre>
    </section>
  );
}
TSX

echo
echo "=== CREO WRAPPER V12 ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor.tsx <<'TSX'
import React from "react";

import { RFInstrumentSuiteV11PerformanceTelemetry } from "./RFInstrumentSuiteV11PerformanceTelemetry";
import { RFRenderGovernorV12 } from "../telemetry/RFRenderGovernorV12";

export function RFInstrumentSuiteV12RenderGovernor() {
  return (
    <section>
      <RFRenderGovernorV12 />
      <RFInstrumentSuiteV11PerformanceTelemetry />
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V11 -> V12 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV11PerformanceTelemetry\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV11PerformanceTelemetry['\"];?\n",
    "import { RFInstrumentSuiteV12RenderGovernor } from '../rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor'\n",
    s,
    count=1
)

if "RFInstrumentSuiteV12RenderGovernor" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFInstrumentSuiteV12RenderGovernor } from '../rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV11PerformanceTelemetry />", "<RFInstrumentSuiteV12RenderGovernor />")

p.write_text(s)
print("OK: main.tsx patched to V12 Render Governor")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v12_render_governor.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_governor_v12_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_governor_v12_${TS}" src/styles.css
echo "Rollback V12 Render Governor completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v12_render_governor.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_RENDER_GOVERNOR_V12",
  "created": [
    "src/rf_instruments/telemetry/RFRenderGovernorBusV12.ts",
    "src/rf_instruments/telemetry/RFRenderGovernorV12.tsx",
    "src/rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css"
  ],
  "profiles": [
    "ULTRA",
    "HIGH",
    "BALANCED",
    "SAFE",
    "BACKGROUND"
  ],
  "features": [
    "fps_estimation",
    "frame_jitter",
    "visibility_state",
    "longtask_observer_when_supported",
    "requestIdleCallback_with_interval_fallback",
    "localStorage_policy",
    "window_custom_event_policy_bus"
  ],
  "preserves_v11_performance_telemetry": true,
  "rollback": "${QUALITY_DIR}/rollback_v12_render_governor.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_render_governor_v12

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV12RenderGovernor\\|RFInstrumentSuiteV11PerformanceTelemetry\\|RFInstrumentSuiteV10EvidenceRecorder" src/app/main.tsx || true

echo
echo "=== FILES ==="
ls -lh \
  src/rf_instruments/telemetry/RFRenderGovernorBusV12.ts \
  src/rf_instruments/telemetry/RFRenderGovernorV12.tsx \
  src/rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_render_governor_v12/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V12 RENDER GOVERNOR CREATO. ORA RIAVVIA VITE."
echo "============================================================"
