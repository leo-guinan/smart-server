#!/usr/bin/env bash
# Validate smart server configuration and structure
set -euo pipefail

echo "================================"
echo "Smart Server Validation"
echo "================================"
echo ""

ERRORS=0

# Check directory structure
echo ">> Checking directory structure..."

REQUIRED_DIRS=(
  "bin"
  "experiments"
  "experiments/001_nginx_workers"
  "deploy"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    echo "   ✓ $dir"
  else
    echo "   ✗ Missing: $dir" >&2
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""
echo ">> Checking required files..."

REQUIRED_FILES=(
  "smart.conf"
  "context.md"
  "bin/agent.sh"
  "bin/decide.sh"
  "bin/phone_home.sh"
  "bin/update_dashboard.sh"
  "experiments/001_nginx_workers/meta.json"
  "experiments/001_nginx_workers/apply.sh"
  "experiments/001_nginx_workers/revert.sh"
  "experiments/001_nginx_workers/measure.sh"
  "deploy/install.sh"
  "deploy/hetzner-cloud-init.yaml"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "   ✓ $file"
  else
    echo "   ✗ Missing: $file" >&2
    ERRORS=$((ERRORS + 1))
  fi
done

echo ""
echo ">> Checking script permissions..."

EXECUTABLE_SCRIPTS=(
  "bin/agent.sh"
  "bin/decide.sh"
  "bin/phone_home.sh"
  "bin/update_dashboard.sh"
  "experiments/001_nginx_workers/apply.sh"
  "experiments/001_nginx_workers/revert.sh"
  "experiments/001_nginx_workers/measure.sh"
)

for script in "${EXECUTABLE_SCRIPTS[@]}"; do
  if [ -f "$script" ]; then
    if [ -x "$script" ]; then
      echo "   ✓ $script is executable"
    else
      echo "   ⚠ $script not executable (run: chmod +x $script)"
    fi
  fi
done

echo ""
echo ">> Validating JSON files..."

JSON_FILES=(
  "experiments/001_nginx_workers/meta.json"
)

for json in "${JSON_FILES[@]}"; do
  if [ -f "$json" ]; then
    if jq empty "$json" 2>/dev/null; then
      echo "   ✓ $json is valid JSON"
    else
      echo "   ✗ $json has invalid JSON" >&2
      ERRORS=$((ERRORS + 1))
    fi
  fi
done

echo ""
echo ">> Checking for common issues..."

# Check if BASE_DIR is set correctly in smart.conf
if grep -q 'BASE_DIR="${BASE_DIR:-/opt/smart}"' smart.conf; then
  echo "   ✓ BASE_DIR properly configured"
else
  echo "   ⚠ BASE_DIR might not be configured correctly"
fi

# Check for placeholder values
if grep -q "YOUR_USERNAME" deploy/hetzner-cloud-init.yaml; then
  echo "   ⚠ hetzner-cloud-init.yaml still has YOUR_USERNAME placeholder"
  echo "     Update this before deploying!"
fi

echo ""
echo "================================"

if [ $ERRORS -eq 0 ]; then
  echo "✓ Validation passed!"
  echo "================================"
  echo ""
  echo "Next steps:"
  echo "  1. Run: bash scripts/test-local.sh"
  echo "  2. Update: deploy/hetzner-cloud-init.yaml with your repo"
  echo "  3. Deploy: See DEPLOYMENT.md"
  exit 0
else
  echo "✗ Validation failed with $ERRORS errors"
  echo "================================"
  exit 1
fi

