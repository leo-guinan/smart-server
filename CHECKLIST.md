# Smart Server - Pre-Deployment Checklist

## 📋 Before First Deploy

### Required Changes
- [ ] **Update `deploy/hetzner-cloud-init.yaml`**
  - Replace `YOUR_USERNAME/smart_server` with your actual GitHub repo URL
  - Line 21: `git clone https://github.com/YOUR_USERNAME/smart_server.git`

### Optional Configuration
- [ ] **Set phone-home coaching URL** (if using remote coaching)
  - Edit `smart.conf` or set environment variables:
    ```bash
    export COACH_URL="https://your-api.com/coach"
    export COACH_TOKEN="your-secret-token"
    ```

- [ ] **Adjust experiment timing** (optional)
  - Edit `smart.conf`:
    - `BASELINE_SECONDS` - How long to measure baseline (default: 300s)
    - `EXPERIMENT_SECONDS` - How long per variant (default: 300s)
    - `COOLDOWN_SECONDS` - Pause between variants (default: 60s)

- [ ] **Adjust decision thresholds** (optional)
  - `IMPROVE_PCT` - Minimum improvement to keep (default: 10%)
  - `MAX_ERR_DELTA_PCT` - Maximum error increase allowed (default: 2%)

### Pre-Flight Validation
- [ ] **Run local validation**
  ```bash
  bash scripts/validate.sh
  ```
  Expected: ✓ Validation passed!

- [ ] **Test locally** (optional, requires nginx or creates test server)
  ```bash
  bash scripts/test-local.sh
  ```

- [ ] **Commit and push to git**
  ```bash
  git init
  git add .
  git commit -m "Initial smart server setup"
  git remote add origin <your-repo-url>
  git push -u origin main
  ```

## 🚀 Deployment Steps

### 1. Hetzner Setup
- [ ] **Hetzner account created**
- [ ] **API token generated** (Hetzner Cloud Console → Security → API Tokens)
- [ ] **SSH key added to Hetzner**

### 2. Install Hetzner CLI (if using automated deployment)
```bash
# macOS
brew install hcloud

# Linux
wget https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz
tar xzf hcloud-linux-amd64.tar.gz
sudo mv hcloud /usr/local/bin/
```

### 3. Configure Hetzner CLI
```bash
hcloud context create smart-server
# Paste your API token when prompted
```

### 4. Create Server
```bash
# Add your SSH key (if not already done)
hcloud ssh-key create --name my-key --public-key-from-file ~/.ssh/id_rsa.pub

# Create server with cloud-init
hcloud server create \
  --name smart-server-01 \
  --type cx11 \
  --image ubuntu-22.04 \
  --location nbg1 \
  --ssh-key my-key \
  --user-data-from-file deploy/hetzner-cloud-init.yaml

# Wait 3-5 minutes for installation...
```

### 5. Get Server IP
```bash
hcloud server ip smart-server-01
# Or
hcloud server describe smart-server-01
```

### 6. Verify Installation
```bash
# SSH into server
ssh root@<server-ip>

# Check installation
systemctl status smart-experiment.timer
systemctl status nginx

# View logs
tail -f /opt/smart/var/experiment.log

# Check dashboard files
ls -la /opt/smart/www/
cat /opt/smart/var/state.json
```

### 7. Access Dashboard
- [ ] Open browser to `http://<server-ip>`
- [ ] Verify dashboard loads
- [ ] Wait for first experiment (30 min) or run manually:
  ```bash
  sudo -u smart /opt/smart/bin/agent.sh
  ```

## ✅ Post-Deployment Verification

### Automated Tests
- [ ] Dashboard loads successfully
- [ ] State JSON endpoint works: `http://<server-ip>/state.json`
- [ ] First experiment runs without errors
- [ ] Decision is made (keep or revert)
- [ ] Dashboard updates with results
- [ ] Timer is running: `systemctl list-timers smart-experiment.timer`

### Manual Checks
- [ ] Nginx is running: `systemctl status nginx`
- [ ] Smart user exists: `id smart`
- [ ] Sudoers configured: `cat /etc/sudoers.d/smart-server`
- [ ] Firewall active: `ufw status`
- [ ] Logs rotating: Check `/opt/smart/var/experiment.log` size

## 🔒 Security Hardening (Post-Deploy)

### Immediate
- [ ] **Disable password authentication** (SSH keys only)
  ```bash
  sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart ssh
  ```

- [ ] **Enable fail2ban** (optional but recommended)
  ```bash
  apt-get install -y fail2ban
  systemctl enable fail2ban
  systemctl start fail2ban
  ```

### Within First Week
- [ ] **Set up HTTPS** (if using domain)
  ```bash
  apt-get install -y certbot python3-certbot-nginx
  certbot --nginx -d yourdomain.com
  ```

- [ ] **Configure firewall for specific IPs** (optional)
  ```bash
  # Restrict SSH to your IP
  ufw delete allow 22
  ufw allow from <your-ip> to any port 22
  ufw reload
  ```

- [ ] **Set up monitoring** (optional)
  - Add health check endpoint
  - Configure alerts (Slack, Discord, email)
  - Set up uptime monitoring (UptimeRobot, etc.)

## 📊 Monitoring Setup

### Log Rotation
- [ ] Configure logrotate
  ```bash
  cat > /etc/logrotate.d/smart-server <<EOF
  /opt/smart/var/experiment.log {
      daily
      rotate 7
      compress
      delaycompress
      missingok
      notifempty
  }
  EOF
  ```

### Cleanup Old Runs
- [ ] Add cleanup cron job
  ```bash
  echo "0 2 * * * find /opt/smart/var/runs -type d -mtime +30 -exec rm -rf {} \;" | crontab -
  ```

## 🧪 First Experiment

### Default Experiment (nginx workers)
- [ ] Waits for timer (30 min) or run manually
- [ ] Tests: baseline, workers=auto, workers=2, workers=4
- [ ] Measures: p50 latency, 5xx error rate
- [ ] Decides: keep if ≥10% improvement, ≤2% error increase
- [ ] Updates dashboard with results

### View Results
```bash
# Latest run
ls -ltr /opt/smart/var/runs/ | tail -1

# Run log
cat /opt/smart/var/runs/<run-id>/run.log

# Metrics
cat /opt/smart/var/runs/<run-id>/baseline.csv
cat /opt/smart/var/runs/<run-id>/*_decision.log

# Current state
cat /opt/smart/var/state.json | jq .
```

## 🔧 Troubleshooting

### Dashboard Blank
```bash
# Generate state by running experiment
sudo -u smart /opt/smart/bin/agent.sh

# Check nginx
systemctl status nginx
curl http://localhost/
```

### Experiments Not Running
```bash
# Check timer
systemctl status smart-experiment.timer
systemctl list-timers

# View service logs
journalctl -u smart-experiment.service -f

# Run manually with debug
bash -x /opt/smart/bin/agent.sh
```

### Permission Errors
```bash
# Fix ownership
chown -R smart:smart /opt/smart

# Check sudoers
sudo -u smart sudo nginx -t
```

## 📈 Success Metrics

After first week:
- [ ] At least 3 experiments completed
- [ ] No critical errors in logs
- [ ] Dashboard accessible 24/7
- [ ] At least 1 improvement kept
- [ ] Server stable and responsive

## 🎯 Next Steps

After successful deployment:
1. [ ] Review first experiment results
2. [ ] Adjust thresholds if needed
3. [ ] Add more experiments (see `experiments/` for template)
4. [ ] Set up monitoring/alerting
5. [ ] Document learnings in `context.md`

## 📚 Documentation Reference

- Quick start: `QUICKSTART.md`
- Full deployment: `DEPLOYMENT.md`
- Architecture: `ARCHITECTURE.md`
- Roadmap: `TODO.md`
- Implementation notes: `NOTES.md`
- Project summary: `SUMMARY.md`

---

**Status**: ⏳ Ready for first deployment  
**Blockers**: Need to update cloud-init.yaml with real repo URL  
**Risk Level**: Low (can always rebuild server)

