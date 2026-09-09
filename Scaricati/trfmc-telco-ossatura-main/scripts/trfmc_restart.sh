#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

bash scripts/trfmc_stop.sh
bash scripts/trfmc_start.sh
bash scripts/trfmc_status.sh
