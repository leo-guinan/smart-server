# Quick Start Guide

Get your Smart Server running in under 10 minutes.

## Local Testing (Mac/Linux)

```bash
# 1. Clone and navigate
git clone <your-repo>
cd smart_server

# 2. Make scripts executable (already done, but just in case)
chmod +x bin/*.sh experiments/*/[!m]*.sh scripts/*.sh

# 3. Validate setup
bash scripts/validate.sh

# 4. Run local test (creates test server, runs short experiment)
bash scripts/test-local.sh

# 5. View results
cat var/state.json | jq .
open www/index.html  # or use your browser
```

## Deploy to Hetzner (5 minutes)

### Prerequisites
- Hetzner account
- `hcloud` CLI: `brew install hcloud` (Mac) or see [docs](https://community.hetzner.com/tutorials/howto-hcloud-cli)
- SSH key added to Hetzner

### Steps

```bash
# 1. Login to Hetzner
hcloud context create smart-server
# Enter your API token from Hetzner Cloud Console

# 2. Add your SSH key (if not already done)
hcloud ssh-key create --name my-key --public-key-from-file ~/.ssh/id_rsa.pub

# 3. Update cloud-init with your repo
# Edit deploy/hetzner-cloud-init.yaml:
# Replace: YOUR_USERNAME/smart_server
# With: yourusername/yourrepo

# 4. Create server
hcloud server create \
  --name smart-server-01 \
  --type cx11 \
  --image ubuntu-22.04 \
  --location nbg1 \
  --ssh-key my-key \
  --user-data-from-file deploy/hetzner-cloud-init.yaml

# 5. Get server IP
hcloud server ip smart-server-01

# 6. Wait 3-5 minutes for installation, then open browser
# http://<server-ip>
```

## First Experiment

After deployment, your server will automatically:
- ✅ Run experiments every 30 minutes
- ✅ Test nginx worker configurations
- ✅ Measure latency and error rates
- ✅ Keep improvements, revert failures
- ✅ Update the dashboard

## Check Status

```bash
# SSH into server
ssh root@<server-ip>

# View experiment status
systemctl status smart-experiment.timer

# View logs
tail -f /opt/smart/var/experiment.log

# Run experiment manually
sudo -u smart /opt/smart/bin/agent.sh

# View results
cat /opt/smart/var/state.json | jq .
```

## View Dashboard

Open in browser:
- Main dashboard: `http://<server-ip>/`
- Current state: `http://<server-ip>/state.json`
- Run logs: `http://<server-ip>/runs/`

Dashboard shows:
- Current experiment name
- Baseline vs variant metrics
- Decision (keep/revert)
- Improvement percentages
- Auto-refreshes every 30s

## Add Your Own Experiment

```bash
# 1. SSH into server
ssh root@<server-ip>

# 2. Create new experiment
cd /opt/smart/experiments
cp -r 001_nginx_workers 002_my_experiment

# 3. Edit meta.json with your test
nano 002_my_experiment/meta.json

# 4. Update apply.sh, revert.sh, measure.sh as needed

# 5. Run it
sudo -u smart /opt/smart/bin/agent.sh /opt/smart/experiments/002_my_experiment
```

## Troubleshooting

**Dashboard not loading?**
```bash
# Check nginx
systemctl status nginx
curl http://localhost/

# Run experiment to generate state
sudo -u smart /opt/smart/bin/agent.sh
```

**Experiments not running?**
```bash
# Check timer
systemctl list-timers smart-experiment.timer

# View errors
journalctl -u smart-experiment.service -f
```

**Permission errors?**
```bash
# Fix ownership
chown -R smart:smart /opt/smart

# Check sudoers
cat /etc/sudoers.d/smart-server
```

## Configuration

Edit `/opt/smart/smart.conf`:

```bash
# Experiment timing
BASELINE_SECONDS=300          # 5 minutes baseline
EXPERIMENT_SECONDS=300        # 5 minutes per variant
COOLDOWN_SECONDS=60           # 1 minute between

# Decision thresholds
IMPROVE_PCT=10                # Need 10% improvement
MAX_ERR_DELTA_PCT=2           # Allow max 2% error increase

# Phone-home (optional)
COACH_URL="https://your-api/coach"
COACH_TOKEN="secret"
```

## Next Steps

1. **Monitor first experiment** - Wait 30 min or run manually
2. **Review results** - Check dashboard and logs
3. **Add more experiments** - Test different configurations
4. **Set up phone-home** - Get AI coaching for decisions
5. **Enable HTTPS** - Use certbot for SSL

## Full Documentation

- [README.md](README.md) - Complete feature documentation
- [DEPLOYMENT.md](DEPLOYMENT.md) - Detailed deployment guide
- [context.md](context.md) - Current experiments and goals

## Cost

Running on Hetzner CX11:
- **~$3.50/month** for 24/7 self-adapting server
- Includes 20TB transfer
- Scale up anytime with `hcloud server change-type`

---

**That's it!** Your server is now running experiments and optimizing itself. 🚀

