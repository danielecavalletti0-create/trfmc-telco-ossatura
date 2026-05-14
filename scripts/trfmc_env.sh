#!/usr/bin/env bash

export TRFMC_ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"

export TRFMC_BACKEND_IMAGE="trfmc-backend:v0.24"
export TRFMC_BACKEND_CONTAINER="trfmc_backend_v24"
export TRFMC_FRONTEND_CONTAINER="trfmc_frontend_v24"

export TRFMC_BACKEND_PORT="8000"
export TRFMC_FRONTEND_PORT="5173"

export TRFMC_BACKEND_URL="http://127.0.0.1:${TRFMC_BACKEND_PORT}"
export TRFMC_FRONTEND_URL="http://127.0.0.1:${TRFMC_FRONTEND_PORT}"

export TRFMC_ENV="dev"
export TRFMC_OPERATIONAL_MODE="SIMULATION_ONLY"
export TRFMC_RESTRICTED_ENABLED="false"
export TRFMC_SQLITE_PATH="/runtime/trfmc.db"
