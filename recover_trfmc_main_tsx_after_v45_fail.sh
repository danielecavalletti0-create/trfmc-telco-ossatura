#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/home/sentinel/Scaricati/trfmc_full_telco_ossatura_v0_2"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
OP="TRFMC_MAIN_TSX_RECOVERY_AFTER_V45_FAIL"
RDIR="$ROOT/runtime/releases/${OP}_${TS}"
QDIR="$ROOT/runtime/quality/${OP}_${TS}"
mkdir -p "$RDIR/candidates" "$QDIR" runtime/freezes

MAIN="frontend/src/app/main.tsx"
BROKEN_COPY="$RDIR/main.tsx.broken_${TS}"
cp "$MAIN" "$BROKEN_COPY"

echo "============================================================"
echo "$OP"
echo "Recover buildable frontend/src/app/main.tsx"
echo "============================================================"

echo
echo "=== CURRENT ERROR CONTEXT ==="
nl -ba "$MAIN" | sed -n '60,95p' | tee "$RDIR/current_main_context_60_95.txt"

echo
echo "=== COLLECT CANDIDATES FROM FILE BACKUPS ==="

find runtime frontend -type f \
  \( -name 'main.tsx.before*' -o -name 'main.tsx.*before*' -o -name 'main.tsx.backup*' \) \
  2>/dev/null | sort -r > "$RDIR/file_candidates.list" || true

i=0
while IFS= read -r f; do
  [ -s "$f" ] || continue
  i=$((i+1))
  cp "$f" "$RDIR/candidates/file_candidate_${i}.tsx"
  echo "FILE_CANDIDATE_${i}: $f"
done < "$RDIR/file_candidates.list"

echo
echo "=== COLLECT CANDIDATES FROM TAR FREEZES ==="

find runtime/freezes -maxdepth 1 -type f -name '*.tar.gz' 2>/dev/null | sort -r > "$RDIR/freezes.list" || true

j=0
while IFS= read -r tarfile; do
  [ -s "$tarfile" ] || continue

  if tar -tzf "$tarfile" 2>/dev/null | grep -qE '(^|/)frontend/src/app/main\.tsx$'; then
    j=$((j+1))
    tmp="$RDIR/tar_extract_$j"
    mkdir -p "$tmp"
    tar -xzf "$tarfile" -C "$tmp" 2>/dev/null || true

    found="$(find "$tmp" -type f -path '*/frontend/src/app/main.tsx' | head -n 1 || true)"
    if [ -n "$found" ] && [ -s "$found" ]; then
      cp "$found" "$RDIR/candidates/tar_candidate_${j}.tsx"
      echo "TAR_CANDIDATE_${j}: $tarfile"
    fi
  fi
done < "$RDIR/freezes.list"

echo
echo "=== TEST CANDIDATES WITH npm run build ==="

BEST=""
BEST_NAME=""

for candidate in "$RDIR"/candidates/*.tsx; do
  [ -s "$candidate" ] || continue

  name="$(basename "$candidate")"
  echo
  echo "--- testing $name"

  cp "$candidate" "$MAIN"

  pushd frontend >/dev/null
  if npm run build > "$RDIR/build_${name}.log" 2>&1; then
    popd >/dev/null
    BEST="$candidate"
    BEST_NAME="$name"
    echo "PASS: $name"
    break
  else
    popd >/dev/null
    echo "FAIL: $name"
    tail -n 20 "$RDIR/build_${name}.log" || true
  fi
done

RESULT="FAIL"

if [ -n "$BEST" ]; then
  cp "$BEST" "$MAIN"
  RESULT="PASS"
else
  cp "$BROKEN_COPY" "$MAIN"
fi

echo
echo "=== FINAL BUILD VERIFY ==="

FINAL_BUILD="FAIL"
if [ "$RESULT" = "PASS" ]; then
  pushd frontend >/dev/null
  if npm run build > "$RDIR/npm_build_final_recovery.log" 2>&1; then
    FINAL_BUILD="PASS"
  fi
  popd >/dev/null
fi

HTTP_TSV="$RDIR/http.tsv"
printf "url\tstatus\tbytes\n" > "$HTTP_TSV"

for url in \
  "http://127.0.0.1:5173/" \
  "http://127.0.0.1:4181/api/health"
do
  meta="$(curl -sS -o /dev/null -w "%{http_code}\t%{size_download}" --connect-timeout 2 --max-time 8 "$url" 2>/dev/null || printf "000\t0")"
  printf "%s\t%s\n" "$url" "$meta" >> "$HTTP_TSV"
done

cat > "$RDIR/main_tsx_recovery_manifest.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "broken_copy": "$BROKEN_COPY",
  "selected_candidate": "$BEST",
  "selected_candidate_name": "$BEST_NAME",
  "final_build": "$FINAL_BUILD",
  "result": "$RESULT"
}
JSON

cat > "$QDIR/summary.json" <<JSON
{
  "timestamp": "$TS",
  "operation": "$OP",
  "release_dir": "$RDIR",
  "manifest": "$RDIR/main_tsx_recovery_manifest.json",
  "broken_copy": "$BROKEN_COPY",
  "selected_candidate": "$BEST",
  "selected_candidate_name": "$BEST_NAME",
  "final_build": "$FINAL_BUILD",
  "http_tsv": "$HTTP_TSV",
  "result": "$RESULT"
}
JSON

ln -sfn "$QDIR" "$ROOT/runtime/quality/latest_main_tsx_recovery_after_v45_fail"
ln -sfn "$RDIR" "$ROOT/runtime/releases/latest_main_tsx_recovery_after_v45_fail"

echo
echo "=== SUMMARY ==="
cat "$QDIR/summary.json" | python3 -m json.tool

if [ "$RESULT" != "PASS" ] || [ "$FINAL_BUILD" != "PASS" ]; then
  echo "ERRORE: recovery non riuscita. Vedi log in $RDIR"
  exit 1
fi

echo
echo "============================================================"
echo "$OP COMPLETATO: PASS"
echo "============================================================"
