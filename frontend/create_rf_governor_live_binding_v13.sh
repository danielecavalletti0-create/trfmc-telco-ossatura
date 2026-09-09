#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
QUALITY_DIR="../runtime/quality/TRFMC_RF_GOVERNOR_LIVE_BINDING_V13_${TS}"
FREEZE="../runtime/freezes/TRFMC_BEFORE_RF_GOVERNOR_LIVE_BINDING_V13_${TS}.tar.gz"

echo "============================================================"
echo "TRFMC RF GOVERNOR LIVE BINDING V13"
echo "V12 policy bus -> VSA Dock rendering throttle / waterfall / IQ budget"
echo "============================================================"

mkdir -p ../runtime/freezes "$QUALITY_DIR"
mkdir -p src/rf_instruments/telemetry

echo
echo "=== PREFLIGHT ==="

test -f src/app/main.tsx || { echo "ERRORE: src/app/main.tsx mancante"; exit 1; }
test -f src/styles.css || { echo "ERRORE: src/styles.css mancante"; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor.tsx || { echo "ERRORE: V12 mancante. Prima completare V12."; exit 1; }
test -f src/rf_instruments/instruments/RFInstrumentDockV4.tsx || { echo "ERRORE: RFInstrumentDockV4.tsx mancante"; exit 1; }
test -f src/rf_instruments/telemetry/RFRenderGovernorBusV12.ts || { echo "ERRORE: RFRenderGovernorBusV12.ts mancante"; exit 1; }

grep -q "RFInstrumentSuiteV12RenderGovernor" src/app/main.tsx || {
  echo "ERRORE: main.tsx non monta V12 Render Governor. Non procedo."
  exit 1
}

echo "OK: V12 presente e montato"

echo
echo "=== BACKUP STATO V12 ==="

tar -czf "$FREEZE" \
  index.html \
  src/app/main.tsx \
  src/styles.css \
  src/rf_instruments \
  2>/dev/null || true

cp src/app/main.tsx "src/app/main.tsx.bak_rf_governor_binding_v13_${TS}"
cp src/styles.css "src/styles.css.bak_rf_governor_binding_v13_${TS}"
cp src/rf_instruments/instruments/RFInstrumentDockV4.tsx "src/rf_instruments/instruments/RFInstrumentDockV4.tsx.bak_rf_governor_binding_v13_${TS}"

echo "Freeze pre-patch: $FREEZE"

echo
echo "=== APPENDO CSS V13 ==="

if ! grep -q "TRFMC_RF_GOVERNOR_LIVE_BINDING_V13_STYLE" src/styles.css; then
cat >> src/styles.css <<'CSS'

/* TRFMC_RF_GOVERNOR_LIVE_BINDING_V13_STYLE */
.rf-binding-v13{
  margin-bottom:12px;
  border:1px solid rgba(255,209,102,.34);
  border-radius:24px;
  overflow:hidden;
  background:
    radial-gradient(circle at 84% 0%,rgba(255,209,102,.14),transparent 34%),
    radial-gradient(circle at 12% 100%,rgba(125,255,178,.08),transparent 30%),
    linear-gradient(145deg,rgba(28,22,6,.96),rgba(0,4,9,.99));
  box-shadow:
    0 26px 95px rgba(0,0,0,.66),
    inset 0 0 48px rgba(255,209,102,.035);
}

.rf-binding-v13-header{
  display:grid;
  grid-template-columns:minmax(0,1fr) auto;
  gap:14px;
  padding:14px;
  border-bottom:1px solid rgba(255,209,102,.22);
  background:linear-gradient(180deg,rgba(42,32,8,.96),rgba(2,9,16,.98));
}

.rf-binding-v13-title{
  color:#fff8df;
  font-size:17px;
  font-weight:950;
  text-transform:uppercase;
  letter-spacing:.12em;
  text-shadow:0 0 18px rgba(255,209,102,.45);
}

.rf-binding-v13-sub{
  margin-top:5px;
  color:#c9b987;
  font-size:11px;
}

.rf-binding-v13-badges{
  display:flex;
  flex-wrap:wrap;
  gap:7px;
  justify-content:flex-end;
  align-content:start;
}

.rf-binding-v13-badges span{
  border:1px solid rgba(255,209,102,.28);
  background:rgba(255,209,102,.07);
  color:#ffd166;
  border-radius:999px;
  padding:6px 9px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:10px;
}

.rf-binding-v13-grid{
  padding:10px;
  display:grid;
  grid-template-columns:repeat(6,minmax(145px,1fr));
  gap:10px;
}

.rf-binding-v13-card{
  border:1px solid rgba(255,209,102,.22);
  border-radius:18px;
  padding:12px;
  background:
    linear-gradient(145deg,rgba(28,23,9,.90),rgba(1,5,11,.98)),
    radial-gradient(circle at 100% 0%,rgba(255,209,102,.08),transparent 35%);
}

.rf-binding-v13-card b{
  display:block;
  color:#ffd166;
  font-size:11px;
  text-transform:uppercase;
  letter-spacing:.10em;
  margin-bottom:7px;
}

.rf-binding-v13-card span{
  display:block;
  color:#eafbff;
  font-family:ui-monospace,Consolas,monospace;
  font-size:15px;
  font-weight:850;
}

.rf-binding-v13-card small{
  display:block;
  color:#c9b987;
  margin-top:6px;
  line-height:1.45;
  word-break:break-all;
}

.rf-binding-v13-pre{
  margin:0 10px 10px;
  border:1px solid rgba(255,209,102,.18);
  border-radius:16px;
  background:#02060c;
  color:#eafbff;
  padding:10px;
  font-family:ui-monospace,Consolas,monospace;
  font-size:11px;
  max-height:170px;
  overflow:auto;
}

.rf-binding-ultra{ color:#7dffb2; }
.rf-binding-high{ color:#39d7ff; }
.rf-binding-balanced{ color:#ffd166; }
.rf-binding-safe{ color:#ff9f6e; }
.rf-binding-background{ color:#ff5f7a; }

@media(max-width:1500px){
  .rf-binding-v13-grid{ grid-template-columns:repeat(3,minmax(145px,1fr)); }
  .rf-binding-v13-header{ grid-template-columns:1fr; }
  .rf-binding-v13-badges{ justify-content:flex-start; }
}

@media(max-width:760px){
  .rf-binding-v13-grid{ grid-template-columns:1fr; }
}
CSS
fi

echo
echo "=== CREO GOVERNOR BINDING AUDIT V13 ==="

cat > src/rf_instruments/telemetry/RFGovernorBindingAuditV13.tsx <<'TSX'
import React, { useEffect, useMemo, useState } from "react";

import {
  readRFRenderGovernorPolicyV12,
  RF_RENDER_GOVERNOR_EVENT_V12,
  RFRenderGovernorPolicyV12
} from "./RFRenderGovernorBusV12";

function cls(profile?: string) {
  if (profile === "ULTRA") return "rf-binding-ultra";
  if (profile === "HIGH") return "rf-binding-high";
  if (profile === "BALANCED") return "rf-binding-balanced";
  if (profile === "SAFE") return "rf-binding-safe";
  if (profile === "BACKGROUND") return "rf-binding-background";
  return "";
}

export function RFGovernorBindingAuditV13() {
  const [policy, setPolicy] = useState<RFRenderGovernorPolicyV12 | null>(() => readRFRenderGovernorPolicyV12());
  const [events, setEvents] = useState(0);
  const [lastEventAt, setLastEventAt] = useState("—");

  useEffect(() => {
    const handler = (ev: Event) => {
      const custom = ev as CustomEvent<RFRenderGovernorPolicyV12>;

      if (!custom.detail) return;

      setPolicy(custom.detail);
      setEvents((old) => old + 1);
      setLastEventAt(new Date().toLocaleTimeString());
    };

    window.addEventListener(RF_RENDER_GOVERNOR_EVENT_V12, handler);

    const timer = window.setInterval(() => {
      const stored = readRFRenderGovernorPolicyV12();
      if (stored) setPolicy(stored);
    }, 1000);

    return () => {
      window.removeEventListener(RF_RENDER_GOVERNOR_EVENT_V12, handler);
      window.clearInterval(timer);
    };
  }, []);

  const cards = useMemo(
    () => [
      {
        label: "Binding",
        value: policy ? "LIVE" : "WAIT",
        detail: policy ? "V12 policy visible to V13 consumers" : "Waiting V12 policy bus"
      },
      {
        label: "Profile",
        value: policy?.profile ?? "—",
        detail: policy?.reason ?? "No policy yet",
        className: cls(policy?.profile)
      },
      {
        label: "FPS Target",
        value: policy ? String(policy.fpsTarget) : "—",
        detail: "Dock V4 throttle target"
      },
      {
        label: "Waterfall",
        value: policy ? `1/${policy.waterfallEveryNFrames}` : "—",
        detail: "Waterfall update cadence"
      },
      {
        label: "IQ Budget",
        value: policy ? String(policy.iqPointBudget) : "—",
        detail: "Constellation point cap"
      },
      {
        label: "Events",
        value: String(events),
        detail: `Last ${lastEventAt}`
      }
    ],
    [policy, events, lastEventAt]
  );

  return (
    <section className="rf-binding-v13">
      <header className="rf-binding-v13-header">
        <div>
          <div className="rf-binding-v13-title">TRFMC RF Governor Live Binding V13</div>
          <div className="rf-binding-v13-sub">
            V12 policy bus consumed by VSA Dock V4 · render throttle · waterfall cadence · I/Q point budget
          </div>
        </div>

        <div className="rf-binding-v13-badges">
          <span>CUSTOM EVENT BUS</span>
          <span>LOCAL STORAGE POLICY</span>
          <span>VSA DOCK CONSUMER</span>
          <span>NO BACKEND MUTATION</span>
        </div>
      </header>

      <div className="rf-binding-v13-grid">
        {cards.map((card) => (
          <div className="rf-binding-v13-card" key={card.label}>
            <b>{card.label}</b>
            <span className={card.className ?? ""}>{card.value}</span>
            <small>{card.detail}</small>
          </div>
        ))}
      </div>

      <pre className="rf-binding-v13-pre">
        {JSON.stringify(
          {
            event: RF_RENDER_GOVERNOR_EVENT_V12,
            policy,
            consumer: "RFInstrumentDockV4",
            appliedControls: [
              "draw-loop fpsTarget throttle",
              "animationEnabled background skip",
              "waterfallEveryNFrames",
              "iqPointBudget"
            ]
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
echo "=== PATCH RFInstrumentDockV4.tsx PER CONSUMARE GOVERNOR V12 ==="

python3 - <<'PY'
from pathlib import Path

p = Path("src/rf_instruments/instruments/RFInstrumentDockV4.tsx")
s = p.read_text()

if "RF_RENDER_GOVERNOR_EVENT_V12" not in s:
    s = s.replace(
        'import { IQConstellationRenderer, IQPoint } from "../renderers/IQConstellationRenderer";\n',
        'import { IQConstellationRenderer, IQPoint } from "../renderers/IQConstellationRenderer";\n'
        'import {\n'
        '  readRFRenderGovernorPolicyV12,\n'
        '  RF_RENDER_GOVERNOR_EVENT_V12,\n'
        '  RFRenderGovernorPolicyV12\n'
        '} from "../telemetry/RFRenderGovernorBusV12";\n',
        1
    )

if "const defaultGovernorPolicyV13" not in s:
    insert_after = '''const initialMetrics: Metrics = {
  snr: 0,
  evm: 0,
  mer: 0,
  obw: 0,
  aclrLow: 0,
  aclrHigh: 0,
  channelPower: 0,
  noiseFloor: 0,
  crestFactor: 0,
  classifier: "BOOT",
  evidence: "waiting worker"
};
'''
    default_policy = '''
const defaultGovernorPolicyV13: RFRenderGovernorPolicyV12 = {
  profile: "ULTRA",
  fpsTarget: 60,
  canvasScale: 1,
  waterfallEveryNFrames: 1,
  iqPointBudget: 800,
  spectrumBins: 4096,
  animationEnabled: true,
  reason: "default local policy",
  timestamp: new Date().toISOString()
};
'''
    s = s.replace(insert_after, insert_after + default_policy, 1)

if "const [governorProfile" not in s:
    s = s.replace(
        '  const [frameNo, setFrameNo] = useState(0);\n',
        '  const [frameNo, setFrameNo] = useState(0);\n'
        '  const [governorProfile, setGovernorProfile] = useState(defaultGovernorPolicyV13.profile);\n',
        1
    )

if "const governorPolicyRef" not in s:
    s = s.replace(
        '  const rafRef = useRef<number | null>(null);\n',
        '  const rafRef = useRef<number | null>(null);\n'
        '  const governorPolicyRef = useRef<RFRenderGovernorPolicyV12>(readRFRenderGovernorPolicyV12() ?? defaultGovernorPolicyV13);\n'
        '  const lastDrawAtRef = useRef(0);\n',
        1
    )

if "RF_RENDER_GOVERNOR_EVENT_V12, handler" not in s:
    marker = '''  useEffect(() => {
    const worker = new Worker(
'''
    listener = '''  useEffect(() => {
    const stored = readRFRenderGovernorPolicyV12();
    if (stored) {
      governorPolicyRef.current = stored;
      setGovernorProfile(stored.profile);
    }

    const handler = (ev: Event) => {
      const custom = ev as CustomEvent<RFRenderGovernorPolicyV12>;
      if (!custom.detail) return;

      governorPolicyRef.current = custom.detail;
      setGovernorProfile(custom.detail.profile);
    };

    window.addEventListener(RF_RENDER_GOVERNOR_EVENT_V12, handler);
    return () => window.removeEventListener(RF_RENDER_GOVERNOR_EVENT_V12, handler);
  }, []);

'''
    s = s.replace(marker, listener + marker, 1)

if "GOV {governorProfile}" not in s:
    s = s.replace(
        '          <span className="rf-dock-v4-pill">V3 SAFE / V4 DOCK</span>\n',
        '          <span className="rf-dock-v4-pill">V3 SAFE / V4 DOCK</span>\n'
        '          <span className="rf-dock-v4-pill">GOV {governorProfile}</span>\n',
        1
    )

old_loop = '''    const drawLoop = () => {
      const frame = lastFrame.current;

      if (frame) {
        const spec = spectrumCanvas.current;
        const wf = waterfallCanvas.current;
        const iqc = iqCanvas.current;

        if (spec) {
          surface.current.draw(
            spec,
            {
              primary: frame.primary,
              maxHold: frame.maxHold,
              average: frame.average
            },
            frame.markers
          );
        }

        if (wf) {
          waterfall.current.push(frame.primary);
          waterfall.current.draw(wf);
        }

        if (iqc) {
          iq.current.draw(iqc, frame.iq);
        }
      }

      rafRef.current = requestAnimationFrame(drawLoop);
    };
'''

new_loop = '''    const drawLoop = () => {
      const frame = lastFrame.current;
      const policy = governorPolicyRef.current;

      if (!policy.animationEnabled) {
        rafRef.current = requestAnimationFrame(drawLoop);
        return;
      }

      const now = performance.now();
      const minDelta = 1000 / Math.max(1, policy.fpsTarget);

      if (now - lastDrawAtRef.current < minDelta) {
        rafRef.current = requestAnimationFrame(drawLoop);
        return;
      }

      lastDrawAtRef.current = now;

      if (frame) {
        const spec = spectrumCanvas.current;
        const wf = waterfallCanvas.current;
        const iqc = iqCanvas.current;

        if (spec) {
          surface.current.draw(
            spec,
            {
              primary: frame.primary,
              maxHold: frame.maxHold,
              average: frame.average
            },
            frame.markers
          );
        }

        if (wf && frame.frame % Math.max(1, policy.waterfallEveryNFrames) === 0) {
          waterfall.current.push(frame.primary);
          waterfall.current.draw(wf);
        }

        if (iqc) {
          iq.current.draw(iqc, frame.iq.slice(0, policy.iqPointBudget));
        }
      }

      rafRef.current = requestAnimationFrame(drawLoop);
    };
'''

if old_loop in s:
    s = s.replace(old_loop, new_loop, 1)
else:
    print("WARN: drawLoop block non trovato esattamente; patch parziale")

p.write_text(s)
print("OK: RFInstrumentDockV4 patched for V13 governor binding")
PY

echo
echo "=== CREO WRAPPER V13 ==="

cat > src/rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding.tsx <<'TSX'
import React from "react";

import { RFInstrumentSuiteV12RenderGovernor } from "./RFInstrumentSuiteV12RenderGovernor";
import { RFGovernorBindingAuditV13 } from "../telemetry/RFGovernorBindingAuditV13";

export function RFInstrumentSuiteV13GovernorBinding() {
  return (
    <section>
      <RFGovernorBindingAuditV13 />
      <RFInstrumentSuiteV12RenderGovernor />
    </section>
  );
}
TSX

echo
echo "=== PATCH main.tsx: V12 -> V13 ==="

python3 - <<'PY'
from pathlib import Path
import re

p = Path("src/app/main.tsx")
s = p.read_text()

s = re.sub(
    r"import\s+\{\s*RFInstrumentSuiteV12RenderGovernor\s*\}\s+from\s+['\"]\.\./rf_instruments/instruments/RFInstrumentSuiteV12RenderGovernor['\"];?\n",
    "import { RFInstrumentSuiteV13GovernorBinding } from '../rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding'\n",
    s,
    count=1
)

if "RFInstrumentSuiteV13GovernorBinding" not in s:
    lines = s.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.lstrip().startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import { RFInstrumentSuiteV13GovernorBinding } from '../rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding'\n")
    s = "".join(lines)

s = s.replace("<RFInstrumentSuiteV12RenderGovernor />", "<RFInstrumentSuiteV13GovernorBinding />")

p.write_text(s)
print("OK: main.tsx patched to V13 Governor Binding")
PY

echo
echo "=== CREO ROLLBACK SCRIPT ==="

cat > "$QUALITY_DIR/rollback_v13_governor_binding.sh" <<ROLLBACK
#!/usr/bin/env bash
set -Eeuo pipefail
cd "$ROOT"
cp "src/app/main.tsx.bak_rf_governor_binding_v13_${TS}" src/app/main.tsx
cp "src/styles.css.bak_rf_governor_binding_v13_${TS}" src/styles.css
cp "src/rf_instruments/instruments/RFInstrumentDockV4.tsx.bak_rf_governor_binding_v13_${TS}" src/rf_instruments/instruments/RFInstrumentDockV4.tsx
echo "Rollback V13 Governor Live Binding completato."
ROLLBACK

chmod +x "$QUALITY_DIR/rollback_v13_governor_binding.sh"

echo
echo "=== QUALITY SUMMARY ==="

cat > "$QUALITY_DIR/summary.json" <<JSON
{
  "timestamp": "${TS}",
  "operation": "TRFMC_RF_GOVERNOR_LIVE_BINDING_V13",
  "created": [
    "src/rf_instruments/telemetry/RFGovernorBindingAuditV13.tsx",
    "src/rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding.tsx"
  ],
  "patched": [
    "src/app/main.tsx",
    "src/styles.css",
    "src/rf_instruments/instruments/RFInstrumentDockV4.tsx"
  ],
  "bindings": [
    "fpsTarget draw-loop throttle",
    "animationEnabled background skip",
    "waterfallEveryNFrames cadence",
    "iqPointBudget constellation cap",
    "governor profile badge in VSA Dock"
  ],
  "preserves_v12_render_governor": true,
  "rollback": "${QUALITY_DIR}/rollback_v13_governor_binding.sh",
  "result": "READY_FOR_VITE_TEST"
}
JSON

ln -sfn "$(pwd)/$QUALITY_DIR" ../runtime/quality/latest_rf_governor_live_binding_v13

echo
echo "=== VERIFICA PATCH ==="
grep -n "RFInstrumentSuiteV13GovernorBinding\\|RFInstrumentSuiteV12RenderGovernor\\|RFInstrumentSuiteV11PerformanceTelemetry" src/app/main.tsx || true

echo
echo "=== VERIFICA DOCK BINDING ==="
grep -n "RF_RENDER_GOVERNOR_EVENT_V12\\|governorProfile\\|iqPointBudget\\|waterfallEveryNFrames\\|fpsTarget" src/rf_instruments/instruments/RFInstrumentDockV4.tsx || true

echo
echo "=== FILES ==="
ls -lh \
  src/rf_instruments/telemetry/RFGovernorBindingAuditV13.tsx \
  src/rf_instruments/instruments/RFInstrumentSuiteV13GovernorBinding.tsx

echo
echo "=== SUMMARY ==="
cat ../runtime/quality/latest_rf_governor_live_binding_v13/summary.json | python3 -m json.tool

echo
echo "============================================================"
echo "V13 GOVERNOR LIVE BINDING CREATO. ORA RIAVVIA VITE."
echo "============================================================"
