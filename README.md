# Smart Server 🧪

A self-adapting experiment server that runs automated performance tests, makes decisions based on data, and optionally phones home for coaching.

## What It Does

- **Runs automated experiments** on server configurations (nginx workers, cache settings, etc.)
- **Measures performance** (latency, error rates) with baseline vs. variant comparisons
- **Makes autonomous decisions** using shell-based decision logic
- **Hosts its own dashboard** showing experiment results in real-time
- **Phones home** (optionally) to request coaching when uncertain
- **Zero heavy dependencies** - just bash, jq, curl, and your web server

## Architecture

```
/opt/smart/
├── smart.conf              # Configuration (thresholds, timing, coach URL)
├── context.md              # What/why for current experiments
├── bin/
│   ├── agent.sh            # Main orchestrator
│   ├── decide.sh           # Decision engine (keep/revert logic)
│   ├── phone_home.sh       # Optional remote coaching
│   └── update_dashboard.sh # Dashboard generator
├── experiments/
│   └── 001_nginx_workers/
│       ├── meta.json       # Experiment definition
│       ├── apply.sh        # Apply variant
│       ├── revert.sh       # Revert to baseline
│       └── measure.sh      # Collect metrics
├── var/
│   ├── runs/               # Historical run data
│   └── state.json          # Latest experiment state
└── www/
    └── index.html          # Self-serve dashboard
```

## Quick Start

### Local Development/Testing

1. **Clone and explore**:
   ```bash
   git clone <repo>
   cd smart_server
   ```

2. **Review configuration**:
   ```bash
   cat smart.conf
   # Adjust BASELINE_SECONDS, EXPERIMENT_SECONDS, thresholds as needed
   ```

3. **Run a test experiment** (requires nginx installed):
   ```bash
   # Make scripts executable
   chmod +x bin/*.sh
   chmod +x experiments/001_nginx_workers/*.sh
   
   # Run once
   BASE_DIR=$(pwd) bash bin/agent.sh
   ```

4. **View results**:
   - Check `var/runs/<run_id>/` for CSV data and logs
   - Open `www/index.html` in a browser (serve with `python3 -m http.server`)

### Production Deployment (Hetzner)

#### Option 1: Cloud-Init (Automated)

1. **Update the cloud-init file**:
   Edit `deploy/hetzner-cloud-init.yaml` and replace `YOUR_USERNAME` with your GitHub username.

2. **Create server with Hetzner CLI**:
   ```bash
   hcloud server create \
     --name smart-server-01 \
     --type cx11 \
     --image ubuntu-22.04 \
     --ssh-key <your-key-name> \
     --user-data-from-file deploy/hetzner-cloud-init.yaml
   ```

3. **Access your server**:
   ```bash
   # Get IP
   hcloud server describe smart-server-01
   
   # SSH in
   ssh root@<server-ip>
   
   # Check installation
   systemctl status smart-experiment.timer
   ```

4. **View dashboard**:
   Open `http://<server-ip>` in your browser.

#### Option 2: Manual Installation

1. **Create a Hetzner server** (Ubuntu 22.04 recommended)

2. **SSH into the server**:
   ```bash
   ssh root@<server-ip>
   ```

3. **Clone repository**:
   ```bash
   git clone <your-repo-url> /opt/smart-repo
   cd /opt/smart-repo
   ```

4. **Run installation script**:
   ```bash
   bash deploy/install.sh
   ```

5. **Verify installation**:
   ```bash
   systemctl status smart-experiment.timer
   curl http://localhost/
   ```

## Configuration

### Experiment Thresholds

Edit `/opt/smart/smart.conf`:

```bash
BASELINE_SECONDS=300          # How long to measure baseline
EXPERIMENT_SECONDS=300        # How long to test each variant
COOLDOWN_SECONDS=60           # Pause between variants

IMPROVE_PCT=10                # Minimum improvement to keep (%)
MAX_ERR_DELTA_PCT=2           # Maximum error rate increase (%)
```

### Phone-Home Coaching

To enable remote coaching:

```bash
export COACH_URL="https://your-coach-api.com/smart/advise"
export COACH_TOKEN="your-secret-token"
```

The server will POST experiment results and receive advice.

## How Decisions Work

For each experiment:

1. **Baseline**: Measure current performance (p50 latency, 5xx rate)
2. **Variant**: Apply change and measure again
3. **Compare**: Calculate improvement percentage and error delta
4. **Decide**:
   - ✓ **KEEP** if: latency improves ≥10% AND errors don't increase >2%
   - ✗ **REVERT** otherwise
5. **Update**: Refresh dashboard with results

## Creating New Experiments

1. **Create experiment directory**:
   ```bash
   mkdir -p experiments/002_cache_ttl
   ```

2. **Write meta.json**:
   ```json
   {
     "id": "002_cache_ttl",
     "description": "Test different cache TTL values",
     "variants": [
       {"name": "baseline", "apply": "true"},
       {"name": "ttl_3600", "apply": "your-command-here"}
     ],
     "revert": "revert-command",
     "target_url": "http://127.0.0.1/",
     "measure_interval_sec": 5
   }
   ```

3. **Create scripts**:
   ```bash
   cp experiments/001_nginx_workers/*.sh experiments/002_cache_ttl/
   # Edit apply.sh, revert.sh, measure.sh as needed
   ```

4. **Run it**:
   ```bash
   sudo -u smart /opt/smart/bin/agent.sh /opt/smart/experiments/002_cache_ttl
   ```

## Monitoring

### View Logs
```bash
tail -f /opt/smart/var/experiment.log
```

### Check Timer Status
```bash
systemctl status smart-experiment.timer
systemctl list-timers smart-experiment.timer
```

### Manual Run
```bash
sudo -u smart /opt/smart/bin/agent.sh
```

### View Historical Data
```bash
ls -la /opt/smart/var/runs/
cat /opt/smart/var/runs/<run-id>/run.log
```

## Dashboard Features

The self-serve dashboard (`/`) shows:

- Current experiment name and run ID
- Which variant was kept (if any)
- Baseline vs. variant metrics:
  - p50 latency
  - 5xx error rate
- Decision logic output (keep/revert + percentages)
- Auto-refreshes every 30 seconds

## Security Notes

- Smart server runs as limited `smart` user
- Sudoers configured for only specific nginx commands
- No external dependencies beyond basic system tools
- All experiment changes are logged
- Revert on any uncertainty

## Roadmap

- [ ] Local small model integration (ollama/llama.cpp) for decision coaching
- [ ] Multi-experiment queue scheduling
- [ ] A/B testing with traffic splitting
- [ ] Anomaly detection for automatic rollback
- [ ] Historical trend analysis
- [ ] Slack/Discord notifications

## License

MIT

## Contributing

PRs welcome! Focus areas:
- New experiment templates
- Better decision algorithms
- Additional measurement sources
- Dashboard improvements

