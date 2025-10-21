#!/usr/bin/env bash
# Analyze landing page experiment results and update component stats
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATS_FILE="${SCRIPT_DIR}/var/component_stats.json"
RESULTS_FILE="${SCRIPT_DIR}/var/results.jsonl"
GENERATIONS_FILE="${SCRIPT_DIR}/var/generations.jsonl"

# Check if we have enough data
if [ ! -f "$RESULTS_FILE" ]; then
  echo "No results to analyze yet"
  exit 0
fi

TOTAL_SESSIONS=$(wc -l < "$RESULTS_FILE")

if [ "$TOTAL_SESSIONS" -lt 10 ]; then
  echo "Need at least 10 sessions to analyze (have: $TOTAL_SESSIONS)"
  exit 0
fi

echo "Analyzing $TOTAL_SESSIONS sessions..."

# Create temp file for updated stats
TMP_STATS=$(mktemp)

# Copy current stats structure
cp "$STATS_FILE" "$TMP_STATS"

# Function to update component stats
update_component_stats() {
  local stage=$1
  local component_id=$2
  
  # Count impressions for this component
  impressions=$(jq -r --arg id "$component_id" \
    'select(.components['$stage'] == $id)' \
    "$RESULTS_FILE" | wc -l)
  
  if [ "$impressions" -eq 0 ]; then
    return
  fi
  
  # Count conversions based on stage
  case $stage in
    hero)
      metric="scroll_25"
      ;;
    problem)
      metric="scroll_50"
      ;;
    solution)
      metric="scroll_75"
      ;;
    proof)
      metric="scroll_90"
      ;;
    cta)
      metric="cta_click"
      ;;
  esac
  
  # Count successful conversions
  conversions=$(jq -r --arg id "$component_id" --arg m "$metric" \
    'select(.components['$stage'] == $id) | select(.events[$m] == true)' \
    "$RESULTS_FILE" | wc -l)
  
  # Calculate conversion rate
  conversion_rate=$(awk -v c="$conversions" -v i="$impressions" 'BEGIN{printf "%.4f", c/i}')
  
  # Calculate average dwell time
  avg_dwell=$(jq -r --arg id "$component_id" \
    'select(.components['$stage'] == $id) | .dwell_time_ms' \
    "$RESULTS_FILE" | \
    awk '{sum+=$1; count++} END{if(count>0) print int(sum/count); else print 0}')
  
  # Update stats in JSON
  jq --arg stage "$stage" \
     --arg id "$component_id" \
     --argjson imp "$impressions" \
     --arg conv "$conversions" \
     --arg rate "$conversion_rate" \
     --argjson dwell "$avg_dwell" \
     '(.components[$stage][] | select(.id==$id) | .stats) |= {
        impressions: $imp,
        ($conv | split("_")[0]): ($conv | tonumber),
        conversion_rate: ($rate | tonumber),
        avg_dwell_ms: $dwell
      }' \
     "$TMP_STATS" > "${TMP_STATS}.new"
  
  mv "${TMP_STATS}.new" "$TMP_STATS"
  
  echo "  $component_id: $impressions impressions, $conversions conversions ($conversion_rate rate)"
}

# Analyze each stage and component
for stage in hero problem solution proof cta; do
  echo "Analyzing $stage components:"
  
  # Get all unique component IDs for this stage
  jq -r ".components.$stage[].id" "$STATS_FILE" | while read -r component_id; do
    update_component_stats "$stage" "$component_id"
  done
done

# Save updated stats
mv "$TMP_STATS" "$STATS_FILE"

echo ""
echo "✓ Analysis complete"
echo ""
echo "Top performers by stage:"

for stage in hero problem solution proof cta; do
  top=$(jq -r --arg s "$stage" \
    '.components[$s] | sort_by(-.stats.conversion_rate) | .[0] | "\(.id): \(.stats.conversion_rate)"' \
    "$STATS_FILE")
  echo "  $stage: $top"
done

# Identify underperformers
echo ""
echo "Components to review (conversion_rate < 0.5):"
jq -r '.components[] | .[] | select(.stats.conversion_rate < 0.5 and .stats.impressions > 10) | "  \(.id): \(.stats.conversion_rate) (\(.stats.impressions) impressions)"' "$STATS_FILE"

