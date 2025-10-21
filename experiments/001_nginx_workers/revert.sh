#!/usr/bin/env bash
# Revert to baseline configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META="${SCRIPT_DIR}/meta.json"

if [ ! -f "$META" ]; then
  echo "Error: meta.json not found" >&2
  exit 1
fi

CMD=$(jq -r '.revert' "$META")

if [ -z "$CMD" ] || [ "$CMD" = "null" ]; then
  echo "Error: No revert command defined" >&2
  exit 1
fi

echo "Reverting to baseline configuration"
eval "$CMD"

