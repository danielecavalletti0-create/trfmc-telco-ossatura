# TRFMC Architecture Current State

## Pipeline logica

```text
Scenario -> RF/Network Run -> CloudEvents -> Timeline -> Correlation Graph -> Report -> Evidence Vault -> Backup -> Restore Readiness
```

## Backend

```text
FastAPI
Uvicorn
Docker
SQLite
CloudEvents
WebSocket event stream
modular domains
```

## Frontend

```text
Vite
React
standalone console in frontend/public
```

## Runtime

```text
runtime/trfmc.db
runtime/evidence_vault/
runtime/backups/
```

## v0.28 Architecture Current State Upgrade

### Visione architetturale

TRFMC è organizzato come piattaforma modulare locale per mission control Telco/RF/Cyber.
La catena logica parte dagli asset digital twin, passa per simulazioni RF e network journey, produce eventi normalizzati, timeline, correlazione, report, evidence vault, backup e restore readiness.

### Pipeline operativa

```text
Asset Digital Twin
  -> Scenario Runner
  -> RF / Network Simulation
  -> CloudEvents
  -> Timeline
  -> Correlation Graph
  -> Report
  -> Evidence Vault
  -> Backup
  -> Restore Readiness
  -> Documentation / Operator Handbook
```

### Backend

```text
runtime = Docker container
framework = FastAPI
server = Uvicorn
language = Python
persistence = SQLite
event model = CloudEvents
transport = REST + WebSocket
```

### Domini backend principali

```text
health
persistence
rf field
rf coverage
observability
timeline
correlation
scenario runner
reports
security
portal index
vault
backup/recovery
restore readiness
docs portal
```

### Runtime networking

```text
backend  = http://127.0.0.1:8000
frontend = http://127.0.0.1:5173
docker bridge = 172.17.0.0/16
```

### Nota versioni

Le release v0.25, v0.26 e v0.27 sono frontend-only. Per questo motivo il backend può mostrare ancora 0.24.0 mentre Portal Index e Operator Handbook sono più avanzati lato frontend.
La v0.28 aggiorna i contenuti documentali e richiederà rebuild del backend per aggiornare i file serviti da /app/docs.
