#!/usr/bin/env bash
# Usage: decide.sh baseline.csv variant.csv
# Returns "keep" or "revert" based on performance metrics
set -euo pipefail

B="$1"; V="$2"

# Calculate median (p50)
p50() { 
  awk -F, 'NR>1{print $2}' "$1" | sort -n | awk '{
    a[NR]=$1
  } END {
    if (NR%2) {
      print a[(NR+1)/2]
    } else {
      print (a[NR/2]+a[NR/2+1])/2
    }
  }'
}

# Calculate error rate (5xx responses)
err_rate() { 
  awk -F, 'NR>1{
    if ($3+0>=500) e++
  } END{ 
    if (NR>1) print (e/(NR-1))*100
    else print 0
  }' "$1"
}

BASE_P50=$(p50 "$B")
VAR_P50=$(p50 "$V")
BASE_ERR=$(err_rate "$B")
VAR_ERR=$(err_rate "$V")

# Calculate improvement percentage
IMPROVE=$(awk -v b="$BASE_P50" -v v="$VAR_P50" 'BEGIN{
  if (b > 0) print int((b - v) * 100 / b)
  else print 0
}')

ERR_DELTA=$(awk -v b="$BASE_ERR" -v v="$VAR_ERR" 'BEGIN{print v-b}')

# Thresholds from env with sane defaults
IMPROVE_PCT="${IMPROVE_PCT:-10}"
MAX_ERR_DELTA_PCT="${MAX_ERR_DELTA_PCT:-2}"

# Decision logic
if [ "$IMPROVE" -ge "$IMPROVE_PCT" ] && awk -v d="$ERR_DELTA" -v m="$MAX_ERR_DELTA_PCT" 'BEGIN{exit !(d <= m)}'; then
  echo "keep"
else
  echo "revert"
fi

# Log metrics to stderr
printf "baseline_p50_ms=%s variant_p50_ms=%s improve_pct=%s baseline_err=%.2f variant_err=%.2f err_delta=%.2f\n" \
  "$BASE_P50" "$VAR_P50" "$IMPROVE" "$BASE_ERR" "$VAR_ERR" "$ERR_DELTA" >&2

