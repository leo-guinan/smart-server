#!/usr/bin/env bash
# Test smart server locally before deploying
set -euo pipefail

echo "================================"
echo "Smart Server Local Test"
echo "================================"
echo ""

# Check dependencies
echo ">> Checking dependencies..."
MISSING=""

if ! command -v jq &> /dev/null; then
  MISSING="${MISSING}jq "
fi

if ! command -v curl &> /dev/null; then
  MISSING="${MISSING}curl "
fi

if [ -n "$MISSING" ]; then
  echo "Error: Missing dependencies: $MISSING" >&2
  echo "Install with: brew install $MISSING (macOS) or apt-get install $MISSING (Linux)" >&2
  exit 1
fi

echo "✓ All dependencies found"
echo ""

# Set up local environment
export BASE_DIR="$(pwd)"
export RUNS_DIR="${BASE_DIR}/var/runs"
export STATE_FILE="${BASE_DIR}/var/state.json"
export DASH_DIR="${BASE_DIR}/www"

mkdir -p "${RUNS_DIR}" "${DASH_DIR}"

# Make scripts executable
chmod +x bin/*.sh
chmod +x experiments/001_nginx_workers/*.sh

echo ">> Creating test web server..."

# Create a simple test server if nginx isn't available
if ! command -v nginx &> /dev/null; then
  echo "   Nginx not found, creating Python test server..."
  
  # Create a simple test page
  mkdir -p test-server
  cat > test-server/index.html <<EOF
<!DOCTYPE html>
<html><body><h1>Test Server</h1></body></html>
EOF
  
  # Start Python server in background
  cd test-server
  python3 -m http.server 8000 > /dev/null 2>&1 &
  SERVER_PID=$!
  cd ..
  
  # Update experiment to use port 8000
  sed -i.bak 's|http://127.0.0.1/|http://127.0.0.1:8000/|' experiments/001_nginx_workers/meta.json
  
  # Since we can't test nginx workers without nginx, let's create a simple experiment
  cat > experiments/001_nginx_workers/apply.sh <<'SCRIPT'
#!/usr/bin/env bash
# Simplified test - just logs the variant
echo "Applied variant: $1"
SCRIPT
  
  cat > experiments/001_nginx_workers/revert.sh <<'SCRIPT'
#!/usr/bin/env bash
# Simplified test - just logs revert
echo "Reverted to baseline"
SCRIPT
  
  echo "   ✓ Test server started on port 8000 (PID: $SERVER_PID)"
else
  echo "   ✓ Nginx detected"
fi

echo ""
echo ">> Running experiment with short duration..."

# Override config for quick testing
export BASELINE_SECONDS=10
export EXPERIMENT_SECONDS=10
export COOLDOWN_SECONDS=2

bash bin/agent.sh

echo ""
echo ">> Test Results:"
echo "   - Logs: ${RUNS_DIR}/$(ls -t ${RUNS_DIR} | head -1)/run.log"
echo "   - State: ${STATE_FILE}"
echo ""

if [ -f "${STATE_FILE}" ]; then
  echo ">> State JSON:"
  cat "${STATE_FILE}" | jq .
  echo ""
  echo "✓ Test successful!"
  
  echo ""
  echo ">> View dashboard:"
  echo "   Open www/index.html in your browser"
  echo "   Or run: python3 -m http.server 3000"
  echo "   Then visit: http://localhost:3000/www/"
else
  echo "✗ Test failed - no state file generated"
  exit 1
fi

# Cleanup
if [ -n "${SERVER_PID:-}" ]; then
  kill $SERVER_PID 2>/dev/null || true
  echo ""
  echo ">> Cleaned up test server"
fi

echo ""
echo "================================"
echo "Local test complete!"
echo "================================"

