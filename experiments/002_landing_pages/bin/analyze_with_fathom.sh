#!/usr/bin/env bash
# Analyze landing page performance using Fathom data and update component stats
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(dirname "$SCRIPT_DIR")"

# Source configurations
. "${EXP_DIR}/fathom.conf"

FATHOM_DATA_DIR="${EXP_DIR}/var/fathom"
STATS_FILE="${EXP_DIR}/var/component_stats.json"
COMPONENTS_FILE="${EXP_DIR}/components.json"

echo "================================"
echo "Smart Server: Fathom Analysis"
echo "================================"
echo ""

# Check if Fathom data exists
if [ ! -d "$FATHOM_DATA_DIR" ] || [ ! -f "${FATHOM_DATA_DIR}/pageviews.json" ]; then
  echo "No Fathom data found. Run fetch_fathom_data.sh first."
  exit 1
fi

# Initialize stats if needed
if [ ! -f "$STATS_FILE" ]; then
  cp "$COMPONENTS_FILE" "$STATS_FILE"
fi

# Get total visitors
# Fathom returns array directly, not {data: [...]}
TOTAL_VISITORS=$(jq -r '.[0].uniques // 0' "${FATHOM_DATA_DIR}/pageviews.json")

if [ "$TOTAL_VISITORS" -lt "$MIN_SESSIONS_FOR_ANALYSIS" ]; then
  echo "Not enough data yet (need ${MIN_SESSIONS_FOR_ANALYSIS}, have ${TOTAL_VISITORS})"
  echo "Keep driving traffic and check back later."
  exit 0
fi

echo "Analyzing ${TOTAL_VISITORS} visitors..."
echo ""

# Calculate funnel conversion rates
# Fathom returns array directly, not {data: [...]}
PAGE_LOADS=$(jq -r '.[0].uniques // 0' "${FATHOM_DATA_DIR}/event_page_load.json")
SCROLL_25=$(jq -r '.[0].uniques // 0' "${FATHOM_DATA_DIR}/event_scroll_25.json")
SCROLL_50=$(jq -r '.[0].uniques // 0' "${FATHOM_DATA_DIR}/event_scroll_50.json")
SCROLL_75=$(jq -r '.[0].uniques // 0' "${FATHOM_DATA_DIR}/event_scroll_75.json")
SCROLL_90=$(jq -r '.[0].uniques // 0' "${FATHOM_DATA_DIR}/event_scroll_90.json")
CTA_CLICKS=$(jq -r '.[0].uniques // 0' "${FATHOM_DATA_DIR}/event_cta_click.json")

echo "Funnel Analysis:"
echo "  Visitors:     ${TOTAL_VISITORS}"
echo "  Page loads:   ${PAGE_LOADS}"
echo "  Scroll 25%:   ${SCROLL_25} (hero → problem)"
echo "  Scroll 50%:   ${SCROLL_50} (problem → solution)"
echo "  Scroll 75%:   ${SCROLL_75} (solution → proof)"
echo "  Scroll 90%:   ${SCROLL_90} (proof → CTA)"
echo "  CTA clicks:   ${CTA_CLICKS}"
echo ""

# Calculate conversion rates
if [ "$PAGE_LOADS" -gt 0 ]; then
  HERO_RATE=$(awk -v s="$SCROLL_25" -v p="$PAGE_LOADS" 'BEGIN{printf "%.4f", s/p}')
else
  HERO_RATE=0
fi

if [ "$SCROLL_25" -gt 0 ]; then
  PROBLEM_RATE=$(awk -v s="$SCROLL_50" -v p="$SCROLL_25" 'BEGIN{printf "%.4f", s/p}')
else
  PROBLEM_RATE=0
fi

if [ "$SCROLL_50" -gt 0 ]; then
  SOLUTION_RATE=$(awk -v s="$SCROLL_75" -v p="$SCROLL_50" 'BEGIN{printf "%.4f", s/p}')
else
  SOLUTION_RATE=0
fi

if [ "$SCROLL_75" -gt 0 ]; then
  PROOF_RATE=$(awk -v s="$SCROLL_90" -v p="$SCROLL_75" 'BEGIN{printf "%.4f", s/p}')
else
  PROOF_RATE=0
fi

if [ "$SCROLL_90" -gt 0 ]; then
  CTA_RATE=$(awk -v c="$CTA_CLICKS" -v p="$SCROLL_90" 'BEGIN{printf "%.4f", c/p}')
else
  CTA_RATE=0
fi

echo "Stage Conversion Rates:"
echo "  Hero:         ${HERO_RATE} ($(awk -v r="$HERO_RATE" 'BEGIN{printf "%.1f", r*100}')%)"
echo "  Problem:      ${PROBLEM_RATE} ($(awk -v r="$PROBLEM_RATE" 'BEGIN{printf "%.1f", r*100}')%)"
echo "  Solution:     ${SOLUTION_RATE} ($(awk -v r="$SOLUTION_RATE" 'BEGIN{printf "%.1f", r*100}')%)"
echo "  Proof:        ${PROOF_RATE} ($(awk -v r="$PROOF_RATE" 'BEGIN{printf "%.1f", r*100}')%)"
echo "  CTA:          ${CTA_RATE} ($(awk -v r="$CTA_RATE" 'BEGIN{printf "%.1f", r*100}')%)"
echo ""

# Overall conversion
if [ "$TOTAL_VISITORS" -gt 0 ]; then
  OVERALL_RATE=$(awk -v c="$CTA_CLICKS" -v t="$TOTAL_VISITORS" 'BEGIN{printf "%.4f", c/t}')
  echo "Overall Conversion: ${OVERALL_RATE} ($(awk -v r="$OVERALL_RATE" 'BEGIN{printf "%.2f", r*100}')%)"
else
  OVERALL_RATE=0
fi

# Calculate revenue
CTA_VALUE=$(jq -r '.[0].sum // 0' "${FATHOM_DATA_DIR}/event_cta_value.json")
echo "Total Revenue: \$${CTA_VALUE}"
echo ""

# Update component stats based on performance
# Since we don't have per-component tracking yet, we'll update all components
# with the average performance for their stage

echo "Updating component statistics..."

# Create temp file
TMP_STATS=$(mktemp)
cp "$STATS_FILE" "$TMP_STATS"

# Update each stage with real conversion rates
# We distribute the impressions equally among components since we don't track individual components yet
for stage in hero problem solution proof cta; do
  case $stage in
    hero)
      RATE=$HERO_RATE
      METRIC="scroll_25"
      ;;
    problem)
      RATE=$PROBLEM_RATE
      METRIC="scroll_50"
      ;;
    solution)
      RATE=$SOLUTION_RATE
      METRIC="scroll_75"
      ;;
    proof)
      RATE=$PROOF_RATE
      METRIC="scroll_90"
      ;;
    cta)
      RATE=$CTA_RATE
      METRIC="cta_click"
      ;;
  esac
  
  # Count components in this stage
  COMPONENT_COUNT=$(jq -r ".components.${stage} | length" "$STATS_FILE")
  
  # Distribute impressions equally (for now - later we can track per-component)
  IMPRESSIONS=$(awk -v t="$TOTAL_VISITORS" -v c="$COMPONENT_COUNT" 'BEGIN{printf "%d", t/c}')
  
  # Update each component in this stage
  jq ".components.${stage}[] |= . + {
    stats: {
      impressions: ${IMPRESSIONS},
      ${METRIC}: 0,
      conversion_rate: ${RATE},
      avg_dwell_ms: 0
    }
  }" "$TMP_STATS" > "${TMP_STATS}.new"
  
  mv "${TMP_STATS}.new" "$TMP_STATS"
done

# Save updated stats
mv "$TMP_STATS" "$STATS_FILE"

echo "✓ Component stats updated"
echo ""

# Identify best and worst performing stages
echo "Stage Performance:"
declare -A stage_rates=(
  ["hero"]=$HERO_RATE
  ["problem"]=$PROBLEM_RATE
  ["solution"]=$SOLUTION_RATE
  ["proof"]=$PROOF_RATE
  ["cta"]=$CTA_RATE
)

# Find weakest stage
MIN_RATE=1.0
WEAKEST_STAGE=""
for stage in hero problem solution proof cta; do
  rate=${stage_rates[$stage]}
  if awk -v r="$rate" -v m="$MIN_RATE" 'BEGIN{exit !(r < m)}'; then
    MIN_RATE=$rate
    WEAKEST_STAGE=$stage
  fi
done

echo "  Weakest stage: ${WEAKEST_STAGE} ($(awk -v r="$MIN_RATE" 'BEGIN{printf "%.1f", r*100}')%)"
echo "  → Focus optimization efforts here"
echo ""

# Recommendations
echo "Recommendations:"
if awk -v r="$HERO_RATE" 'BEGIN{exit !(r < 0.7)}'; then
  echo "  ⚠️  Hero conversion is low (<70%) - Test new hooks"
fi
if awk -v r="$PROBLEM_RATE" 'BEGIN{exit !(r < 0.6)}'; then
  echo "  ⚠️  Problem section losing visitors - Strengthen the pain point"
fi
if awk -v r="$SOLUTION_RATE" 'BEGIN{exit !(r < 0.5)}'; then
  echo "  ⚠️  Solution not resonating - Clarify the value proposition"
fi
if awk -v r="$PROOF_RATE" 'BEGIN{exit !(r < 0.4)}'; then
  echo "  ⚠️  Proof insufficient - Add more case studies or testimonials"
fi
if awk -v r="$CTA_RATE" 'BEGIN{exit !(r < 0.1)}'; then
  echo "  ⚠️  CTA conversion very low - Test different offers or guarantees"
fi
if awk -v r="$OVERALL_RATE" 'BEGIN{exit !(r >= 0.02)}'; then
  echo "  ✅ Overall conversion is good (>2%)"
fi

echo ""
echo "================================"
echo "Next: Regenerate page to apply optimizations"
echo "  bash generate_page.sh"
echo "================================"

