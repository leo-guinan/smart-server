#!/usr/bin/env bash
# Main experiment orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source config
. "${BASE_DIR}/smart.conf"

# Allow override of experiment directory
EXP_DIR="${1:-${BASE_DIR}/experiments/001_nginx_workers}"

if [ ! -d "$EXP_DIR" ]; then
  echo "Error: Experiment directory not found: $EXP_DIR" >&2
  exit 1
fi

RUN_ID=$(date +%Y%m%dT%H%M%S)
WORK_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$WORK_DIR"

META="$EXP_DIR/meta.json"

if [ ! -f "$META" ]; then
  echo "Error: meta.json not found in $EXP_DIR" >&2
  exit 1
fi

DUR_BASE="$BASELINE_SECONDS"
DUR_VAR="$EXPERIMENT_SECONDS"

echo "================================" | tee -a "$WORK_DIR/run.log"
echo "Smart Server Experiment Run: $RUN_ID" | tee -a "$WORK_DIR/run.log"
echo "Experiment: $(basename "$EXP_DIR")" | tee -a "$WORK_DIR/run.log"
echo "================================" | tee -a "$WORK_DIR/run.log"

# 1) Run baseline
echo ">> Running baseline measurement (${DUR_BASE}s)..." | tee -a "$WORK_DIR/run.log"
bash "$EXP_DIR/apply.sh" baseline 2>&1 | tee -a "$WORK_DIR/run.log"
bash "$EXP_DIR/measure.sh" "$DUR_BASE" "$WORK_DIR/baseline.csv" 2>&1 | tee -a "$WORK_DIR/run.log"

KEPT="none"

# 2) Iterate through variants
jq -r '.variants[] | select(.name!="baseline") .name' "$META" | while read -r VAR; do
  echo "" | tee -a "$WORK_DIR/run.log"
  echo ">> Testing variant: $VAR" | tee -a "$WORK_DIR/run.log"
  
  bash "$EXP_DIR/apply.sh" "$VAR" 2>&1 | tee -a "$WORK_DIR/run.log"
  
  echo ">> Cooldown (${COOLDOWN_SECONDS}s)..." | tee -a "$WORK_DIR/run.log"
  sleep "$COOLDOWN_SECONDS"
  
  VAR_FILE="$WORK_DIR/${VAR}.csv"
  echo ">> Measuring variant (${DUR_VAR}s)..." | tee -a "$WORK_DIR/run.log"
  bash "$EXP_DIR/measure.sh" "$DUR_VAR" "$VAR_FILE" 2>&1 | tee -a "$WORK_DIR/run.log"
  
  echo ">> Evaluating results..." | tee -a "$WORK_DIR/run.log"
  DECISION=$(IMPROVE_PCT="$IMPROVE_PCT" MAX_ERR_DELTA_PCT="$MAX_ERR_DELTA_PCT" \
    bash "${SCRIPT_DIR}/decide.sh" "$WORK_DIR/baseline.csv" "$VAR_FILE" 2>&1 | tee "$WORK_DIR/${VAR}_decision.log" | tail -n1)
  
  cat "$WORK_DIR/${VAR}_decision.log" | tee -a "$WORK_DIR/run.log"
  
  if [ "$DECISION" = "keep" ]; then
    KEPT="$VAR"
    echo "✓ Decision: KEEP $VAR" | tee -a "$WORK_DIR/run.log"
    echo "$VAR" > "$WORK_DIR/kept.txt"
    break
  else
    echo "✗ Decision: REVERT $VAR" | tee -a "$WORK_DIR/run.log"
    bash "$EXP_DIR/revert.sh" 2>&1 | tee -a "$WORK_DIR/run.log"
  fi
done

# Read kept value from file if it was set in subshell
if [ -f "$WORK_DIR/kept.txt" ]; then
  KEPT=$(cat "$WORK_DIR/kept.txt")
fi

echo "" | tee -a "$WORK_DIR/run.log"
echo "================================" | tee -a "$WORK_DIR/run.log"
echo "Run complete. Final decision: $KEPT" | tee -a "$WORK_DIR/run.log"
echo "================================" | tee -a "$WORK_DIR/run.log"

# 3) Update dashboard
echo ">> Updating dashboard..." | tee -a "$WORK_DIR/run.log"
bash "${SCRIPT_DIR}/update_dashboard.sh" "$RUN_ID" "$EXP_DIR" "$KEPT" 2>&1 | tee -a "$WORK_DIR/run.log"

# 4) Optional phone-home
echo ">> Phoning home..." | tee -a "$WORK_DIR/run.log"
bash "${SCRIPT_DIR}/phone_home.sh" "$RUN_ID" 2>&1 | tee -a "$WORK_DIR/run.log" || true

echo "✓ All done. Results in: $WORK_DIR" | tee -a "$WORK_DIR/run.log"

