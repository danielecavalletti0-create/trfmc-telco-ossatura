# Security Baseline

## Default

- Backend dev bind: `127.0.0.1:8000`
- Frontend dev bind: `127.0.0.1:5173`
- Restricted Intelligence: `LOCKED`
- Real RF emission: `DISABLED`
- Open5GS provisioning: API-only / no direct MongoDB manipulation

## Porte iniziali

| Porta | Servizio | Binding | Motivazione |
|---:|---|---|---|
| 8000 | FastAPI | 127.0.0.1 | API sviluppo |
| 5173 | Vite | 127.0.0.1 | Frontend sviluppo |
| 5432 | PostgreSQL opzionale | internal | DB app |
| 9092 | Redpanda/Kafka opzionale | internal | event bus |

## Controlli futuri obbligatori

- Keycloak OIDC
- RBAC/ABAC
- mTLS
- PKI interna
- smartcard/token hardware per restricted
- SAST
- secret scanning
- SBOM
- dependency scanning
- immutable audit
