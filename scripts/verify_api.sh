#!/usr/bin/env bash
set -Eeuo pipefail

BASE="${1:-http://127.0.0.1:8000/api}"

echo "== TRFMC API VERIFY =="

for path in \
  /health \
  /mission/status \
  /events/demo \
  /scientific/plane-wave/demo \
  /scientific/near-far/demo \
  /scientific/qpsk-awgn/demo \
  /network-fabric/destinations \
  "/network-fabric/path?destination=New%20York" \
  /telco-mns/status \
  /assets/demo \
  /access-trust/rat/demo \
  /access-trust/wifi/demo \
  /soc-noc/model \
  /soc-noc/correlation/demo \
  /evidence/demo \
  /restricted/status \
  /persistence/status \
  /persistence/missions \
  /persistence/assets \
  /persistence/evidence \
  /persistence/incidents
do
  echo
  echo "--- $path"
  curl -fsS "$BASE$path" | python3 -m json.tool | head -n 80
done

echo
echo "--- POST /events/publish-demo"
curl -fsS -X POST "$BASE/events/publish-demo" | python3 -m json.tool | head -n 120

echo
echo "--- /persistence/events"
curl -fsS "$BASE/persistence/events" | python3 -m json.tool | head -n 120
