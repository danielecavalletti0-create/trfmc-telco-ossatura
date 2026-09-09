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
