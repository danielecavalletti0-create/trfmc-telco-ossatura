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
