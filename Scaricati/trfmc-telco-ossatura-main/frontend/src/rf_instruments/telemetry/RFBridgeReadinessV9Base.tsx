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
