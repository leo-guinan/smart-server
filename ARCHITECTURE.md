# Smart Server Architecture

## Overview

The Smart Server is a self-adapting system that runs experiments, measures performance, makes autonomous decisions, and phones home for coaching when needed. It's built entirely with shell scripts, standard Unix tools, and minimal dependencies.

## Design Principles

1. **Shell-First** - Use bash as the primary orchestration language
2. **Minimal Dependencies** - Only jq, curl, and a web server required
3. **Self-Contained** - Server hosts its own dashboard and state
4. **Fail-Safe** - Always revert on uncertainty or errors
5. **Observable** - All decisions logged and visible
6. **Extensible** - Easy to add new experiments

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Smart Server                        │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐         ┌──────────────┐              │
│  │   Systemd    │────────▶│  agent.sh    │              │
│  │    Timer     │         │ (Orchestrator)│              │
│  │ (every 30min)│         └───────┬───────┘              │
│  └──────────────┘                 │                      │
│                                   │                      │
│         ┌─────────────────────────┼──────────────┐       │
│         ▼                         ▼              ▼       │
│  ┌──────────────┐         ┌──────────────┐ ┌─────────┐  │
│  │ Experiment   │         │  decide.sh   │ │phone_   │  │
│  │   Runner     │────────▶│  (Decision   │ │home.sh  │  │
│  │              │         │   Engine)    │ │         │  │
│  │ • apply.sh   │         └──────┬───────┘ └────┬────┘  │
│  │ • measure.sh │                │              │       │
│  │ • revert.sh  │                │              │       │
│  └──────────────┘                │              │       │
│         │                        │              │       │
│         ▼                        ▼              ▼       │
│  ┌──────────────────────────────────────────────────┐   │
│  │          update_dashboard.sh                     │   │
│  │  (Updates state.json + HTML dashboard)           │   │
│  └──────────────────────────────────────────────────┘   │
│         │                                                │
│         ▼                                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │               Nginx Web Server                   │   │
│  │  Serves: dashboard, state.json, run logs         │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
└─────────────────────────────────────────────────────────┘
                           │
                           │ HTTP
                           ▼
                    ┌─────────────┐
                    │   Browser   │
                    │  Dashboard  │
                    └─────────────┘

                           │ HTTPS (optional)
                           ▼
                    ┌─────────────┐
                    │   Coach     │
                    │     API     │
                    └─────────────┘
```

## Core Components

### 1. Orchestrator (`bin/agent.sh`)

**Purpose**: Main control loop that coordinates experiments

**Flow**:
1. Load configuration from `smart.conf`
2. Read experiment metadata (`meta.json`)
3. Run baseline measurement
4. Iterate through variants:
   - Apply variant configuration
   - Wait for cooldown
   - Measure performance
   - Evaluate with `decide.sh`
   - Keep or revert based on decision
5. Update dashboard
6. Phone home (if configured)

**Key Features**:
- Logs all actions to run log
- Handles errors gracefully
- Can run specific experiments on demand
- Generates unique run IDs

### 2. Decision Engine (`bin/decide.sh`)

**Purpose**: Autonomous decision-making based on metrics

**Inputs**:
- Baseline CSV (timestamp, latency_ms, response_code)
- Variant CSV (same format)
- Thresholds from environment

**Calculations**:
- **p50 latency** - Median response time
- **Error rate** - Percentage of 5xx responses
- **Improvement %** - (baseline - variant) / baseline * 100
- **Error delta** - variant_errors - baseline_errors

**Decision Logic**:
```bash
if improve_pct >= IMPROVE_PCT 
   AND err_delta <= MAX_ERR_DELTA_PCT
then
  echo "keep"
else
  echo "revert"
fi
```

**Outputs**:
- "keep" or "revert" to stdout
- Detailed metrics to stderr (logged)

### 3. Measurement System (`measure.sh`)

**Purpose**: Collect performance data for analysis

**Process**:
1. Read target URL from `meta.json`
2. Make repeated HTTP requests
3. Measure latency and response codes
4. Write to CSV: `timestamp,latency_ms,response_code`
5. Continue for specified duration

**Configurable**:
- Duration (seconds)
- Interval between probes
- Target URL
- Output file

### 4. Experiment Definition (`meta.json`)

**Structure**:
```json
{
  "id": "experiment_name",
  "description": "What this tests",
  "variants": [
    {"name": "baseline", "apply": "true"},
    {"name": "variant1", "apply": "command to apply"}
  ],
  "revert": "command to revert",
  "target_url": "http://localhost/",
  "measure_interval_sec": 5
}
```

**Scripts**:
- `apply.sh` - Applies configuration changes
- `revert.sh` - Reverts to baseline
- `measure.sh` - Collects metrics

### 5. Dashboard System

**Components**:

**State JSON** (`var/state.json`):
```json
{
  "run_id": "20250121T143022",
  "experiment": "001_nginx_workers",
  "kept_variant": "workers_auto",
  "metrics": {
    "base_p50_ms": 45.2,
    "var_p50_ms": 38.1,
    "base_err_pct": 0.0,
    "var_err_pct": 0.0
  },
  "updated_at": "2025-01-21T14:35:22Z"
}
```

**HTML Dashboard** (`www/index.html`):
- Pure HTML/CSS/JS - no frameworks
- Auto-refreshes every 30 seconds
- Fetches `/state.json` via AJAX
- Displays metrics and decision
- Dark mode UI

**Nginx Configuration**:
- Serves static dashboard
- Proxies state.json (no-cache)
- Provides directory listing for run logs

### 6. Phone-Home System (`phone_home.sh`)

**Purpose**: Optional remote coaching for decision assistance

**When to Use**:
- Borderline decisions (e.g., 8% improvement vs 10% threshold)
- Unusual patterns detected
- Request human/AI guidance

**Request Payload**:
```json
{
  "run_id": "...",
  "state": { /* current state */ },
  "server_id": "hostname"
}
```

**Response** (future):
```json
{
  "advice": "Try workers=auto; monitor for 24h",
  "next_variant": "workers_auto",
  "confidence": 0.85
}
```

## Data Flow

### Experiment Run Cycle

```
1. TRIGGER (systemd timer or manual)
   │
   ├─▶ Load smart.conf
   │
2. BASELINE MEASUREMENT
   │
   ├─▶ Apply baseline variant
   ├─▶ Run measure.sh for BASELINE_SECONDS
   ├─▶ Save to baseline.csv
   │
3. VARIANT TESTING (loop)
   │
   ├─▶ Apply variant configuration
   ├─▶ Cooldown period
   ├─▶ Run measure.sh for EXPERIMENT_SECONDS
   ├─▶ Save to variant.csv
   │
4. DECISION
   │
   ├─▶ Run decide.sh with baseline + variant CSVs
   ├─▶ Calculate metrics
   ├─▶ Output: keep or revert
   │
5. APPLY DECISION
   │
   ├─▶ If keep: note variant and break loop
   ├─▶ If revert: run revert.sh, continue to next variant
   │
6. UPDATE DASHBOARD
   │
   ├─▶ Generate state.json
   ├─▶ Update HTML (if needed)
   │
7. PHONE HOME (optional)
   │
   └─▶ POST results to coach API
```

### File System Layout

```
/opt/smart/
├── smart.conf                # Global configuration
├── context.md                # Human-readable context
│
├── bin/                      # Executables
│   ├── agent.sh              # Main orchestrator
│   ├── decide.sh             # Decision logic
│   ├── phone_home.sh         # Remote coaching
│   └── update_dashboard.sh   # Dashboard generator
│
├── experiments/              # Experiment definitions
│   └── 001_nginx_workers/
│       ├── meta.json         # Experiment config
│       ├── apply.sh          # Apply changes
│       ├── revert.sh         # Revert changes
│       └── measure.sh        # Collect metrics
│
├── var/                      # Runtime data
│   ├── runs/                 # Historical runs
│   │   └── 20250121T143022/
│   │       ├── baseline.csv
│   │       ├── workers_auto.csv
│   │       ├── workers_2.csv
│   │       ├── workers_auto_decision.log
│   │       └── run.log
│   └── state.json            # Latest state
│
└── www/                      # Web dashboard
    └── index.html            # Self-serve UI
```

## Security Model

### User Isolation

- Service runs as dedicated `smart` user
- No root access except via sudoers
- Home directory: `/opt/smart`

### Sudoers Configuration

Only specific commands allowed without password:
```
smart ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
smart ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
smart ALL=(ALL) NOPASSWD: /bin/sed -i* * /etc/nginx/nginx.conf
```

### Network Security

- UFW firewall: only 22, 80, 443
- Optional: IP allowlisting for SSH
- HTTPS available via Let's Encrypt
- Phone-home uses bearer token auth

### Experiment Safety

- All changes logged before execution
- Automatic revert on errors
- Time-boxed experiments (never infinite)
- Config backups created (.bak files)

## Extensibility

### Adding New Experiments

1. Create directory: `experiments/XXX_name/`
2. Write `meta.json` with variants
3. Implement `apply.sh`, `revert.sh`, `measure.sh`
4. Test manually: `agent.sh /opt/smart/experiments/XXX_name`
5. Add to rotation or schedule

### Custom Decision Logic

Override `decide.sh` with custom algorithms:
- Machine learning models (local)
- Statistical analysis (R, Python via shell)
- External API calls
- Multi-metric optimization

### Integration Points

**Pre-run hooks**: Execute before experiment
**Post-run hooks**: Execute after decision
**Custom metrics**: Extend measure.sh for app-specific data
**Alerting**: Add to `update_dashboard.sh`

## Performance Characteristics

### Resource Usage

- **CPU**: Minimal (~1% during idle, 5-10% during runs)
- **Memory**: <50MB for scripts
- **Disk**: ~1MB per run (CSV logs)
- **Network**: Minimal (local probes + optional phone-home)

### Timing

- Baseline: 5 minutes (configurable)
- Per variant: 5 minutes (configurable)
- Cooldown: 1 minute (configurable)
- Total per experiment: ~15-30 minutes

### Scalability

- Runs on minimal hardware (CX11: 1 vCPU, 2GB RAM)
- Can test multiple servers in parallel
- Handles hundreds of experiments per day
- Logs rotate automatically (TODO)

## Future Enhancements

### Phase 2: Local AI

- Integrate ollama or llama.cpp
- Local decision coaching
- Pattern recognition across runs
- Anomaly detection

### Phase 3: Multi-Server

- Coordinate experiments across fleet
- Canary deployments
- A/B testing with traffic splitting
- Distributed measurements

### Phase 4: Advanced Analytics

- Trend analysis
- Predictive modeling
- Cost-benefit optimization
- Automated experiment generation

## Troubleshooting Guide

### Common Issues

**Experiments not running**:
- Check `systemctl status smart-experiment.timer`
- Verify permissions: `ls -la /opt/smart`
- Review logs: `journalctl -u smart-experiment.service`

**Dashboard blank**:
- Run experiment: `sudo -u smart /opt/smart/bin/agent.sh`
- Check nginx: `systemctl status nginx`
- Verify state: `cat /opt/smart/var/state.json`

**Permission denied**:
- Fix ownership: `chown -R smart:smart /opt/smart`
- Check sudoers: `cat /etc/sudoers.d/smart-server`

**Decisions always revert**:
- Lower thresholds in `smart.conf`
- Check if measurements are collecting data
- Review decision logs in run directory

## References

- [README.md](README.md) - User-facing documentation
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment guide
- [QUICKSTART.md](QUICKSTART.md) - Fast setup
- [context.md](context.md) - Current experiments

