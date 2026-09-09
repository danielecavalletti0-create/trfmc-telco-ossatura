# TRFMC — Telco RF Mission Control Platform

**Release:** v0.2 — Full Telco Skeleton / Ossatura Enterprise

Questa release implementa l'ossatura enterprise del portale full Telco:

- Backend FastAPI con Clean Architecture / DDD
- Frontend React + Vite + TypeScript feature-based
- Event Fabric CloudEvents-ready
- ADR iniziali
- Mission Orchestrator skeleton
- Scientific RF/EM/DSP Core skeleton
- Global Network Fabric skeleton
- Telco MnS / 3GPP OAM skeleton
- Asset Registry
- Access Trust: RAT downgrade + Wi-Fi trust
- SOC/NOC correlation skeleton
- Evidence skeleton
- Restricted Intelligence compartment LOCKED

## Avvio backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

## Avvio frontend

```bash
cd frontend
npm install
npm run dev -- --host 127.0.0.1 --port 5173
```

## Verifica API

```bash
bash scripts/verify_api.sh
```

## Regole base

- Nessuna pagina scollegata.
- Nessun dato senza modello.
- Nessun evento senza CloudEvent.
- Nessuna simulazione CPU-bound nel thread HTTP.
- Nessun provisioning Open5GS via accesso diretto a MongoDB.
- Nessuna porta esposta senza ragione.
- Nessun dominio RED/EW/SIGINT operativo senza compartimentazione PKI/smartcard/audit.
