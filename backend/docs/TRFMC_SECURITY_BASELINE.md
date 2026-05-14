# TRFMC Security Baseline

## Stato attuale

```text
TRFMC_OPERATIONAL_MODE=SIMULATION_ONLY
TRFMC_RESTRICTED_ENABLED=false
localhost binding
```

## Roadmap

```text
TLS reverse proxy
Private CA
mTLS
client certificates
smartcard / PKCS#11
RBAC/ABAC
immutable audit trail
data classification
retention policy
restricted interlocks
```

## v0.28 Security Baseline Upgrade

### Stato corrente

```text
environment = dev
operational_mode = SIMULATION_ONLY
restricted_enabled = false
network_binding = 127.0.0.1
backend_port = 8000
frontend_port = 5173
persistence = SQLite
```

### Regole operative immediate

```text
1. Non pubblicare 8000/5173 su interfacce esterne.
2. Non usare dati sensibili reali nel runtime di sviluppo.
3. Non caricare runtime live su repository pubblico.
4. Non committare database, vault, backup runtime o report sensibili.
5. Non abilitare restricted mode senza design dedicato.
6. Non collegare strumenti reali senza interlock di sicurezza.
```

### Baseline futura produzione/lab avanzato

```text
reverse proxy TLS
private CA
mTLS client/server
client certificate
smartcard / PKCS#11
RBAC/ABAC
least privilege
security headers
immutable audit trail
signed reports
signed backups
hash chain evidenze
retention policy
data classification
restricted area interlock
```

### Verifica locale sicurezza

```bash
sudo ss -ltnp | grep -E ':(8000|5173)\b'
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
curl -s http://127.0.0.1:8000/api/health | python3 -m json.tool
```

### Criterio di accettazione sicurezza

Una release è accettabile solo se mantiene Git pulito dopo il commit, runtime verificato, porte controllate, backup creato e rollback possibile.
