#!/usr/bin/env bash
# Measure performance metrics for an experiment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META="${SCRIPT_DIR}/meta.json"

if [ ! -f "$META" ]; then
  echo "Error: meta.json not found" >&2
  exit 1
fi

URL=$(jq -r '.target_url' "$META")
INTERVAL=$(jq -r '.measure_interval_sec' "$META")
DURATION="${1:-60}"   # duration in seconds
OUT="${2:-/dev/stdout}"

END_TS=$(( $(date +%s) + DURATION ))

echo "Measuring $URL for ${DURATION}s, interval ${INTERVAL}s"
echo "ts,latency_ms,rcode" > "$OUT"

while [ "$(date +%s)" -lt "$END_TS" ]; do
  START=$(date +%s%3N)
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo 000)
  END=$(date +%s%3N)
  LAT=$((END-START))
  echo "$(date -Iseconds),$LAT,$CODE" >> "$OUT"
  sleep "$INTERVAL"
done

echo "Measurement complete. $(wc -l < "$OUT") data points collected."

