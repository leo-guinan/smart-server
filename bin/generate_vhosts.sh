#!/usr/bin/env bash
# Generate nginx virtual hosts for experiments and dashboard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source configurations
. "${BASE_DIR}/smart.conf"
. "${BASE_DIR}/domain.conf"

NGINX_SITES_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (or with sudo)" >&2
  exit 1
fi

echo "================================"
echo "Generating Nginx Virtual Hosts"
echo "================================"
echo ""

# Create dashboard vhost
if [ -n "${BASE_DOMAIN}" ]; then
  if [ -n "${DASHBOARD_SUBDOMAIN}" ]; then
    DASHBOARD_DOMAIN="${DASHBOARD_SUBDOMAIN}.${BASE_DOMAIN}"
  else
    DASHBOARD_DOMAIN="${BASE_DOMAIN}"
  fi
  
  echo ">> Creating dashboard vhost: ${DASHBOARD_DOMAIN}"
  
  cat > "${NGINX_SITES_DIR}/smart-dashboard" <<EOF
server {
    listen 80;
    server_name ${DASHBOARD_DOMAIN};
    
    root ${BASE_DIR}/www;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /state.json {
        alias ${BASE_DIR}/var/state.json;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        add_header Content-Type "application/json";
    }
    
    location /runs/ {
        alias ${BASE_DIR}/var/runs/;
        autoindex on;
    }
    
    # Will be updated by certbot when SSL is set up
}
EOF
  
  ln -sf "${NGINX_SITES_DIR}/smart-dashboard" "${NGINX_ENABLED_DIR}/"
fi

# Create experiment vhosts
for exp_dir in "${BASE_DIR}/experiments"/*; do
  if [ -d "$exp_dir" ]; then
    exp_id=$(basename "$exp_dir" | cut -d_ -f1)
    exp_name=$(basename "$exp_dir")
    
    if [ -n "${BASE_DOMAIN}" ]; then
      # Generate subdomain from pattern
      subdomain="${EXPERIMENT_SUBDOMAIN_PATTERN//\{experiment_id\}/$exp_id}"
      subdomain="${subdomain//\{experiment_name\}/$exp_name}"
      exp_domain="${subdomain}.${BASE_DOMAIN}"
      
      echo ">> Creating experiment vhost: ${exp_domain} -> ${exp_name}"
      
      cat > "${NGINX_SITES_DIR}/smart-exp-${exp_id}" <<EOF
server {
    listen 80;
    server_name ${exp_domain};
    
    root ${BASE_DIR}/www;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /state.json {
        alias ${BASE_DIR}/var/state.json;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
        add_header Content-Type "application/json";
    }
    
    location /runs/ {
        alias ${BASE_DIR}/var/runs/;
        autoindex on;
    }
    
    # Custom experiment-specific configuration can go here
    
    # Will be updated by certbot when SSL is set up
}
EOF
      
      ln -sf "${NGINX_SITES_DIR}/smart-exp-${exp_id}" "${NGINX_ENABLED_DIR}/"
    fi
  fi
done

# Test nginx configuration
echo ""
echo ">> Testing nginx configuration..."
nginx -t

echo ""
echo ">> Reloading nginx..."
systemctl reload nginx

echo ""
echo "================================"
echo "✓ Virtual Hosts Created!"
echo "================================"
echo ""

if [ -n "${BASE_DOMAIN}" ]; then
  echo "Configured domains:"
  echo "  Dashboard: http://${DASHBOARD_DOMAIN}"
  for exp_dir in "${BASE_DIR}/experiments"/*; do
    if [ -d "$exp_dir" ]; then
      exp_id=$(basename "$exp_dir" | cut -d_ -f1)
      exp_name=$(basename "$exp_dir")
      subdomain="${EXPERIMENT_SUBDOMAIN_PATTERN//\{experiment_id\}/$exp_id}"
      subdomain="${subdomain//\{experiment_name\}/$exp_name}"
      echo "  ${exp_name}: http://${subdomain}.${BASE_DOMAIN}"
    fi
  done
  echo ""
  echo "Next step: Run setup_ssl.sh to enable HTTPS"
else
  echo "No BASE_DOMAIN set. Using IP-based configuration."
fi

