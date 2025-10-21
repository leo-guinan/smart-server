#!/usr/bin/env bash
# Phone home to coaching service for advice
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source config
. "${BASE_DIR}/smart.conf"

RUN_ID="${1:-unknown}"

# Exit silently if no coach URL configured
[ -z "${COACH_URL:-}" ] && exit 0

# Build payload
payload=$(jq -n \
  --arg run "$RUN_ID" \
  --slurpfile state "$STATE_FILE" \
  '{run_id:$run, state:$state[0], server_id: env.HOSTNAME}')

# POST to coach (don't fail if coach is down)
curl -sS -X POST "$COACH_URL" \
  -H "Authorization: Bearer ${COACH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$payload" >/dev/null || {
    echo "Warning: Failed to contact coach at ${COACH_URL}" >&2
    exit 0
  }

echo "Successfully phoned home for run ${RUN_ID}" >&2

