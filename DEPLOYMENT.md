# Deployment Guide: Smart Server on Hetzner

This guide walks you through deploying the Smart Server to Hetzner Cloud.

## Prerequisites

- Hetzner Cloud account
- `hcloud` CLI installed (or use the Hetzner Cloud Console)
- SSH key added to Hetzner
- GitHub repository (or other git hosting) with this code

## Method 1: Automated with Cloud-Init (Recommended)

This method uses cloud-init to automatically set up everything on first boot.

### Step 1: Prepare Your Repository

1. Push this code to a git repository:
   ```bash
   git init
   git add .
   git commit -m "Initial smart server setup"
   git remote add origin <your-repo-url>
   git push -u origin main
   ```

2. Edit `deploy/hetzner-cloud-init.yaml`:
   - Replace `YOUR_USERNAME/smart_server` with your actual repo URL

### Step 2: Create the Server

Using Hetzner CLI:

```bash
# List available server types
hcloud server-type list

# Create server with cloud-init
hcloud server create \
  --name smart-server-01 \
  --type cx11 \
  --image ubuntu-22.04 \
  --location nbg1 \
  --ssh-key <your-key-name> \
  --user-data-from-file deploy/hetzner-cloud-init.yaml
```

Using Hetzner Cloud Console:
1. Go to "Servers" → "Add Server"
2. Choose Ubuntu 22.04
3. Select CX11 or larger
4. Add your SSH key
5. Under "Cloud config", paste contents of `deploy/hetzner-cloud-init.yaml`
6. Click "Create & Buy now"

### Step 3: Wait for Installation

The server will:
- Update packages
- Install dependencies (jq, curl, nginx)
- Clone your repository
- Run the installation script
- Configure nginx
- Set up the systemd timer

This takes about 3-5 minutes.

### Step 4: Access Your Server

```bash
# Get the server IP
hcloud server describe smart-server-01

# SSH into the server
ssh root@<server-ip>

# Check installation status
systemctl status smart-experiment.timer
tail -f /opt/smart/var/experiment.log
```

### Step 5: View Dashboard

Open your browser to: `http://<server-ip>`

## Method 2: Manual Installation

If you prefer manual setup or need more control:

### Step 1: Create Basic Server

```bash
hcloud server create \
  --name smart-server-01 \
  --type cx11 \
  --image ubuntu-22.04 \
  --location nbg1 \
  --ssh-key <your-key-name>
```

### Step 2: SSH and Install

```bash
# SSH into the server
ssh root@<server-ip>

# Clone repository
git clone <your-repo-url> /opt/smart-repo
cd /opt/smart-repo

# Run installation
bash deploy/install.sh
```

### Step 3: Verify

```bash
# Check timer
systemctl status smart-experiment.timer

# Check nginx
systemctl status nginx
curl http://localhost/

# Run experiment manually
sudo -u smart /opt/smart/bin/agent.sh

# View logs
tail -f /opt/smart/var/experiment.log
```

## Configuration

### Environment Variables

Set these before installation or in `/opt/smart/smart.conf`:

```bash
# Optional: Phone-home coaching
export COACH_URL="https://your-api.com/coach"
export COACH_TOKEN="your-secret-token"

# Adjust experiment parameters
export BASELINE_SECONDS=300
export EXPERIMENT_SECONDS=300
export IMPROVE_PCT=10
export MAX_ERR_DELTA_PCT=2
```

### Experiment Schedule

By default, experiments run every 30 minutes. To change:

```bash
# Edit the timer
sudo systemctl edit smart-experiment.timer

# Add this under [Timer]:
[Timer]
OnCalendar=*:0/60  # Every hour instead

# Reload
sudo systemctl daemon-reload
sudo systemctl restart smart-experiment.timer
```

## Firewall Setup

The install script sets up UFW with these rules:

```bash
# Allow SSH, HTTP, HTTPS
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

For additional security:

```bash
# Restrict SSH to specific IP
ufw delete allow 22/tcp
ufw allow from <your-ip> to any port 22

# Or use Hetzner Cloud Firewall (recommended)
hcloud firewall create --name smart-server-fw
hcloud firewall add-rule smart-server-fw \
  --direction in \
  --protocol tcp \
  --port 22 \
  --source-ips <your-ip>/32
hcloud firewall apply-to-resource smart-server-fw \
  --type server \
  --server smart-server-01
```

## SSL/HTTPS Setup (Optional)

To add HTTPS with Let's Encrypt:

```bash
# Install certbot
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Get certificate (requires domain pointing to server)
certbot --nginx -d yourdomain.com

# Auto-renewal is set up automatically
```

Update nginx config at `/etc/nginx/sites-available/smart-server`:

```nginx
server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # ... rest of config
}
```

## Monitoring

### Check Experiment Status

```bash
# View timer status
systemctl list-timers smart-experiment.timer

# View logs
journalctl -u smart-experiment.service -f

# View experiment logs
tail -f /opt/smart/var/experiment.log

# View latest run
ls -ltr /opt/smart/var/runs/ | tail -1
cat /opt/smart/var/runs/<latest-run>/run.log
```

### Dashboard Access

The dashboard is available at:
- HTTP: `http://<server-ip>`
- Direct state: `http://<server-ip>/state.json`
- Run logs: `http://<server-ip>/runs/`

## Troubleshooting

### Experiments Not Running

```bash
# Check timer is enabled
systemctl status smart-experiment.timer

# Check for errors
journalctl -u smart-experiment.service --since "1 hour ago"

# Run manually to see errors
sudo -u smart /opt/smart/bin/agent.sh
```

### Nginx Issues

```bash
# Test config
sudo nginx -t

# Check status
systemctl status nginx

# View error log
tail -f /var/log/nginx/error.log
```

### Permission Issues

```bash
# Ensure smart user owns files
chown -R smart:smart /opt/smart

# Check sudoers config
cat /etc/sudoers.d/smart-server

# Test sudo access
sudo -u smart sudo nginx -t
```

### Dashboard Not Loading

```bash
# Check if state.json exists
ls -la /opt/smart/var/state.json

# Run an experiment to generate state
sudo -u smart /opt/smart/bin/agent.sh

# Check nginx serving files
curl http://localhost/
curl http://localhost/state.json
```

## Upgrading

To update the smart server code:

```bash
# SSH into server
ssh root@<server-ip>

# Pull latest changes
cd /opt/smart-repo
git pull

# Re-run installation
bash deploy/install.sh

# Restart timer
systemctl restart smart-experiment.timer
```

## Cost Estimation

**Hetzner CX11** (smallest suitable instance):
- 1 vCPU
- 2 GB RAM
- 20 GB SSD
- **€3.29/month** (~$3.50 USD)

**Data Transfer**: 20 TB included

**Total**: ~$4/month for a fully automated, self-adapting server.

## Scaling Up

For production or high-traffic sites:

1. **Upgrade instance**:
   ```bash
   hcloud server change-type smart-server-01 cx21 --upgrade-disk
   ```

2. **Add monitoring** (Prometheus, Grafana)
3. **Add more experiments** in `/opt/smart/experiments/`
4. **Implement experiment queue** to rotate through multiple tests
5. **Add alerting** (Slack, Discord, PagerDuty)

## Next Steps

After deployment:

1. ✅ Access dashboard at `http://<server-ip>`
2. ✅ Wait for first experiment to run (30 min by default)
3. ✅ Review results in dashboard and `/opt/smart/var/runs/`
4. ✅ Add more experiments in `/opt/smart/experiments/`
5. ✅ Optionally set up phone-home coaching endpoint
6. ✅ Configure alerts and monitoring

---

**Questions or issues?** Check the main README.md or open an issue on GitHub.

