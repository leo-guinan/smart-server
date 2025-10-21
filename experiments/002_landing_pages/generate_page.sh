#!/usr/bin/env bash
# Dynamic landing page generator - selects best-performing components
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Source configurations
. "${BASE_DIR}/smart.conf"

COMPONENTS_FILE="${SCRIPT_DIR}/components.json"
META_FILE="${SCRIPT_DIR}/meta.json"
OUTPUT_DIR="${SCRIPT_DIR}/public"
STATS_FILE="${SCRIPT_DIR}/var/component_stats.json"

mkdir -p "${OUTPUT_DIR}" "${SCRIPT_DIR}/var"

# Initialize stats file if it doesn't exist
if [ ! -f "$STATS_FILE" ]; then
  cp "$COMPONENTS_FILE" "$STATS_FILE"
fi

# Function to select best component for a stage using epsilon-greedy
select_component() {
  local stage=$1
  local epsilon=0.2  # 20% exploration, 80% exploitation
  
  # Random number between 0 and 1
  local rand=$(awk 'BEGIN{srand(); print rand()}')
  
  if awk -v r="$rand" -v e="$epsilon" 'BEGIN{exit !(r < e)}'; then
    # Explore: random selection
    jq -r --arg stage "$stage" \
      '.components[$stage] | .[floor(now * 1000 % length)] | .id' \
      "$STATS_FILE"
  else
    # Exploit: best performing
    jq -r --arg stage "$stage" \
      '.components[$stage] | sort_by(-.stats.conversion_rate) | .[0] | .id' \
      "$STATS_FILE"
  fi
}

# Generate session ID
SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "session_$(date +%s)")

# Select components for each stage
HERO_ID=$(select_component "hero")
PROBLEM_ID=$(select_component "problem")
SOLUTION_ID=$(select_component "solution")
PROOF_ID=$(select_component "proof")
CTA_ID=$(select_component "cta")

# Get Fathom site ID
FATHOM_SITE_ID=$(jq -r '.fathom_site_id' "$META_FILE")

# Build the page
cat > "${OUTPUT_DIR}/index.html" << 'HTMLSTART'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Time Audit - Find Where Your Time Leaks</title>
  <link rel="stylesheet" href="/landing/styles.css">
  <script src="https://cdn.usefathom.com/script.js" data-site="FATHOM_SITE_ID_PLACEHOLDER" defer></script>
</head>
<body>
  <main class="landing-page" data-session-id="SESSION_ID_PLACEHOLDER">
HTMLSTART

# Insert selected components
for component_id in "$HERO_ID" "$PROBLEM_ID" "$SOLUTION_ID" "$PROOF_ID" "$CTA_ID"; do
  # Find the component's HTML file
  html_file=$(jq -r --arg id "$component_id" \
    '.components[] | .[] | select(.id==$id) | .html' \
    "$COMPONENTS_FILE")
  
  if [ -f "${SCRIPT_DIR}/${html_file}" ]; then
    cat "${SCRIPT_DIR}/${html_file}" >> "${OUTPUT_DIR}/index.html"
  fi
done

# Add tracking script
cat >> "${OUTPUT_DIR}/index.html" << 'HTMLEND'
  </main>
  
  <script>
    // Tracking configuration
    const SESSION_ID = document.querySelector('.landing-page').dataset.sessionId;
    const COMPONENTS = {
      hero: document.querySelector('[data-stage="hero"]')?.dataset.component,
      problem: document.querySelector('[data-stage="problem"]')?.dataset.component,
      solution: document.querySelector('[data-stage="solution"]')?.dataset.component,
      proof: document.querySelector('[data-stage="proof"]')?.dataset.component,
      cta: document.querySelector('[data-stage="cta"]')?.dataset.component
    };
    
    // Track experiment start
    if (window.fathom) {
      fathom.trackGoal('PAGE_LOAD', 0);
      fathom.trackEvent('experiment_config', {
        _value: JSON.stringify(COMPONENTS),
        _session: SESSION_ID
      });
    }
    
    // Scroll tracking
    let scrollEvents = {
      scroll_25: false,
      scroll_50: false,
      scroll_75: false,
      scroll_90: false
    };
    
    window.addEventListener('scroll', () => {
      const scrollPct = window.scrollY / (document.body.scrollHeight - window.innerHeight);
      
      if (scrollPct > 0.25 && !scrollEvents.scroll_25) {
        scrollEvents.scroll_25 = true;
        if (window.fathom) fathom.trackGoal('SCROLL_25', 0);
      }
      if (scrollPct > 0.5 && !scrollEvents.scroll_50) {
        scrollEvents.scroll_50 = true;
        if (window.fathom) fathom.trackGoal('SCROLL_50', 0);
      }
      if (scrollPct > 0.75 && !scrollEvents.scroll_75) {
        scrollEvents.scroll_75 = true;
        if (window.fathom) fathom.trackGoal('SCROLL_75', 0);
      }
      if (scrollPct > 0.9 && !scrollEvents.scroll_90) {
        scrollEvents.scroll_90 = true;
        if (window.fathom) fathom.trackGoal('SCROLL_90', 0);
      }
    });
    
    // CTA click tracking
    document.querySelectorAll('[data-event="cta_click"]').forEach(button => {
      button.addEventListener('click', (e) => {
        const offer = e.target.dataset.offer;
        if (window.fathom) {
          fathom.trackGoal('CTA_CLICK', 49); // $49 value
          fathom.trackEvent('cta_click', {
            _value: offer,
            _session: SESSION_ID
          });
        }
        // Redirect to checkout
        window.location.href = `/checkout/${offer}`;
      });
    });
    
    // Track time on page
    let startTime = Date.now();
    window.addEventListener('beforeunload', () => {
      const dwellTime = Date.now() - startTime;
      if (window.fathom) {
        fathom.trackEvent('page_exit', {
          _value: Math.round(dwellTime / 1000),
          _session: SESSION_ID
        });
      }
    });
    
    // Send results to server for analysis
    window.addEventListener('beforeunload', () => {
      const results = {
        session_id: SESSION_ID,
        components: COMPONENTS,
        events: scrollEvents,
        dwell_time_ms: Date.now() - startTime
      };
      
      // Use sendBeacon for reliable delivery
      navigator.sendBeacon('/api/landing/track', JSON.stringify(results));
    });
  </script>
</body>
</html>
HTMLEND

# Replace placeholders
sed -i.bak "s/FATHOM_SITE_ID_PLACEHOLDER/${FATHOM_SITE_ID}/g" "${OUTPUT_DIR}/index.html"
sed -i.bak "s/SESSION_ID_PLACEHOLDER/${SESSION_ID}/g" "${OUTPUT_DIR}/index.html"
rm "${OUTPUT_DIR}/index.html.bak"

# Log the generation
echo "{\"session_id\":\"${SESSION_ID}\",\"components\":{\"hero\":\"${HERO_ID}\",\"problem\":\"${PROBLEM_ID}\",\"solution\":\"${SOLUTION_ID}\",\"proof\":\"${PROOF_ID}\",\"cta\":\"${CTA_ID}\"},\"timestamp\":\"$(date -Iseconds)\"}" \
  >> "${SCRIPT_DIR}/var/generations.jsonl"

echo "✓ Generated landing page: ${OUTPUT_DIR}/index.html"
echo "  Session: ${SESSION_ID}"
echo "  Components: ${HERO_ID}, ${PROBLEM_ID}, ${SOLUTION_ID}, ${PROOF_ID}, ${CTA_ID}"

