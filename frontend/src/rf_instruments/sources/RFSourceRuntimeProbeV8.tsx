import React, { useEffect, useMemo, useRef, useState } from "react";

import { SyntheticRFSourceAdapter } from "./SyntheticRFSourceAdapter";
import type { RFBridgeFrameMeta } from "./RFSourceTypes";

type ProbeState = {
  status: string;
  frames: number;
  drops: number;
  lastFrameAt: string;
  lastBytes: number;
  lastMeta: string;
};

const initialState: ProbeState = {
  status: "BOOT",
  frames: 0,
  drops: 0,
  lastFrameAt: "—",
  lastBytes: 0,
  lastMeta: "waiting synthetic adapter"
};

export function RFSourceRuntimeProbeV8() {
  const adapterRef = useRef<SyntheticRFSourceAdapter | null>(null);
  const [state, setState] = useState<ProbeState>(initialState);
  const [log, setLog] = useState<string[]>([]);

  useEffect(() => {
    const adapter = new SyntheticRFSourceAdapter();
    adapterRef.current = adapter;

    adapter.onFrame((payload, meta: RFBridgeFrameMeta) => {
      const health = adapter.getHealth();

      const bytes =
        payload instanceof Float32Array
          ? payload.byteLength
          : payload instanceof ArrayBuffer
            ? payload.byteLength
            : 0;

      setState({
        status: health.status,
        frames: health.frames,
        drops: health.drops,
        lastFrameAt: new Date(meta.timestamp).toLocaleTimeString(),
        lastBytes: bytes,
        lastMeta: `${meta.source} seq=${meta.sequence} ${meta.format ?? ""}`
      });

      if (meta.sequence % 10 === 0) {
        setLog((old) => [
          `[${new Date(meta.timestamp).toLocaleTimeString()}] source=${meta.source} seq=${meta.sequence} bytes=${bytes} format=${meta.format ?? "n/a"}`,
          ...old
        ].slice(0, 8));
      }
    });

    adapter.connect();

    setLog((old) => [
      "[BOOT] SyntheticRFSourceAdapter connected in safe runtime probe mode.",
      ...old
    ]);

    return () => {
      adapter.disconnect();
      adapterRef.current = null;
    };
  }, []);

  const cards = useMemo(
    () => [
      {
        label: "Source",
        value: "Synthetic",
        detail: "Runtime adapter reale, nessuna sorgente live esterna."
      },
      {
        label: "Status",
        value: state.status,
        detail: "Health ottenuto da SyntheticRFSourceAdapter."
      },
      {
        label: "Frames",
        value: String(state.frames),
        detail: `Drops ${state.drops} · last ${state.lastFrameAt}`
      },
      {
        label: "Payload",
        value: `${state.lastBytes} B`,
        detail: state.lastMeta
      }
    ],
    [state]
  );

  return (
    <section className="rf-runtime-v8">
      <header className="rf-runtime-v8-header">
        <div>
          <div className="rf-runtime-v8-title">TRFMC RF Source Runtime V8 Probe</div>
          <div className="rf-runtime-v8-sub">
            Safe runtime verification · synthetic adapter active · future binary IQ/WebSocket/SDR rails preserved
          </div>
        </div>

        <div className="rf-runtime-v8-badges">
          <span>RUNTIME PROBE ACTIVE</span>
          <span>NO SDR AUTO-CONNECT</span>
          <span>NO OPEN5GS MUTATION</span>
          <span>SOURCE CONTRACT READY</span>
        </div>
      </header>

      <div className="rf-runtime-v8-grid">
        {cards.map((card) => (
          <div className="rf-runtime-v8-card" key={card.label}>
            <b>{card.label}</b>
            <span>{card.value}</span>
            <small>{card.detail}</small>
          </div>
        ))}
      </div>

      <pre className="rf-runtime-v8-log">
        {log.length ? log.join("\n") : "waiting frames..."}
      </pre>
    </section>
  );
}
