#!/usr/bin/env bash
set -Eeuo pipefail

BASE="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
OUTDIR="$BASE/runtime/readiness"
PUBLIC="$BASE/frontend/public"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$OUTDIR/trfmc_runtime_readiness_$TS.json"
LATEST="$OUTDIR/latest_runtime_readiness.json"
PUBLIC_LATEST="$PUBLIC/trfmc_runtime_readiness_latest.json"

mkdir -p "$OUTDIR" "$BASE/runtime/evidence"/{pcap,iq,reports,logs}

exists_file(){ [ -f "$1" ] && echo true || echo false; }
exists_dir(){ [ -d "$1" ] && echo true || echo false; }
cmd_exists(){ command -v "$1" >/dev/null 2>&1 && echo true || echo false; }

find_first_dir(){
  for d in "$@"; do
    [ -d "$d" ] && { echo "$d"; return 0; }
  done
  echo ""
}

OPEN5GS_ROOT="$(find_first_dir \
  "$BASE/open5gs" \
  "$BASE/lab/open5gs" \
  "$HOME/lab/open5gs-d12-curl77/install/bin" \
  "$HOME/lab/open5gs/install/bin" \
  "/home/debian/lab/open5gs-d12-curl77/install/bin" \
  "/usr/bin" \
  "/usr/local/bin")"

UERANSIM_ROOT="$(find_first_dir \
  "$BASE/UERANSIM" \
  "$BASE/lab/UERANSIM" \
  "$HOME/lab/UERANSIM" \
  "/home/debian/lab/UERANSIM")"

cat > "$OUT" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "base": "$BASE",
  "portal": {
    "official_port": 5173,
    "health_url": "http://127.0.0.1:5173/api/health",
    "root_url": "http://127.0.0.1:5173/"
  },
  "project_scripts": {
    "start_portale_5173": $(exists_file "$BASE/start_portale_5173.sh"),
    "stop_portale_5173": $(exists_file "$BASE/stop_portale_5173.sh"),
    "status_portale_5173": $(exists_file "$BASE/status_portale_5173.sh"),
    "collaudo_portale_5173": $(exists_file "$BASE/trfmc_collaudo_portale_5173.sh"),
    "domain_registry": $(exists_file "$BASE/trfmc_create_domain_registry_v1.sh"),
    "engine_board": $(exists_file "$BASE/trfmc_create_engine_promotion_board_v1.sh")
  },
  "fiveg_scripts": {
    "bin_5g_start": $(exists_file "$BASE/bin/5g-start.sh"),
    "bin_5g_stop": $(exists_file "$BASE/bin/5g-stop.sh"),
    "bin_5g_health": $(exists_file "$BASE/bin/5g-health.sh"),
    "home_5g_start": $(exists_file "$HOME/bin/5g-start.sh"),
    "home_5g_stop": $(exists_file "$HOME/bin/5g-stop.sh"),
    "home_5g_health": $(exists_file "$HOME/bin/5g-health.sh")
  },
  "open5gs": {
    "detected_root": "$OPEN5GS_ROOT",
    "amfd": $(cmd_exists open5gs-amfd),
    "smfd": $(cmd_exists open5gs-smfd),
    "upfd": $(cmd_exists open5gs-upfd),
    "ausfd": $(cmd_exists open5gs-ausfd),
    "udmd": $(cmd_exists open5gs-udmd),
    "logs_var_log_open5gs": $(exists_dir "/var/log/open5gs"),
    "config_etc_open5gs": $(exists_dir "/etc/open5gs")
  },
  "ueransim": {
    "detected_root": "$UERANSIM_ROOT",
    "nr_gnb_in_path": $(cmd_exists nr-gnb),
    "nr_ue_in_path": $(cmd_exists nr-ue),
    "nr_cli_in_path": $(cmd_exists nr-cli),
    "config_open5gs_gnb": $(exists_file "$UERANSIM_ROOT/config/open5gs-gnb.yaml"),
    "config_open5gs_ue": $(exists_file "$UERANSIM_ROOT/config/open5gs-ue.yaml")
  },
  "hackrf": {
    "hackrf_info": $(cmd_exists hackrf_info),
    "hackrf_transfer": $(cmd_exists hackrf_transfer),
    "hackrf_sweep": $(cmd_exists hackrf_sweep),
    "soapy_sdr_util": $(cmd_exists SoapySDRUtil)
  },
  "evidence_storage": {
    "runtime_evidence": $(exists_dir "$BASE/runtime/evidence"),
    "pcap": $(exists_dir "$BASE/runtime/evidence/pcap"),
    "iq": $(exists_dir "$BASE/runtime/evidence/iq"),
    "reports": $(exists_dir "$BASE/runtime/evidence/reports"),
    "logs": $(exists_dir "$BASE/runtime/evidence/logs"),
    "backups": $(exists_dir "$BASE/runtime/backups")
  },
  "quality": {
    "runtime_size": "$(du -sh "$BASE/runtime" 2>/dev/null | awk '{print $1}')",
    "disk_free": "$(df -h "$BASE" | awk 'NR==2 {print $4}')",
    "latest_collaudo_dir": "$(find "$BASE/runtime/collaudo" -maxdepth 1 -type d -name 'TRFMC_COLLAUDO_5173_*' 2>/dev/null | sort | tail -n 1)",
    "latest_freeze": "$(find "$BASE/runtime/freezes" -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | sort | tail -n 1)"
  }
}
JSON

python3 -m json.tool "$OUT" > /dev/null

cp -f "$OUT" "$LATEST"
cp -f "$OUT" "$PUBLIC_LATEST"

echo "$OUT"
