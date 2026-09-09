# TRFMC Backup and Restore

## Backup progetto

```bash
bash scripts/trfmc_backup_project.sh
```

## Backup runtime

```text
http://127.0.0.1:5173/operational_backup_console_v21.html
```

## Restore readiness

```text
http://127.0.0.1:5173/restore_readiness_console_v22.html
```

## Drill non distruttivo

```bash
bash scripts/trfmc_restore_drill.sh
```

Il drill non modifica il runtime live.

## v0.28 Backup and Restore Operational Upgrade

### Obiettivo

La catena di backup e restore deve garantire recuperabilità del progetto dopo errore umano, patch fallita, container non avviabile, perdita file frontend o migrazione verso altra macchina.

### Tipologie di backup

```text
1. Backup progetto: sorgenti, backend, frontend, script, documentazione.
2. Backup runtime: database SQLite, evidence vault, backup runtime.
3. Backup locali temporanei: copie HTML/docs fuori repository.
```

### Comandi di verifica backup

```bash
ls -lh /home/sentinel/Scaricati/trfmc_full_project_backup_v*.tar.gz | tail -n 10
ls -lh /home/sentinel/Scaricati/trfmc_full_project_backup_v*_manifest.txt | tail -n 10
sha256sum /home/sentinel/Scaricati/trfmc_full_project_backup_vXX_YYYYMMDD_HHMMSS.tar.gz
```

### Restore readiness API

```bash
curl -s http://127.0.0.1:8000/api/restore/readiness | python3 -m json.tool
curl -s http://127.0.0.1:8000/api/restore/plan | python3 -m json.tool
curl -s http://127.0.0.1:8000/api/restore/verify-backup | python3 -m json.tool
curl -s http://127.0.0.1:8000/api/restore/drill | python3 -m json.tool
```

### Procedura cold restore concettuale

```text
1. Fermare TRFMC.
2. Copiare backup progetto su macchina target.
3. Verificare hash SHA256.
4. Estrarre archivio in directory pulita.
5. Avviare backend/frontend.
6. Verificare health API.
7. Verificare frontend.
8. Verificare docs API.
9. Eseguire verify completo.
```

### Segnali di attenzione

```text
git status non pulito senza motivo chiaro
backup senza manifest
manifest senza SHA256
frontend HTTP 000
backend HTTP 000
container in conflitto con stesso nome
porte 8000/5173 occupate da processo non TRFMC
```
