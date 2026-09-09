#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
ROOT="$(pwd)"
APP="$ROOT/backend/readonly_bridge_v28/app.py"
PY="$ROOT/.venv_trfmc_backend_v28/bin/python"

QUALITY_DIR="$ROOT/runtime/quality/TRFMC_CONTRACT_COVERAGE_EXPANSION_V31_$TS"
RELEASE_DIR="$ROOT/runtime/releases/TRFMC_CONTRACT_COVERAGE_EXPANSION_V31_$TS"
FREEZE="$ROOT/runtime/freezes/TRFMC_CONTRACT_COVERAGE_EXPANSION_V31_$TS.tar.gz"

echo "============================================================"
echo "TRFMC CONTRACT COVERAGE EXPANSION V31"
echo "backend-only · P1/P2 read-only API contracts · no frontend/dist/nginx mutation"
echo "============================================================"

mkdir -p "$QUALITY_DIR" "$RELEASE_DIR" "$RELEASE_DIR/samples" "$ROOT/runtime/freezes"

echo
echo "=== PREFLIGHT ==="

test -f "$APP" || { echo "ERRORE: app.py V28 mancante"; exit 1; }
test -x "$PY" || { echo "ERRORE: venv Python mancante: $PY"; exit 1; }

test -f "$ROOT/runtime/quality/latest_backend_probe_hygiene_v30r1/summary.json" || {
  echo "ERRORE: V30R1 summary mancante"
  exit 1
}

test -f "$ROOT/runtime/quality/latest_backend_8000_guard_v29r1/summary.json" || {
  echo "ERRORE: V29R1 backend guard summary mancante"
  exit 1
}

grep -q "v30_no_curl_no_pgrep_no_self_match" "$APP" || {
  echo "ERRORE: patch V30 hygiene non presente in app.py"
  exit 1
}

systemctl --user is-active --quiet trfmc-readonly-backend-8000.service || {
  echo "ERRORE: backend 8000 non active"
  exit 1
}

systemctl --user is-active --quiet trfmc-backend-8000-guard.timer || {
  echo "ERRORE: backend guard timer non active"
  exit 1
}

curl -fsS --connect-timeout 2 --max-time 8 http://127.0.0.1:4181/api/mission/status | grep -q "TRFMC_READONLY_BACKEND_BRIDGE_V28" || {
  echo "ERRORE: proxy 4181 non sta passando al backend V28"
  exit 1
}

cp "$APP" "$RELEASE_DIR/app.py.bak_before_v31_$TS"

echo "OK: backend active, guard active, proxy reale, V30R1 presente"

echo
echo "=== PATCH APP.PY: V31 CONTRACT ROUTES ==="

"$PY" - "$APP" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
txt = p.read_text(encoding="utf-8")

MARKER = "# === TRFMC_V31_CONTRACT_COVERAGE_EXPANSION ==="

block = r'''

# === TRFMC_V31_CONTRACT_COVERAGE_EXPANSION ===
V31_CONTRACT_VERSION = "TRFMC_CONTRACT_COVERAGE_V31"


def v31_contract(endpoint: str, domain: str, capability: str, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    data = common_status()
    data.update({
        "contract_version": V31_CONTRACT_VERSION,
        "endpoint": endpoint,
        "domain": domain,
        "capability": capability,
        "contract_mode": "read-only",
        "action_executed": False,
        "tx_enabled": False,
        "mutation_enabled": False,
        "safety": {
            "read_only": True,
            "no_sdr_tx_control": True,
            "no_rf_transmission": True,
            "no_open5gs_start_stop": True,
            "no_ueransim_start_stop": True,
            "no_file_write": True,
            "no_system_mutation": True,
        },
    })
    if extra:
        data.update(extra)
    return data


@app.get("/api/rfpro/bandplan")
def api_v31_rfpro_bandplan() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bandplan",
        "rfpro",
        "bandplan_inventory",
        {
            "bands": [
                {"name": "FR1 n78", "range_mhz": [3300, 3800], "usage": "5G NR TDD lab reference", "status": "reference"},
                {"name": "ISM 2.4 GHz", "range_mhz": [2400, 2483.5], "usage": "Wi-Fi/Bluetooth/ISM reference", "status": "reference"},
                {"name": "ISM 5 GHz", "range_mhz": [5150, 5850], "usage": "Wi-Fi/ISM reference", "status": "reference"},
                {"name": "GNSS L1", "center_mhz": 1575.42, "usage": "GNSS reference", "status": "reference"},
            ],
            "note": "Reference-only bandplan for UI/API contract coverage; not a regulatory authorization table.",
        },
    )


@app.get("/api/rfpro/bridges/blueway/state")
def api_v31_rfpro_blueway_state() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/blueway/state",
        "rfpro.bridge.blueway",
        "bridge_state",
        {
            "bridge": "blueway",
            "state": "not_connected",
            "driver_loaded": False,
            "readiness": "contract_available_device_not_bound",
        },
    )


@app.get("/api/rfpro/bridges/markvii/preflight")
def api_v31_rfpro_markvii_preflight() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/markvii/preflight",
        "rfpro.bridge.markvii",
        "preflight",
        {
            "bridge": "markvii",
            "checks": [
                {"name": "device_present", "ok": False, "detail": "No live device adapter bound in V31"},
                {"name": "read_only_policy", "ok": True, "detail": "No transmit or mutation action allowed"},
            ],
            "readiness": "safe_contract_only",
        },
    )


@app.get("/api/rfpro/bridges/soapy/probe")
def api_v31_rfpro_soapy_probe() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/soapy/probe",
        "rfpro.bridge.soapy",
        "device_probe",
        {
            "bridge": "soapy",
            "devices": [],
            "readiness": "not_bound",
            "note": "V31 does not enumerate hardware through SoapySDR; contract only.",
        },
    )


@app.api_route("/api/rfpro/bridges/gnuradio/export", methods=["GET", "POST"])
def api_v31_rfpro_gnuradio_export() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/gnuradio/export",
        "rfpro.bridge.gnuradio",
        "export_contract",
        {
            "export_supported": False,
            "export_executed": False,
            "reason": "V31 is read-only; no GNU Radio file generation.",
        },
    )


@app.api_route("/api/rfpro/bridges/sdrpp/export", methods=["GET", "POST"])
def api_v31_rfpro_sdrpp_export() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/bridges/sdrpp/export",
        "rfpro.bridge.sdrpp",
        "export_contract",
        {
            "export_supported": False,
            "export_executed": False,
            "reason": "V31 is read-only; no SDR++ profile generation.",
        },
    )


@app.get("/api/rfpro/evidence/manifest")
def api_v31_rfpro_evidence_manifest() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/evidence/manifest",
        "rfpro.evidence",
        "evidence_manifest",
        {
            "evidence": {
                "quality_latest": list_recent_dirs(RUNTIME / "quality", limit=12),
                "releases_latest": list_recent_dirs(RUNTIME / "releases", limit=12),
                "freezes_latest": list_recent_dirs(RUNTIME / "freezes", limit=12),
            },
        },
    )


@app.get("/api/rfpro/file/wav/{filename:path}")
def api_v31_rfpro_wav_file(filename: str) -> dict[str, Any]:
    return v31_contract(
        f"/api/rfpro/file/wav/{filename}",
        "rfpro.file.wav",
        "file_lookup_contract",
        {
            "filename": filename,
            "available": False,
            "streaming": False,
            "reason": "No WAV artifact serving enabled in V31 contract mode.",
        },
    )


@app.api_route("/api/rfpro/iq/capture", methods=["GET", "POST"])
def api_v31_rfpro_iq_capture() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/iq/capture",
        "rfpro.iq",
        "iq_capture_contract",
        {
            "capture_supported": False,
            "capture_executed": False,
            "source_modes": ["synthetic", "file", "future_live_rx"],
            "reason": "V31 exposes contract only; no SDR capture is executed.",
        },
    )


@app.api_route("/api/rfpro/spectrum/sweep", methods=["GET", "POST"])
def api_v31_rfpro_spectrum_sweep() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/spectrum/sweep",
        "rfpro.spectrum",
        "sweep_contract",
        {
            "sweep_supported": False,
            "sweep_executed": False,
            "spectrum": {
                "center_mhz": 3640.0,
                "span_mhz": 100.0,
                "rbw_khz": 100.0,
                "source": "synthetic_contract",
            },
            "reason": "V31 does not command SDR/instrument sweep.",
        },
    )


@app.get("/api/rfpro/uav/fhss")
def api_v31_rfpro_uav_fhss() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/uav/fhss",
        "rfpro.uav",
        "fhss_analysis_contract",
        {
            "analysis_supported": True,
            "live_capture": False,
            "profile": {
                "type": "FHSS reference model",
                "hopping_detected": False,
                "source": "contract_only",
            },
        },
    )


@app.get("/api/rfpro/uav/profiles")
def api_v31_rfpro_uav_profiles() -> dict[str, Any]:
    return v31_contract(
        "/api/rfpro/uav/profiles",
        "rfpro.uav",
        "profile_catalog",
        {
            "profiles": [
                {"id": "uav-ism-24", "band": "2.4GHz ISM", "modulation": "FHSS/OFDM reference", "status": "template"},
                {"id": "uav-ism-58", "band": "5.8GHz ISM", "modulation": "OFDM/analog video reference", "status": "template"},
                {"id": "uav-lte-5g", "band": "LTE/5G modem", "modulation": "cellular reference", "status": "template"},
            ],
        },
    )


@app.get("/api/v585/ws/spectrum")
def api_v31_v585_ws_spectrum_contract() -> dict[str, Any]:
    return v31_contract(
        "/api/v585/ws/spectrum",
        "rfpro.websocket",
        "spectrum_stream_contract",
        {
            "websocket_enabled": False,
            "http_contract_available": True,
            "future_ws_path": "/ws/v585/spectrum",
            "reason": "V31 exposes HTTP contract only; live WebSocket can be promoted later.",
        },
    )


@app.get("/api/access-trust/rat/demo")
def api_v31_access_trust_rat_demo() -> dict[str, Any]:
    return v31_contract(
        "/api/access-trust/rat/demo",
        "access-trust",
        "rat_demo",
        {
            "rat": [
                {"name": "NR", "trust": "unknown", "source": "contract"},
                {"name": "LTE", "trust": "unknown", "source": "contract"},
                {"name": "Wi-Fi", "trust": "unknown", "source": "contract"},
            ],
        },
    )


@app.get("/api/access-trust/wifi/demo")
def api_v31_access_trust_wifi_demo() -> dict[str, Any]:
    return v31_contract(
        "/api/access-trust/wifi/demo",
        "access-trust",
        "wifi_demo",
        {
            "wifi": {
                "aps": [],
                "risk_score": None,
                "source": "contract_only",
            },
        },
    )


@app.get("/api/soc-noc/correlation/demo")
def api_v31_soc_noc_correlation_demo() -> dict[str, Any]:
    return v31_contract(
        "/api/soc-noc/correlation/demo",
        "soc-noc",
        "correlation_demo",
        {
            "events": [],
            "correlations": [],
            "source": "contract_only",
        },
    )
# === END TRFMC_V31_CONTRACT_COVERAGE_EXPANSION ===
'''

if MARKER in txt:
    print("OK: V31 block already present, no append needed")
else:
    txt = txt.rstrip() + "\n\n" + block + "\n"
    p.write_text(txt, encoding="utf-8")
    print("OK: V31 contract block appended")
PY

echo
echo "=== SYNTAX CHECK ==="

"$PY" -m py_compile "$APP"

echo
echo "=== RESTART BACKEND ONLY ==="

systemctl --user restart trfmc-readonly-backend-8000.service
sleep 3

systemctl --user is-active trfmc-readonly-backend-8000.service

echo
echo "=== HTTP GATE V31 ==="

HTTP_TSV="$RELEASE_DIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

probe() {
  local u="$1"
  local meta code bytes
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$u" 2>/dev/null || printf "000\t0")"
  code="${meta%%	*}"
  bytes="${meta#*	}"
  printf "%s\t%s\t%s\n" "$u" "$code" "$bytes" >> "$HTTP_TSV"
}

ENDPOINTS=(
  "/api/health"
  "/api/mission/status"
  "/api/core/open5gs/status"
  "/api/ran/ueransim/status"
  "/api/network-fabric/overview"
  "/api/rf-coverage/demo"
  "/api/rf-field/demo"
  "/api/rfpro/bandplan"
  "/api/rfpro/bridges/blueway/state"
  "/api/rfpro/bridges/markvii/preflight"
  "/api/rfpro/bridges/soapy/probe"
  "/api/rfpro/bridges/gnuradio/export"
  "/api/rfpro/bridges/sdrpp/export"
  "/api/rfpro/evidence/manifest"
  "/api/rfpro/file/wav/demo.wav"
  "/api/rfpro/iq/capture"
  "/api/rfpro/spectrum/sweep"
  "/api/rfpro/uav/fhss"
  "/api/rfpro/uav/profiles"
  "/api/v585/ws/spectrum"
  "/api/access-trust/rat/demo"
  "/api/access-trust/wifi/demo"
  "/api/soc-noc/correlation/demo"
)

for base in http://127.0.0.1:8000 http://127.0.0.1:4181
do
  for ep in "${ENDPOINTS[@]}"
  do
    probe "$base$ep"
  done
done

column -t -s $'\t' "$HTTP_TSV" | sed -n '1,140p'

echo
echo "=== SAMPLE PAYLOADS ==="

for ep in \
  /api/rfpro/bandplan \
  /api/rfpro/spectrum/sweep \
  /api/rfpro/iq/capture \
  /api/rfpro/bridges/soapy/probe \
  /api/v585/ws/spectrum \
  /api/soc-noc/correlation/demo
do
  safe="$(echo "$ep" | sed 's#/#_#g' | sed 's/^_//')"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181$ep" | python3 -m json.tool > "$RELEASE_DIR/samples/${safe}.json"
done

echo
echo "=== CONTENT CHECKS ==="

CONTENT_CHECK="$RELEASE_DIR/content_checks.txt"

get_field() {
  local ep="$1"
  local field="$2"
  local tmp="$RELEASE_DIR/check_$(echo "$ep" | sed 's#/#_#g' | sed 's/^_//').json"
  curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181$ep" > "$tmp"
  python3 - "$tmp" "$field" <<'PY'
import json, sys
path, field = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(path))
except Exception:
    print("")
    raise SystemExit(0)
print(d.get(field, ""))
PY
}

BANDPLAN_VERSION="$(get_field /api/rfpro/bandplan contract_version)"
SWEEP_VERSION="$(get_field /api/rfpro/spectrum/sweep contract_version)"
IQ_VERSION="$(get_field /api/rfpro/iq/capture contract_version)"
SOAPY_VERSION="$(get_field /api/rfpro/bridges/soapy/probe contract_version)"
WS_VERSION="$(get_field /api/v585/ws/spectrum contract_version)"
SOC_VERSION="$(get_field /api/soc-noc/correlation/demo contract_version)"

FALLBACK_COUNT=0
for ep in "${ENDPOINTS[@]}"
do
  if curl -sS --connect-timeout 2 --max-time 8 "http://127.0.0.1:4181$ep" | grep -q 'trfmc-nginx-v21-api-fallback'; then
    FALLBACK_COUNT=$((FALLBACK_COUNT + 1))
  fi
done

{
  grep -q "TRFMC_V31_CONTRACT_COVERAGE_EXPANSION" "$APP" && echo "OK: V31 block in app" || echo "MISS: V31 block in app"
  systemctl --user is-active --quiet trfmc-readonly-backend-8000.service && echo "OK: backend service active" || echo "MISS: backend service active"
  systemctl --user is-active --quiet trfmc-backend-8000-guard.timer && echo "OK: backend guard timer active" || echo "MISS: backend guard timer active"

  [ "$BANDPLAN_VERSION" = "TRFMC_CONTRACT_COVERAGE_V31" ] && echo "OK: bandplan V31 contract" || echo "MISS: bandplan V31 contract"
  [ "$SWEEP_VERSION" = "TRFMC_CONTRACT_COVERAGE_V31" ] && echo "OK: spectrum sweep V31 contract" || echo "MISS: spectrum sweep V31 contract"
  [ "$IQ_VERSION" = "TRFMC_CONTRACT_COVERAGE_V31" ] && echo "OK: iq capture V31 contract" || echo "MISS: iq capture V31 contract"
  [ "$SOAPY_VERSION" = "TRFMC_CONTRACT_COVERAGE_V31" ] && echo "OK: soapy probe V31 contract" || echo "MISS: soapy probe V31 contract"
  [ "$WS_VERSION" = "TRFMC_CONTRACT_COVERAGE_V31" ] && echo "OK: v585 ws spectrum V31 contract" || echo "MISS: v585 ws spectrum V31 contract"
  [ "$SOC_VERSION" = "TRFMC_CONTRACT_COVERAGE_V31" ] && echo "OK: soc/noc V31 contract" || echo "MISS: soc/noc V31 contract"

  [ "$FALLBACK_COUNT" -eq 0 ] && echo "OK: no V21 fallback in V31 endpoint set" || echo "MISS: V21 fallback still present"

  grep -q "RFOperationalDeckV16ChunkObservatory" "$ROOT/frontend/src/app/main.tsx" && echo "OK: V16 mount preserved" || echo "MISS: V16 mount preserved"
} > "$CONTENT_CHECK"

cat "$CONTENT_CHECK"

HTTP_NON_200="$(awk -F '\t' 'NR>1 && $2!="200"{c++} END{print c+0}' "$HTTP_TSV")"
HTTP_ZERO_BYTES="$(awk -F '\t' 'NR>1 && $3=="0"{c++} END{print c+0}' "$HTTP_TSV")"
MISS_COUNT="$(grep -c '^MISS:' "$CONTENT_CHECK" || true)"

RESULT="PASS"
if [ "$HTTP_NON_200" -ne 0 ] || [ "$MISS_COUNT" -ne 0 ]; then
  RESULT="FAIL"
elif [ "$HTTP_ZERO_BYTES" -ne 0 ]; then
  RESULT="WARN"
fi

echo
echo "=== MANIFEST ==="

MANIFEST="$RELEASE_DIR/contract_coverage_expansion_manifest_v31.json"

cat > "$MANIFEST" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_CONTRACT_COVERAGE_EXPANSION_V31",
  "backend_url": "http://127.0.0.1:8000/",
  "proxy_url": "http://127.0.0.1:4181/",
  "app": "$APP",
  "coverage_scope": [
    "rfpro bandplan",
    "rfpro bridges",
    "rfpro evidence manifest",
    "rfpro IQ capture contract",
    "rfpro spectrum sweep contract",
    "rfpro UAV profile/FHSS contract",
    "v585 HTTP spectrum stream contract",
    "access-trust demo contracts",
    "soc-noc correlation demo contract"
  ],
  "safety": {
    "read_only": true,
    "action_executed": false,
    "no_sdr_tx_control": true,
    "no_rf_transmission": true,
    "no_file_write": true,
    "no_open5gs_start_stop": true,
    "no_ueransim_start_stop": true,
    "no_frontend_mutation": true,
    "no_dist_mutation": true,
    "no_nginx_mutation": true,
    "no_systemd_mutation": true
  },
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "fallback_count": $FALLBACK_COUNT,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

cat "$MANIFEST" | python3 -m json.tool

echo
echo "=== FREEZE ==="

tar -czf "$FREEZE" \
  backend/readonly_bridge_v28/app.py \
  "$RELEASE_DIR" \
  2>/dev/null || true

SUMMARY="$QUALITY_DIR/summary.json"

cat > "$SUMMARY" <<JSON
{
  "timestamp": "$TS",
  "operation": "TRFMC_CONTRACT_COVERAGE_EXPANSION_V31",
  "release_dir": "$RELEASE_DIR",
  "manifest": "$MANIFEST",
  "freeze": "$FREEZE",
  "http_tsv": "$HTTP_TSV",
  "content_checks": "$CONTENT_CHECK",
  "http_non_200": $HTTP_NON_200,
  "http_zero_bytes": $HTTP_ZERO_BYTES,
  "fallback_count": $FALLBACK_COUNT,
  "miss_count": $MISS_COUNT,
  "result": "$RESULT"
}
JSON

ln -sfn "$QUALITY_DIR" "$ROOT/runtime/quality/latest_contract_coverage_expansion_v31"
ln -sfn "$RELEASE_DIR" "$ROOT/runtime/releases/latest_contract_coverage_expansion_v31"

echo
echo "=== SUMMARY ==="
cat "$SUMMARY" | python3 -m json.tool

echo
echo "============================================================"
echo "V31 CONTRACT COVERAGE EXPANSION COMPLETATO"
echo "Summary: runtime/quality/latest_contract_coverage_expansion_v31/summary.json"
echo "============================================================"
