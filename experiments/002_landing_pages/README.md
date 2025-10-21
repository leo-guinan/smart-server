# Self-Optimizing Landing Page System

A landing page that experiments on itself, testing different component combinations to maximize conversions.

## How It Works

### 1. Component Library
Each section of the landing page (Hero, Problem, Solution, Proof, CTA) has multiple variants stored as HTML templates.

### 2. Dynamic Generation
When a visitor arrives, the system:
- Selects the best-performing components (80% exploitation)
- Randomly tests underused components (20% exploration)
- Generates a unique page configuration
- Tracks performance with Fathom Analytics

### 3. Performance Tracking
Each component tracks:
- **Impressions**: How many times shown
- **Conversions**: How many visitors reached the next stage
- **Conversion Rate**: Success rate
- **Dwell Time**: Average time spent

### 4. Continuous Optimization
- Analyzes results every 24 hours
- Updates component performance stats
- Selects better combinations over time
- Automatically swaps underperforming components

## Setup

### 1. Configure Fathom Analytics

Edit `meta.json`:
```json
{
  "fathom_site_id": "YOUR_FATHOM_SITE_ID"
}
```

### 2. Set Up Tracking Goals in Fathom

Create these custom goals:
- `PAGE_LOAD` - Initial page view
- `SCROLL_25` - Hero → Problem transition
- `SCROLL_50` - Problem → Solution transition
- `SCROLL_75` - Solution → Proof transition
- `SCROLL_90` - Proof → CTA transition
- `CTA_CLICK` - CTA button clicked (set value: $49)

### 3. Generate Initial Page

```bash
bash generate_page.sh
```

This creates `public/index.html` with an optimized component combination.

### 4. Serve the Landing Page

Configure nginx to serve the landing page:

```nginx
server {
    listen 443 ssl http2;
    server_name exp-002.letleodoit.com;
    
    root /opt/smart/experiments/002_landing_pages/public;
    index index.html;
    
    # Tracking API endpoint
    location = /api/landing/track {
        content_by_lua_block {
            local body = ngx.req.get_body_data()
            local handle = io.popen("/opt/smart/experiments/002_landing_pages/api/track.sh", "w")
            handle:write(body)
            handle:close()
        }
    }
    
    # SSL config...
}
```

### 5. Schedule Analysis

Add to crontab:
```bash
# Analyze landing page performance daily at 2 AM
0 2 * * * bash /opt/smart/experiments/002_landing_pages/analyze.sh >> /opt/smart/var/landing_analysis.log 2>&1

# Regenerate page with new component selection every 6 hours
0 */6 * * * bash /opt/smart/experiments/002_landing_pages/generate_page.sh >> /opt/smart/var/landing_gen.log 2>&1
```

## Component Architecture

### Stages & Success Metrics

| Stage | Purpose | Success Metric | Min Rate |
|-------|---------|----------------|----------|
| Hero | Capture attention, deliver "aha" | scroll_25 | 80% |
| Problem | Build tension around fallacy | scroll_50 | 70% |
| Solution | Show the mechanism/leverage | scroll_75 | 60% |
| Proof | Provide evidence/case studies | scroll_90 | 50% |
| CTA | Convert to purchase | cta_click | 15% |

### Component Variants

**Hero (2 variants):**
- `hero_automation_waste` - "Automation doesn't mean you're done"
- `hero_time_leaking` - "Your time is leaking"

**Problem (2 variants):**
- `problem_automation_fallacy` - Contrasts expectations vs reality
- `problem_broken_workflows` - Lists symptoms of broken automation

**Solution (2 variants):**
- `solution_measurement` - Measurement as the other half of leverage
- `solution_time_insurance` - Time Insurance concept

**Proof (2 variants):**
- `proof_case_studies` - Client success stories
- `proof_compound_savings` - ROI calculations and graphs

**CTA (2 variants):**
- `cta_audit` - Time Map Report offer
- `cta_guarantee` - Money-back guarantee emphasis

## Adding New Components

### 1. Create HTML Template

```bash
# Create new variant
nano templates/hero/your_new_variant.html
```

Template format:
```html
<section class="hero" data-component="hero_new_variant" data-stage="hero">
  <div class="container">
    <!-- Your content -->
  </div>
</section>
```

### 2. Register in components.json

```json
{
  "id": "hero_new_variant",
  "name": "Your New Variant",
  "html": "templates/hero/your_new_variant.html",
  "stats": {
    "impressions": 0,
    "scroll_25": 0,
    "conversion_rate": 0.0,
    "avg_dwell_ms": 0
  }
}
```

### 3. Test

```bash
bash generate_page.sh
open public/index.html
```

## Analysis & Optimization

### View Current Performance

```bash
bash analyze.sh
```

Output shows:
- Impressions per component
- Conversion rates
- Top performers
- Underperformers to review

### Understanding Results

**High conversion rate (>0.7):** Keep using, this component works

**Medium conversion rate (0.5-0.7):** Adequate, monitor for trends

**Low conversion rate (<0.5):** Consider replacing or rewriting

**Low impressions (<10):** Not enough data, needs more testing

### Epsilon-Greedy Selection

The system uses **epsilon-greedy** algorithm:
- **80% Exploitation**: Use best-performing components
- **20% Exploration**: Test random components

This balances:
- **Showing what works** (maximizes conversions now)
- **Testing new options** (finds better combinations)

## Funnel Math

Given conversion rates:
- Hero → Problem: 80%
- Problem → Solution: 70%
- Solution → Proof: 60%
- Proof → CTA: 50%
- CTA → Payment: 15%

**Overall conversion**: 0.8 × 0.7 × 0.6 × 0.5 × 0.15 = **2.52%**

Meaning: **1 in 40 visitors** converts to paying customer.

### Optimization Strategy

Improve the **weakest link** first for maximum impact:
1. Find lowest conversion rate stage
2. Test new components for that stage
3. Monitor improvement
4. Move to next weakest stage

## Integration with Fathom

### Event Structure

**Page Load:**
```javascript
fathom.trackGoal('PAGE_LOAD', 0);
fathom.trackEvent('experiment_config', {
  _value: JSON.stringify(COMPONENTS),
  _session: SESSION_ID
});
```

**Scroll Events:**
```javascript
fathom.trackGoal('SCROLL_25', 0);
fathom.trackGoal('SCROLL_50', 0);
// etc.
```

**CTA Click:**
```javascript
fathom.trackGoal('CTA_CLICK', 49); // $49 value
```

### Analyzing in Fathom

1. Go to Fathom dashboard
2. View Goals → See conversion rates per goal
3. Compare time periods to see improvement
4. Export data for deeper analysis

## Files Structure

```
002_landing_pages/
├── meta.json              # Experiment configuration
├── components.json        # Component library definitions
├── generate_page.sh       # Dynamic page generator
├── analyze.sh            # Performance analyzer
├── README.md             # This file
│
├── templates/            # HTML component templates
│   ├── hero/
│   ├── problem/
│   ├── solution/
│   ├── proof/
│   └── cta/
│
├── public/               # Generated landing page
│   ├── index.html       # Current page
│   └── styles.css       # Styles
│
├── api/                  # Tracking endpoints
│   └── track.sh         # Receive analytics data
│
└── var/                  # Runtime data
    ├── component_stats.json   # Performance data
    ├── results.jsonl         # Raw tracking results
    └── generations.jsonl     # Generation log
```

## Best Practices

### 1. Test One Change at a Time
Don't add multiple new components simultaneously. Test one, gather data, then test another.

### 2. Wait for Sufficient Data
Need at least 10 impressions per component before trusting conversion rates.

### 3. Document Hypotheses
When creating new variants, note why you think they'll perform better.

### 4. Monitor Holistically
A component might have high scroll-through but low overall conversion. Check funnel impact.

### 5. Refresh Regularly
Regenerate the page every 6 hours to incorporate new performance data.

## Troubleshooting

**Q: No results being tracked**
- Check Fathom site ID in meta.json
- Verify Fathom script loads (check browser console)
- Ensure `/api/landing/track` endpoint is accessible

**Q: All components have zero impressions**
- Run `generate_page.sh` to create initial page
- Serve the page and visit it
- Wait 24 hours, then run `analyze.sh`

**Q: Analysis shows no top performers**
- Need at least 10 sessions before meaningful analysis
- Check that results.jsonl is being populated
- Verify tracking script is sending data

**Q: Components not updating**
- Run `analyze.sh` to update stats
- Run `generate_page.sh` to apply new selection
- Ensure cron jobs are scheduled

## Future Enhancements

- [ ] Multi-armed bandit algorithm for smarter selection
- [ ] A/B test entire page layouts
- [ ] Personalization based on traffic source
- [ ] Real-time component swapping
- [ ] Automated component generation with AI
- [ ] Integration with payment processor
- [ ] Full checkout flow tracking

## Example: Complete Workflow

```bash
# 1. Initial setup
cd /opt/smart/experiments/002_landing_pages
nano meta.json  # Add your Fathom site ID

# 2. Generate first page
bash generate_page.sh

# 3. Deploy to nginx (configured in vhost)
# Visitors start arriving...

# 4. After 24 hours, analyze
bash analyze.sh

# 5. Regenerate with optimized selection
bash generate_page.sh

# 6. Repeat daily for continuous optimization
```

---

**This landing page optimizes itself. Your job is to create great component variants and let the system find the winning combinations.**

