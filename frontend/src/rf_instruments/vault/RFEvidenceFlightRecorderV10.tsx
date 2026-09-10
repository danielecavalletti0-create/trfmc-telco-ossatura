import React, { useEffect, useMemo, useState } from "react";

import { API_BASE } from "../../shared/api";

type VaultStatus = {
  service?: string;
  timestamp?: string;
  vault_root?: string;
  exists?: boolean;
  report_count?: number;
  latest_snapshot?: Record<string, any>;
  persistence?: Record<string, any>;
};

type VaultReportEntry = {
  run_id?: string;
  [key: string]: any;
};

type VaultReportsList = {
  count?: number;
  latest_run_id?: string;
  reports?: VaultReportEntry[];
};

type LoadState = "idle" | "loading" | "ok" | "error";

async function vaultGet<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { cache: "no-store" });
  if (!res.ok) throw new Error(`${path}: HTTP ${res.status}`);
  return res.json();
}

async function vaultPost<T>(path: string): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { method: "POST" });
  if (!res.ok) throw new Error(`${path}: HTTP ${res.status}`);
  return res.json();
}

export function RFEvidenceFlightRecorderV10() {
  const [status, setStatus] = useState<VaultStatus | null>(null);
  const [reports, setReports] = useState<VaultReportsList | null>(null);
  const [selected, setSelected] = useState<Record<string, any> | null>(null);
  const [loadState, setLoadState] = useState<LoadState>("idle");
  const [archiving, setArchiving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function refresh() {
    setLoadState("loading");
    setError(null);
    try {
      const [statusRes, reportsRes] = await Promise.all([
        vaultGet<VaultStatus>("/vault/status"),
        vaultGet<VaultReportsList>("/vault/reports")
      ]);
      setStatus(statusRes);
      setReports(reportsRes);
      setLoadState("ok");
    } catch (err) {
      setError(err instanceof Error ? err.message : "vault probe failed");
      setLoadState("error");
    }
  }

  useEffect(() => {
    refresh();
  }, []);

  async function archiveLatest() {
    setArchiving(true);
    setError(null);
    try {
      await vaultPost("/vault/archive/latest");
      await refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : "archive failed");
    } finally {
      setArchiving(false);
    }
  }

  async function openReport(runId: string) {
    try {
      const detail = await vaultGet<Record<string, any>>(
        `/vault/reports/${encodeURIComponent(runId)}`
      );
      setSelected(detail);
    } catch (err) {
      setError(err instanceof Error ? err.message : "report fetch failed");
    }
  }

  const statusClass = useMemo(() => {
    if (loadState === "error") return "rf-evidence-v10-bad";
    if (loadState === "ok" && status?.exists) return "rf-evidence-v10-ok";
    if (loadState === "ok") return "rf-evidence-v10-warn";
    return "";
  }, [loadState, status]);

  const reportRows = reports?.reports ?? [];

  return (
    <section className="rf-evidence-v10">
      <header className="rf-evidence-v10-header">
        <div>
          <div className="rf-evidence-v10-title">
            TRFMC Evidence Flight Recorder V10
          </div>
          <div className="rf-evidence-v10-sub">
            Read-mostly vault viewer · archivia snapshot su richiesta · nessun
            controllo SDR, nessuna mutazione core, nessuna emissione RF
          </div>
        </div>

        <div className="rf-evidence-v10-badges">
          <span>VAULT READ</span>
          <span>ARCHIVE = DB SNAPSHOT ONLY</span>
          <span>NO SDR TX</span>
          <span>NO CORE MUTATION</span>
        </div>
      </header>

      <div className="rf-evidence-v10-actions">
        <button onClick={refresh} disabled={loadState === "loading"}>
          {loadState === "loading" ? "Aggiornamento..." : "Aggiorna stato vault"}
        </button>
        <button onClick={archiveLatest} disabled={archiving}>
          {archiving ? "Archiviazione..." : "Archivia snapshot corrente"}
        </button>
      </div>

      <div className="rf-evidence-v10-grid">
        <div className="rf-evidence-v10-card">
          <b>Stato Vault</b>
          <span className={statusClass}>
            {loadState === "idle" && "—"}
            {loadState === "loading" && "..."}
            {loadState === "ok" && (status?.exists ? "PRESENTE" : "ASSENTE")}
            {loadState === "error" && "ERRORE"}
          </span>
          <small>{status?.vault_root ?? "percorso non ancora noto"}</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>Report archiviati</b>
          <span>{status?.report_count ?? reportRows.length ?? 0}</span>
          <small>Totale run registrati nel vault</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>Ultimo run</b>
          <span>{reports?.latest_run_id ?? "—"}</span>
          <small>Run ID più recente disponibile</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>Persistenza</b>
          <span>{status?.persistence ? "attiva" : "n/d"}</span>
          <small>Backend di storage del vault</small>
        </div>

        <div className="rf-evidence-v10-card">
          <b>Ultimo aggiornamento</b>
          <span>{status?.timestamp ?? "—"}</span>
          <small>Timestamp dell'ultima chiamata a /api/vault/status</small>
        </div>
      </div>

      {error && (
        <div className="rf-evidence-v10-pre">
          <span className="rf-evidence-v10-bad">Errore: {error}</span>
        </div>
      )}

      <div className="rf-evidence-v10-actions">
        {reportRows.length === 0 && loadState === "ok" && (
          <span>Nessun report ancora archiviato nel vault.</span>
        )}
        {reportRows.map((r) => (
          <button
            key={r.run_id ?? JSON.stringify(r)}
            onClick={() => r.run_id && openReport(r.run_id)}
          >
            {r.run_id ?? "run"}
          </button>
        ))}
      </div>

      {selected && (
        <pre className="rf-evidence-v10-pre">
          {JSON.stringify(selected, null, 2)}
        </pre>
      )}
    </section>
  );
}
