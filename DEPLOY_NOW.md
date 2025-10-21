# Deploy to Hetzner Server

**Server IP**: 178.156.207.21  
**GitHub Repo**: https://github.com/leo-guinan/smart-server.git

## Step-by-Step Deployment

### 1. Push Code to GitHub ✅

```bash
# Initialize git (if not already done)
git init
git add .
git commit -m "Initial smart server setup"

# Add remote and push
git remote add origin git@github.com:leo-guinan/smart-server.git
git branch -M main
git push -u origin main
```

### 2. SSH into Your Server

```bash
ssh root@178.156.207.21
```

### 3. Run Installation

Once on the server:

```bash
# Clone repository
git clone https://github.com/leo-guinan/smart-server.git /opt/smart-repo
cd /opt/smart-repo

# Run installation script
bash deploy/install.sh

# Verify installation
systemctl status smart-experiment.timer
systemctl status nginx
```

### 4. Access Dashboard

Open in browser:
- **Dashboard**: http://178.156.207.21
- **State JSON**: http://178.156.207.21/state.json

### 5. Run First Experiment (Optional - Timer will run automatically)

```bash
# On the server
sudo -u smart /opt/smart/bin/agent.sh

# Watch it run
tail -f /opt/smart/var/experiment.log
```

### 6. Verify Results

```bash
# Check state
cat /opt/smart/var/state.json | jq .

# View latest run
ls -ltr /opt/smart/var/runs/ | tail -1

# Check logs
cat /opt/smart/var/runs/<run-id>/run.log
```

## Troubleshooting

### If installation fails:
```bash
# Check installation logs
tail -f /var/log/cloud-init-output.log

# Or re-run manually
cd /opt/smart-repo
bash deploy/install.sh
```

### If dashboard doesn't load:
```bash
# Check nginx
systemctl status nginx
curl http://localhost/

# Run experiment to generate state
sudo -u smart /opt/smart/bin/agent.sh
```

## Next Steps

1. ✅ Push to GitHub
2. ✅ SSH into server
3. ✅ Run installation
4. ✅ Access dashboard
5. ✅ Run first experiment
6. Monitor for 24 hours
7. Add more experiments

---

**You're ready to deploy!** 🚀

