#!/usr/bin/env bash
# Fetch analytics data from Fathom API
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(dirname "$SCRIPT_DIR")"

# Source configurations
. "${EXP_DIR}/fathom.conf"

if [ -z "${FATHOM_API_KEY}" ]; then
  echo "Error: FATHOM_API_KEY not set" >&2
  echo "Set it in fathom.conf or as environment variable" >&2
  exit 1
fi

FATHOM_DATA_DIR="${EXP_DIR}/var/fathom"
mkdir -p "$FATHOM_DATA_DIR"

# Calculate date range
END_DATE=$(date -u +%Y-%m-%d)
START_DATE=$(date -u -d "${FATHOM_LOOKBACK_DAYS} days ago" +%Y-%m-%d 2>/dev/null || date -u -v-${FATHOM_LOOKBACK_DAYS}d +%Y-%m-%d)

echo "Fetching Fathom data for ${FATHOM_SITE_ID}..."
echo "Date range: ${START_DATE} to ${END_DATE}"
echo ""

# Fetch pageviews
echo ">> Fetching pageviews..."
curl -s -X GET "${FATHOM_API_URL}/aggregations" \
  -H "Authorization: Bearer ${FATHOM_API_KEY}" \
  -d "entity=pageview" \
  -d "entity_id=${FATHOM_SITE_ID}" \
  -d "aggregates=visits,uniques,pageviews" \
  -d "date_from=${START_DATE}" \
  -d "date_to=${END_DATE}" \
  | jq '.' > "${FATHOM_DATA_DIR}/pageviews.json"

# Fetch events
echo ">> Fetching events..."
for event in page_load scroll_25 scroll_50 scroll_75 scroll_90 cta_click; do
  echo "   - ${event}"
  curl -s -X GET "${FATHOM_API_URL}/aggregations" \
    -H "Authorization: Bearer ${FATHOM_API_KEY}" \
    -d "entity=event" \
    -d "entity_id=${event}" \
    -d "aggregates=visits,uniques" \
    -d "date_from=${START_DATE}" \
    -d "date_to=${END_DATE}" \
    -d "site_id=${FATHOM_SITE_ID}" \
    | jq '.' > "${FATHOM_DATA_DIR}/event_${event}.json"
done

# Fetch event values (for cta_click with $49)
echo ">> Fetching event values..."
curl -s -X GET "${FATHOM_API_URL}/aggregations" \
  -H "Authorization: Bearer ${FATHOM_API_KEY}" \
  -d "entity=event" \
  -d "entity_id=cta_click" \
  -d "aggregates=sum" \
  -d "date_from=${START_DATE}" \
  -d "date_to=${END_DATE}" \
  -d "site_id=${FATHOM_SITE_ID}" \
  | jq '.' > "${FATHOM_DATA_DIR}/event_cta_value.json"

echo ""
echo "✓ Fathom data fetched successfully"
echo "   Data saved to: ${FATHOM_DATA_DIR}"
echo ""

# Generate summary
echo "Summary:"
PAGEVIEWS=$(jq -r '.data[0].pageviews // 0' "${FATHOM_DATA_DIR}/pageviews.json")
VISITORS=$(jq -r '.data[0].uniques // 0' "${FATHOM_DATA_DIR}/pageviews.json")
echo "  Total pageviews: ${PAGEVIEWS}"
echo "  Unique visitors: ${VISITORS}"
echo ""

echo "Event conversions:"
for event in page_load scroll_25 scroll_50 scroll_75 scroll_90 cta_click; do
  COUNT=$(jq -r '.data[0].uniques // 0' "${FATHOM_DATA_DIR}/event_${event}.json")
  if [ "$VISITORS" -gt 0 ]; then
    PCT=$(awk -v c="$COUNT" -v v="$VISITORS" 'BEGIN{printf "%.1f", (c/v)*100}')
    echo "  ${event}: ${COUNT} (${PCT}%)"
  else
    echo "  ${event}: ${COUNT}"
  fi
done

CTA_VALUE=$(jq -r '.data[0].sum // 0' "${FATHOM_DATA_DIR}/event_cta_value.json")
echo ""
echo "  CTA value: \$${CTA_VALUE}"

