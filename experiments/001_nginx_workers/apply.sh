#!/usr/bin/env bash
# Apply a specific experiment variant
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
META="${SCRIPT_DIR}/meta.json"

VARIANT_NAME="$1"

if [ ! -f "$META" ]; then
  echo "Error: meta.json not found" >&2
  exit 1
fi

CMD=$(jq -r --arg v "$VARIANT_NAME" '.variants[] | select(.name==$v).apply' "$META")

if [ -z "$CMD" ] || [ "$CMD" = "null" ]; then
  echo "Error: Variant '$VARIANT_NAME' not found" >&2
  exit 1
fi

if [ "$CMD" = "true" ]; then
  echo "Baseline variant - no changes needed"
else
  echo "Applying variant: $VARIANT_NAME"
  eval "$CMD"
fi

