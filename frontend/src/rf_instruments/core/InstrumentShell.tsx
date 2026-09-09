import React, { memo } from "react";
import "../styles/instrument.css";

type InstrumentShellProps = {
  title: string;
  subtitle?: string;
  left?: React.ReactNode;
  center?: React.ReactNode;
  right?: React.ReactNode;
};

const InstrumentShellComponent = ({ title, subtitle, left, center, right }: InstrumentShellProps) => {
  return (
    <section className="trfmc-instrument-shell">
      <header className="trfmc-instrument-header">
        <div>
          <h1>{title}</h1>
          {subtitle && <p>{subtitle}</p>}
        </div>
      </header>

      <main className="trfmc-instrument-grid">
        <aside className="trfmc-instrument-panel">{left}</aside>
        <section className="trfmc-instrument-panel trfmc-instrument-main">{center}</section>
        <aside className="trfmc-instrument-panel">{right}</aside>
      </main>
    </section>
  );
};

export const InstrumentShell = memo(InstrumentShellComponent);
