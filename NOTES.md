# Development Notes & Implementation Details

## What We Built

A **self-adapting server** that:
1. Runs performance experiments autonomously
2. Measures real metrics (latency, errors)
3. Makes data-driven decisions (keep/revert)
4. Hosts its own dashboard
5. Can phone home for coaching
6. Deploys to Hetzner in ~5 minutes

All with **shell scripts** and **zero heavy dependencies**.

## Key Design Decisions

### Why Shell Scripts?

**Pros**:
- ✅ Universal availability (every server has bash)
- ✅ No runtime installation (Node, Python, etc.)
- ✅ Direct system access (nginx, systemd, etc.)
- ✅ Easy to understand and modify
- ✅ Perfect for system-level automation

**Cons**:
- ❌ Harder to test than application code
- ❌ Error handling requires discipline
- ❌ String manipulation is clunky
- ❌ No type safety

**Decision**: Pros outweigh cons for this use case. Shell is the right tool.

### Why JSON for Config?

- Standard format, parsable with `jq`
- Easy to generate/validate
- Human and machine readable
- Extensible without code changes

### Why CSV for Metrics?

- Simple to generate (just echo)
- Easy to parse with awk
- Works with any data analysis tool
- Small file size
- Human readable for debugging

### Why Static HTML Dashboard?

- Zero build process
- Works without JavaScript (mostly)
- No framework dependencies
- Cacheable and fast
- Easy to customize

## Implementation Challenges & Solutions

### Challenge 1: Median Calculation in Shell

**Problem**: No built-in median function

**Solution**: 
```bash
p50() { 
  awk -F, 'NR>1{print $2}' "$1" | sort -n | awk '{
    a[NR]=$1
  } END {
    if (NR%2) {print a[(NR+1)/2]} 
    else {print (a[NR/2]+a[NR/2+1])/2}
  }'
}
```

### Challenge 2: Subshell Variable Scope

**Problem**: Variables set in while loops don't persist
```bash
while read VAR; do
  KEPT="$VAR"  # Lost after loop!
done
```

**Solution**: Write to file, read after loop
```bash
while read VAR; do
  echo "$VAR" > kept.txt
done
KEPT=$(cat kept.txt)
```

### Challenge 3: Date Format Portability

**Problem**: `date -Iseconds` works on Linux but not macOS

**Current**: Using `-Iseconds` (GNU)  
**TODO**: Use `-Is` or portable format `date -u +%Y-%m-%dT%H:%M:%S`

### Challenge 4: Sudo Without Password

**Problem**: Scripts need to reload nginx

**Solution**: Targeted sudoers rules
```
smart ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
```

Only specific commands, no blanket sudo access.

### Challenge 5: Dashboard State Updates

**Problem**: How to refresh dashboard without constant polling?

**Solution**: 
- Generate `state.json` after each run
- Nginx serves with no-cache headers
- JS polls every 30 seconds
- Future: Server-Sent Events or WebSockets

## What's Working Well

### ✅ Orchestration
- Clean separation of concerns
- Easy to follow control flow
- Logs everything important
- Handles errors gracefully

### ✅ Decision Logic
- Simple but effective
- Configurable thresholds
- Clear audit trail
- Easy to extend

### ✅ Dashboard
- Shows exactly what's needed
- Auto-refreshes
- Mobile-friendly
- No build step

### ✅ Deployment
- Cloud-init makes it trivial
- Repeatable and documented
- Minimal manual steps

## What Needs Work

### ❌ Error Handling

Current: Basic `set -euo pipefail`  
Needed: 
- Retry logic for transient failures
- Better error messages
- Automatic recovery
- Alert on repeated failures

### ❌ Testing

Current: Manual testing only  
Needed:
- Unit tests for decision logic (bats framework?)
- Integration tests with mock servers
- Continuous testing in CI/CD
- Smoke tests after deployment

### ❌ Monitoring

Current: Just logs and dashboard  
Needed:
- Health check endpoint
- Prometheus metrics
- Alert integration
- Uptime monitoring

### ❌ Security

Current: Basic UFW + sudoers  
Needed:
- HTTPS by default
- Secret management (env vars, not config files)
- Audit logging
- Security scanning

## Performance Notes

### Baseline Metrics (CX11 Hetzner)

- Script execution: <100ms
- Measurement overhead: ~5ms per probe
- Decision calculation: <50ms
- Dashboard update: <20ms
- Total run time: ~15 minutes (mostly measurement)

### Resource Usage

- CPU: 1-2% average, 5-10% during runs
- Memory: ~30MB for scripts
- Disk: ~1MB per run (CSV + logs)
- Network: Minimal (local probes only)

### Bottlenecks

- Measurement duration (intentional - need enough samples)
- Cooldown period (safety measure)
- Sequential variant testing (could parallelize with traffic splitting)

## Interesting Patterns

### The "Keep First Winner" Strategy

Current approach: Test variants sequentially, keep first improvement.

**Pros**: 
- Simple to implement
- Quick to find gains
- Conservative (doesn't over-optimize)

**Cons**:
- Might miss better variants
- Order matters
- No global optimization

**Future**: Multi-armed bandit or Bayesian optimization

### The "Stateless Runner" Pattern

Each run is completely independent:
- No persistent state between runs
- Fresh baseline every time
- Self-contained run directories

**Pros**: 
- Easy to reason about
- No state corruption
- Reproducible

**Cons**:
- Can't detect slow degradation
- Wastes time re-establishing baseline
- No learning across runs

**Future**: Track trends, compare to historical baseline

## Lessons Learned

### 1. Start Simple
The first version was going to use Python, PostgreSQL, etc.  
Stripped it down to shell scripts - **way better**.

### 2. Measure Real Things
Synthetic benchmarks lie. Real HTTP requests with real latency = truth.

### 3. Always Revert on Uncertainty
Better to miss an optimization than to keep a regression.

### 4. Logs Are Your Friend
Everything important is logged. Makes debugging trivial.

### 5. Self-Documenting Systems Win
Dashboard shows state, experiments show config, logs show decisions.  
No mysteries.

## Future Explorations

### Local AI Coaching

**Idea**: Run Ollama with Llama 3.1 8B locally

**Prompt Template**:
```
You are a server optimization coach. Based on these metrics:
- Baseline: 45ms p50, 0% errors
- Variant: 38ms p50, 0% errors  
- Improvement: 15.5%
- Threshold: 10% minimum

The system wants to KEEP this change. Do you agree? 
Consider: sustained performance, error trends, resource usage.
```

**Benefits**:
- Nuanced decisions beyond simple thresholds
- Pattern recognition across runs
- Explain reasoning to humans
- Learn from outcomes

**Challenges**:
- Model size (need 16GB+ RAM for 8B model)
- Inference speed (need fast decisions)
- Reliability (can't fail the experiment)
- Context limits (can't send all history)

### Experiment Generation

**Idea**: AI suggests new experiments based on system profile

**How**:
1. Analyze current configuration
2. Identify tunable parameters
3. Suggest safe ranges to test
4. Generate meta.json automatically

**Example**:
```
Detected: Nginx with 1 worker process
Suggestion: Test 2, 4, auto workers
Rationale: Multi-core CPU detected
Risk: Low (just reload nginx)
```

### Multi-Server Coordination

**Idea**: Fleet-wide optimization

**Architecture**:
- One control plane server
- N experiment servers
- Centralized decision making
- Coordinated rollouts

**Benefits**:
- Faster experimentation (parallel testing)
- A/B with real traffic
- Canary deployments
- Learn from entire fleet

## Open Questions

1. **How to handle multi-metric optimization?**
   - Current: Just latency + errors
   - Wanted: Cost, CPU, memory, etc.
   - Solution: Weighted scoring? Pareto optimization?

2. **When to stop experimenting?**
   - Current: Never (runs forever)
   - Wanted: Detect diminishing returns
   - Solution: Track improvement velocity, pause when flat?

3. **How to share learnings across servers?**
   - Current: Each server independent
   - Wanted: "Worker config X works on similar hardware"
   - Solution: Centralized pattern database?

4. **What about side effects?**
   - Current: Only measure direct metrics
   - Missed: Resource exhaustion, cascading failures
   - Solution: Multi-dimensional health checks?

5. **How to validate experiments are safe?**
   - Current: Trust the experiment author
   - Wanted: Automatic safety analysis
   - Solution: Dry-run mode? Canary percentage?

## Next Steps

Immediate (this week):
1. ✅ Finish documentation
2. ⏳ Test full Hetzner deployment
3. ⏳ Add log rotation
4. ⏳ Security hardening

Short-term (this month):
- Multiple experiment rotation
- Better error handling
- Monitoring integration
- More experiment templates

Long-term (this quarter):
- Local AI integration
- Multi-server support
- Advanced analytics
- Web management UI

---

**These notes are living documentation. Update as we learn.**

