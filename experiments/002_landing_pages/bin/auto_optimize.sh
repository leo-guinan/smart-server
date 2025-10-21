#!/usr/bin/env bash
# Automatically fetch Fathom data, analyze, and regenerate page
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         Smart Server: Auto-Optimization Cycle            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Started: $(date)"
echo ""

# Step 1: Fetch latest data from Fathom
echo "STEP 1: Fetching Fathom Analytics data..."
echo "────────────────────────────────────────────────────────────"
if bash "${SCRIPT_DIR}/fetch_fathom_data.sh"; then
  echo "✓ Data fetched successfully"
else
  echo "✗ Failed to fetch Fathom data"
  exit 1
fi

echo ""
echo "STEP 2: Analyzing performance..."
echo "────────────────────────────────────────────────────────────"
if bash "${SCRIPT_DIR}/analyze_with_fathom.sh"; then
  echo "✓ Analysis complete"
else
  echo "✗ Analysis failed"
  exit 1
fi

echo ""
echo "STEP 3: Regenerating landing page..."
echo "────────────────────────────────────────────────────────────"
if bash "${EXP_DIR}/generate_page.sh"; then
  echo "✓ Page regenerated with optimized components"
else
  echo "✗ Failed to regenerate page"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║              Optimization Cycle Complete                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Completed: $(date)"
echo ""
echo "View updated page: https://exp-002.letleodoit.com"
echo "Check stats: cat ${EXP_DIR}/var/component_stats.json | jq ."

