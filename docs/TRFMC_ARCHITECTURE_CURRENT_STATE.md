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
