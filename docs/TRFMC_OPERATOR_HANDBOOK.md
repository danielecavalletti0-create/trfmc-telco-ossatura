# TRFMC Operator Handbook

## Stato operativo

TRFMC è una piattaforma locale di mission control Telco/RF/Cyber.

```text
SIMULATION_ONLY
restricted_enabled = false
localhost-only
```

## Avvio

```bash
cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2
bash scripts/trfmc_start.sh
bash scripts/trfmc_status.sh
bash scripts/trfmc_verify.sh
```

## Spegnimento

```bash
bash scripts/trfmc_stop.sh
```

## Console principali

```text
Portal Index       http://127.0.0.1:5173/portal_index_v19.html
Restore Readiness http://127.0.0.1:5173/restore_readiness_console_v22.html
Backup Console    http://127.0.0.1:5173/operational_backup_console_v21.html
Operator Handbook http://127.0.0.1:5173/operator_handbook_console_v23.html
```

## v0.28 Operational Upgrade

### Scopo operativo esteso

TRFMC opera come piattaforma locale di mission control Telco/RF/Cyber in modalità controllata e non produttiva.
La piattaforma deve essere usata come laboratorio tecnico per simulazione, verifica, raccolta evidenze, documentazione e procedure operative.

### Regole operative v0.28

```text
1. Verificare sempre git status prima di ogni modifica.
2. Verificare sempre backend health e frontend HTTP prima di procedere.
3. Non cancellare runtime senza backup verificato.
4. Non esporre le porte 8000 e 5173 su rete esterna.
5. Dopo ogni release stabile creare commit, tag e backup progetto.
6. Per vedere i documenti aggiornati via API serve rebuild del backend Docker.
```

### Checklist prima di lavorare

```bash
cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2
git status
git branch --show-current
git tag --points-at HEAD
curl -s http://127.0.0.1:8000/api/health | python3 -m json.tool
curl -I http://127.0.0.1:5173/portal_index_v19.html
curl -I http://127.0.0.1:5173/operator_handbook_console_v23.html
```
