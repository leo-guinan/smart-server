#!/usr/bin/env bash
# Simple API endpoint to receive tracking data from landing pages
# This should be called by nginx with the request body piped in

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_FILE="${EXP_DIR}/var/results.jsonl"

mkdir -p "${EXP_DIR}/var"

# Read JSON from stdin (nginx passes request body)
INPUT=$(cat)

# Validate JSON
if ! echo "$INPUT" | jq empty 2>/dev/null; then
  echo "Content-Type: application/json"
  echo ""
  echo '{"error":"Invalid JSON"}'
  exit 1
fi

# Append to results file with timestamp
echo "$INPUT" | jq -c '. + {received_at: (now|todate)}' >> "$RESULTS_FILE"

# Return success
echo "Content-Type: application/json"
echo ""
echo '{"status":"ok"}'

