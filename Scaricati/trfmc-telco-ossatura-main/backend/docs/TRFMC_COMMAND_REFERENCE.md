# TRFMC Command Reference

```bash
cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2

bash scripts/trfmc_start.sh
bash scripts/trfmc_stop.sh
bash scripts/trfmc_restart.sh
bash scripts/trfmc_status.sh
bash scripts/trfmc_verify.sh
bash scripts/trfmc_backup_project.sh
bash scripts/trfmc_restore_drill.sh

curl -s http://127.0.0.1:8000/api/health | python3 -m json.tool
curl -I http://127.0.0.1:5173/portal_index_v19.html
```

## v0.28 Extended Command Reference

### Evitare il pager Git

```bash
export GIT_PAGER=cat
export PAGER=cat
git log --oneline --decorate --graph -n 20
```

### Diagnostica runtime

```bash
curl -s http://127.0.0.1:8000/api/health | python3 -m json.tool
curl -s http://127.0.0.1:8000/api/persistence/status | python3 -m json.tool
curl -s http://127.0.0.1:8000/api/portal/health-summary | python3 -m json.tool
curl -s http://127.0.0.1:8000/api/docs/index | python3 -m json.tool
```

### Test frontend

```bash
curl -I http://127.0.0.1:5173/portal_index_v19.html
curl -I http://127.0.0.1:5173/operator_handbook_console_v23.html
curl -I http://127.0.0.1:5173/restore_readiness_console_v22.html
curl -I http://127.0.0.1:5173/operational_backup_console_v21.html
```

### Recovery dopo incolla errato

```bash
cd /home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2
git status --short
git branch --show-current
curl -s http://127.0.0.1:8000/api/health | python3 -m json.tool
```
