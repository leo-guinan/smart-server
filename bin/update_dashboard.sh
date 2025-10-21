#!/usr/bin/env bash
# Update dashboard with latest experiment results
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source config
. "${BASE_DIR}/smart.conf"

RUN_ID="$1"
EXP_PATH="$2"
KEPT="${3:-none}"

# Summarize latest run
BASE_FILE="${RUNS_DIR}/${RUN_ID}/baseline.csv"
VAR_FILES=("${RUNS_DIR}/${RUN_ID}"/*.csv)

# Find most recent non-baseline file
VAR_FILE=""
for f in "${VAR_FILES[@]}"; do
  if [[ "$(basename "$f")" != "baseline.csv" ]]; then
    VAR_FILE="$f"
  fi
done

# Helper functions
p50() { 
  awk -F, 'NR>1{print $2}' "$1" | sort -n | awk '{
    a[NR]=$1
  } END {
    if (NR%2) {print a[(NR+1)/2]} 
    else {print (a[NR/2]+a[NR/2+1])/2}
  }'
}

err() { 
  awk -F, 'NR>1{
    if ($3+0>=500) e++
  } END{ 
    if (NR>1) print (e/(NR-1))*100
    else print 0
  }' "$1"
}

BASE_P50=$(p50 "$BASE_FILE")
VAR_P50=$(p50 "$VAR_FILE")
BASE_ERR=$(err "$BASE_FILE")
VAR_ERR=$(err "$VAR_FILE")

# Create directories
mkdir -p "$(dirname "$STATE_FILE")" "$DASH_DIR"

# Update state JSON
jq -n \
  --arg run_id "$RUN_ID" \
  --arg exp "$(basename "$EXP_PATH")" \
  --arg kept "$KEPT" \
  --arg base_p50 "$BASE_P50" \
  --arg var_p50 "$VAR_P50" \
  --arg base_err "$BASE_ERR" \
  --arg var_err "$VAR_ERR" \
  '{
    run_id: $run_id,
    experiment: $exp,
    kept_variant: $kept,
    metrics: { 
      base_p50_ms: ($base_p50|tonumber), 
      var_p50_ms: ($var_p50|tonumber), 
      base_err_pct: ($base_err|tonumber), 
      var_err_pct: ($var_err|tonumber) 
    },
    updated_at: (now|todate)
  }' > "$STATE_FILE"

# Create HTML dashboard if it doesn't exist
if [ ! -f "$DASH_DIR/index.html" ]; then
  cat > "$DASH_DIR/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Smart Server – Experiments</title>
<style>
  :root { 
    --bg:#0b1220; 
    --fg:#e6edf3; 
    --muted:#9aa4b2; 
    --card:#121a2a; 
    --ok:#12d27c; 
    --warn:#ffd166; 
    --bad:#ef476f; 
  }
  body {
    margin:0;
    background:var(--bg);
    color:var(--fg);
    font:16px/1.5 system-ui, -apple-system, Segoe UI, Roboto;
  }
  header {
    padding:24px 20px;
    border-bottom:1px solid #223;
  }
  main {
    max-width:880px;
    margin:0 auto;
    padding:24px;
  }
  .card {
    background:var(--card);
    border:1px solid #223;
    border-radius:14px;
    padding:18px;
    margin:14px 0;
  }
  .kpis {
    display:grid;
    grid-template-columns:repeat(2,minmax(0,1fr));
    gap:12px;
  }
  .kpi {
    background:#0e1626;
    border-radius:12px;
    padding:14px;
    border:1px solid #213;
  }
  .kpi h4 {
    margin:0 0 6px 0;
    color:var(--muted);
    font-weight:600;
    font-size:14px;
  }
  .kpi .v {
    font-size:22px;
    font-weight:600;
  }
  .row {
    display:flex;
    gap:10px;
    align-items:center;
    flex-wrap:wrap;
  }
  .pill {
    padding:4px 10px;
    border-radius:999px;
    background:#1a253a;
    font-size:12px;
    border:1px solid #223;
  }
  .ok {color:var(--ok)} 
  .bad {color:var(--bad)} 
  .muted {color:var(--muted)}
  button {
    background:#3374ff;
    color:#fff;
    border:none;
    padding:10px 14px;
    border-radius:10px;
    font-weight:600;
    cursor:pointer;
  }
  button:hover {
    background:#2563eb;
  }
  h1 {
    margin:0;
    font-size:28px;
  }
  h3 {
    margin:0 0 12px 0;
  }
</style>
</head>
<body>
<header>
  <h1>🧪 Smart Server</h1>
  <div class="muted">Self-adapting experiments</div>
</header>
<main>
  <section id="meta" class="card">
    <div class="row">
      <div>Experiment: <b id="exp"></b></div>
      <div class="pill">Run <span id="run"></span></div>
      <div class="pill">Kept variant: <span id="kept"></span></div>
    </div>
  </section>
  
  <section class="card">
    <h3>Performance Metrics</h3>
    <div class="kpis">
      <div class="kpi">
        <h4>Baseline p50 Latency</h4>
        <div class="v" id="b50"></div>
      </div>
      <div class="kpi">
        <h4>Variant p50 Latency</h4>
        <div class="v" id="v50"></div>
      </div>
      <div class="kpi">
        <h4>Baseline 5xx Rate</h4>
        <div class="v" id="b5x"></div>
      </div>
      <div class="kpi">
        <h4>Variant 5xx Rate</h4>
        <div class="v" id="v5x"></div>
      </div>
    </div>
  </section>
  
  <section class="card">
    <h3>Decision</h3>
    <div id="decision" class="muted">Loading…</div>
  </section>
  
  <section class="card">
    <h3>Last Updated</h3>
    <div id="updated" class="muted">—</div>
  </section>
</main>
<script>
async function load() {
  try {
    const r = await fetch('/state.json', {cache: 'no-store'});
    const s = await r.json();
    const el = id => document.getElementById(id);
    
    el('exp').textContent = s.experiment;
    el('run').textContent = s.run_id;
    el('kept').textContent = s.kept_variant;
    el('b50').textContent = s.metrics.base_p50_ms.toFixed(0) + ' ms';
    el('v50').textContent = s.metrics.var_p50_ms.toFixed(0) + ' ms';
    el('b5x').textContent = s.metrics.base_err_pct.toFixed(2) + ' %';
    el('v5x').textContent = s.metrics.var_err_pct.toFixed(2) + ' %';
    el('updated').textContent = s.updated_at;
    
    const improve = (s.metrics.base_p50_ms - s.metrics.var_p50_ms) / s.metrics.base_p50_ms * 100;
    const errDelta = s.metrics.var_err_pct - s.metrics.base_err_pct;
    const ok = improve >= 10 && errDelta <= 2;
    
    document.getElementById('decision').innerHTML =
      (ok ? '<span class="ok">✓ KEEP</span>' : '<span class="bad">✗ REVERT</span>') +
      ` — improve ${improve.toFixed(1)}%, Δ5xx ${errDelta.toFixed(2)}%`;
  } catch(e) {
    console.error('Failed to load state:', e);
    document.getElementById('decision').innerHTML = '<span class="bad">Error loading data</span>';
  }
}
load();
setInterval(load, 30000); // Refresh every 30s
</script>
</body>
</html>
HTML
fi

echo "Dashboard updated for run ${RUN_ID}" >&2

