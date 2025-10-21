#!/usr/bin/env bash
# Set up SSL certificates for smart server domains
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source configurations
. "${BASE_DIR}/smart.conf"
. "${BASE_DIR}/domain.conf"

if [ -z "${BASE_DOMAIN}" ]; then
  echo "Error: BASE_DOMAIN not set in domain.conf" >&2
  echo "Please set BASE_DOMAIN before running this script" >&2
  exit 1
fi

echo "================================"
echo "Smart Server SSL Setup"
echo "================================"
echo "Base domain: ${BASE_DOMAIN}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (or with sudo)" >&2
  exit 1
fi

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
  echo ">> Installing certbot..."
  apt-get update
  apt-get install -y certbot python3-certbot-nginx
fi

# Collect all domains
DOMAINS=()

# Add dashboard domain
if [ -n "${DASHBOARD_SUBDOMAIN}" ]; then
  DOMAINS+=("${DASHBOARD_SUBDOMAIN}.${BASE_DOMAIN}")
else
  DOMAINS+=("${BASE_DOMAIN}")
fi

# Add experiment subdomains
for exp_dir in "${BASE_DIR}/experiments"/*; do
  if [ -d "$exp_dir" ]; then
    exp_id=$(basename "$exp_dir" | cut -d_ -f1)
    exp_name=$(basename "$exp_dir")
    
    # Generate subdomain from pattern
    subdomain="${EXPERIMENT_SUBDOMAIN_PATTERN//\{experiment_id\}/$exp_id}"
    subdomain="${subdomain//\{experiment_name\}/$exp_name}"
    
    DOMAINS+=("${subdomain}.${BASE_DOMAIN}")
  fi
done

echo ">> Domains to certify:"
for domain in "${DOMAINS[@]}"; do
  echo "   - $domain"
done
echo ""

# Build certbot command
CERTBOT_CMD="certbot --nginx"
CERTBOT_CMD="${CERTBOT_CMD} --email ${SSL_EMAIL}"
CERTBOT_CMD="${CERTBOT_CMD} --agree-tos"
CERTBOT_CMD="${CERTBOT_CMD} --non-interactive"

# Add all domains
for domain in "${DOMAINS[@]}"; do
  CERTBOT_CMD="${CERTBOT_CMD} -d ${domain}"
done

echo ">> Requesting certificates..."
echo "Running: $CERTBOT_CMD"
echo ""

eval $CERTBOT_CMD

echo ""
echo "================================"
echo "✓ SSL Setup Complete!"
echo "================================"
echo ""
echo "Certificates installed for:"
for domain in "${DOMAINS[@]}"; do
  echo "  https://$domain"
done
echo ""
echo "Auto-renewal is configured via certbot systemd timer."
echo "Check status: systemctl status certbot.timer"

