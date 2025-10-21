#!/usr/bin/env bash
# Install smart server on a fresh system
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/smart}"
SERVICE_USER="${SERVICE_USER:-smart}"

echo "================================"
echo "Smart Server Installation"
echo "================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (or with sudo)" >&2
  exit 1
fi

# Install dependencies
echo ">> Installing dependencies..."
apt-get update
apt-get install -y jq curl nginx

# Create service user
if ! id "$SERVICE_USER" &>/dev/null; then
  echo ">> Creating service user: $SERVICE_USER"
  useradd -r -s /bin/bash -d "$INSTALL_DIR" "$SERVICE_USER"
fi

# Create directory structure
echo ">> Creating directory structure at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"/{bin,experiments,var/runs,www}

# Copy files
echo ">> Copying files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cp "$PROJECT_ROOT/smart.conf" "$INSTALL_DIR/"
cp "$PROJECT_ROOT/context.md" "$INSTALL_DIR/"
cp -r "$PROJECT_ROOT/bin"/* "$INSTALL_DIR/bin/"
cp -r "$PROJECT_ROOT/experiments"/* "$INSTALL_DIR/experiments/"

# Make scripts executable
chmod +x "$INSTALL_DIR"/bin/*.sh
chmod +x "$INSTALL_DIR"/experiments/*/[!m]*.sh

# Update BASE_DIR in smart.conf
sed -i "s|BASE_DIR=.*|BASE_DIR=\"$INSTALL_DIR\"|" "$INSTALL_DIR/smart.conf"

# Set ownership
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

# Configure nginx
echo ">> Configuring nginx..."
cat > /etc/nginx/sites-available/smart-server <<EOF
server {
    listen 80;
    server_name _;
    
    root $INSTALL_DIR/www;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    location /state.json {
        alias $INSTALL_DIR/var/state.json;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
    
    location /runs/ {
        alias $INSTALL_DIR/var/runs/;
        autoindex on;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/smart-server /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# Set up sudoers for experiment scripts
echo ">> Configuring sudoers for $SERVICE_USER..."
cat > /etc/sudoers.d/smart-server <<EOF
# Allow smart user to reload nginx without password
$SERVICE_USER ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
$SERVICE_USER ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
$SERVICE_USER ALL=(ALL) NOPASSWD: /bin/sed -i* * /etc/nginx/nginx.conf
EOF

chmod 440 /etc/sudoers.d/smart-server

# Install systemd timer
echo ">> Installing systemd timer..."
cat > /etc/systemd/system/smart-experiment.service <<EOF
[Unit]
Description=Smart Server Experiment Runner
After=network.target

[Service]
Type=oneshot
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/agent.sh
StandardOutput=append:$INSTALL_DIR/var/experiment.log
StandardError=append:$INSTALL_DIR/var/experiment.log
EOF

cat > /etc/systemd/system/smart-experiment.timer <<EOF
[Unit]
Description=Smart Server Experiment Timer
Requires=smart-experiment.service

[Timer]
# Run every 30 minutes
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable smart-experiment.timer
systemctl start smart-experiment.timer

echo ""
echo "================================"
echo "✓ Installation complete!"
echo "================================"
echo ""
echo "Smart server installed at: $INSTALL_DIR"
echo "Web dashboard: http://$(hostname -I | awk '{print $1}')"
echo "Experiments run every 30 minutes via systemd timer"
echo ""
echo "Useful commands:"
echo "  - Run experiment now:  sudo -u $SERVICE_USER $INSTALL_DIR/bin/agent.sh"
echo "  - View logs:           tail -f $INSTALL_DIR/var/experiment.log"
echo "  - Check timer status:  systemctl status smart-experiment.timer"
echo "  - View runs:           ls -la $INSTALL_DIR/var/runs/"
echo ""

