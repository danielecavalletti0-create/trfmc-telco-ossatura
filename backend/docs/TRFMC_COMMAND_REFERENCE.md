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
