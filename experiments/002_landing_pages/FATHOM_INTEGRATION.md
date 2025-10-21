# Fathom Analytics Integration

The Smart Server can automatically query Fathom Analytics to optimize your landing page based on real user behavior data.

## How It Works

```
┌─────────────────┐
│   Visitors      │
│  Browse Page    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Fathom Tracks   │
│  User Events    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Smart Server    │
│  Fetches Data   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Analyzes      │
│  Performance    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Updates      │
│ Component Stats │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Regenerates    │
│   Page with     │
│ Best Components │
└─────────────────┘
```

## Setup

### 1. Get Fathom API Key

1. Go to https://app.usefathom.com/api
2. Create a new API key
3. Copy the key

### 2. Configure API Key

**Option A: Environment Variable (Recommended)**
```bash
export FATHOM_API_KEY="your-api-key-here"
```

Add to `/etc/environment` or `~/.bashrc` for persistence:
```bash
echo 'FATHOM_API_KEY="your-api-key-here"' >> ~/.bashrc
```

**Option B: Config File**
```bash
ssh root@178.156.207.21
nano /opt/smart/experiments/002_landing_pages/fathom.conf
# Set: FATHOM_API_KEY="your-api-key-here"
```

### 3. Test Connection

```bash
cd /opt/smart/experiments/002_landing_pages
bash bin/fetch_fathom_data.sh
```

You should see:
```
Fetching Fathom data for UQBOCDXH...
Date range: 2025-10-14 to 2025-10-21

>> Fetching pageviews...
>> Fetching events...
   - page_load
   - scroll_25
   - scroll_50
   - scroll_75
   - scroll_90
   - cta_click
>> Fetching event values...

✓ Fathom data fetched successfully
```

## Usage

### Manual Analysis

Run analysis anytime:
```bash
cd /opt/smart/experiments/002_landing_pages

# Fetch latest data
bash bin/fetch_fathom_data.sh

# Analyze performance
bash bin/analyze_with_fathom.sh

# Regenerate page with optimizations
bash generate_page.sh
```

### Automatic Optimization

Run the full cycle:
```bash
bash bin/auto_optimize.sh
```

This will:
1. Fetch Fathom data (last 7 days)
2. Analyze component performance
3. Update component statistics
4. Regenerate page with best-performing components

### Schedule Automatic Optimization

Add to crontab for daily optimization:
```bash
crontab -e

# Add this line:
# Run daily at 3 AM
0 3 * * * bash /opt/smart/experiments/002_landing_pages/bin/auto_optimize.sh >> /opt/smart/var/landing_optimization.log 2>&1
```

Or every 6 hours:
```
# Every 6 hours
0 */6 * * * bash /opt/smart/experiments/002_landing_pages/bin/auto_optimize.sh >> /opt/smart/var/landing_optimization.log 2>&1
```

## What Gets Analyzed

### Events Tracked:
- `page_load` - Initial page view
- `scroll_25` - Passed hero section
- `scroll_50` - Passed problem section
- `scroll_75` - Passed solution section
- `scroll_90` - Passed proof section
- `cta_click` - Clicked CTA button ($49 value)

### Metrics Calculated:
- **Conversion rates** per stage
- **Overall conversion** (visitor → CTA click)
- **Revenue** (sum of CTA click values)
- **Funnel drop-off** points
- **Weakest stage** identification

### Component Updates:
- Updates `impressions` count
- Updates `conversion_rate` for each stage
- Maintains epsilon-greedy selection (80% best, 20% explore)

## Output Examples

### Funnel Analysis
```
Funnel Analysis:
  Visitors:     245
  Page loads:   245
  Scroll 25%:   196 (hero → problem)
  Scroll 50%:   147 (problem → solution)
  Scroll 75%:   103 (solution → proof)
  Scroll 90%:   62 (proof → CTA)
  CTA clicks:   8

Stage Conversion Rates:
  Hero:         0.8000 (80.0%)
  Problem:      0.7500 (75.0%)
  Solution:     0.7007 (70.1%)
  Proof:        0.6019 (60.2%)
  CTA:          0.1290 (12.9%)

Overall Conversion: 0.0327 (3.27%)
Total Revenue: $392
```

### Recommendations
```
Recommendations:
  ✅ Overall conversion is good (>2%)
  
Stage Performance:
  Weakest stage: proof (60.2%)
  → Focus optimization efforts here
```

## Data Files

All Fathom data is stored in `var/fathom/`:

```
var/fathom/
├── pageviews.json          # Total pageviews and visitors
├── event_page_load.json    # Page load events
├── event_scroll_25.json    # 25% scroll events
├── event_scroll_50.json    # 50% scroll events
├── event_scroll_75.json    # 75% scroll events
├── event_scroll_90.json    # 90% scroll events
├── event_cta_click.json    # CTA click events
└── event_cta_value.json    # CTA click revenue
```

## Configuration Options

Edit `fathom.conf`:

```bash
# How many days of data to analyze
FATHOM_LOOKBACK_DAYS=7

# Minimum sessions before trusting data
MIN_SESSIONS_FOR_ANALYSIS=10
```

## Advanced: Per-Component Tracking

Currently, the system updates all components in a stage with the same conversion rate. To track individual components:

### Future Enhancement:
1. Add component ID to Fathom events
2. Parse generation logs to map sessions to components
3. Calculate per-component conversion rates
4. Update only the specific components that were shown

**Implementation:**
```javascript
// In generate_page.sh, track which components were shown
fathom.trackEvent('component_shown', {
  _value: JSON.stringify({
    hero: 'hero_automation_waste',
    problem: 'problem_automation_fallacy',
    // ...
  })
});
```

Then in analysis, match events to component combinations.

## Troubleshooting

### "FATHOM_API_KEY not set"
Set the API key in `fathom.conf` or as environment variable.

### "Not enough data yet"
Need at least 10 sessions before analysis. Keep driving traffic.

### "Failed to fetch Fathom data"
- Check API key is correct
- Verify Fathom site ID matches
- Check network connectivity
- Ensure API key has read permissions

### "No Fathom data found"
Run `bash bin/fetch_fathom_data.sh` first.

## API Reference

### Fathom API Endpoints Used:

**Aggregations:**
```
GET https://api.usefathom.com/v1/aggregations
```

**Parameters:**
- `entity`: pageview or event
- `entity_id`: site_id or event name
- `aggregates`: visits, uniques, pageviews, sum
- `date_from`: YYYY-MM-DD
- `date_to`: YYYY-MM-DD
- `site_id`: Your Fathom site ID

**Authentication:**
```
Authorization: Bearer YOUR_API_KEY
```

**Documentation:**
https://usefathom.com/api

## Benefits

### Automatic Optimization:
- ✅ No manual A/B test setup
- ✅ Continuous learning from real data
- ✅ Data-driven component selection
- ✅ Automatic page regeneration
- ✅ Identifies weak points in funnel

### Intelligent Exploration:
- 80% exploitation (show best performers)
- 20% exploration (test underused components)
- Prevents local maxima
- Discovers better combinations over time

### Full Feedback Loop:
```
Traffic → Behavior → Data → Analysis → Optimization → Better Results
    ↑                                                          ↓
    └──────────────────────────────────────────────────────────┘
```

## Example Workflow

### Day 1: Launch
```bash
# Deploy landing page
bash generate_page.sh
# Drive traffic
```

### Day 2: First Analysis
```bash
# After getting 100+ visitors
bash bin/auto_optimize.sh
# Review recommendations
```

### Day 3+: Automatic
```bash
# Cron runs daily at 3 AM
# System automatically:
# - Fetches data
# - Analyzes performance
# - Optimizes components
# - Regenerates page
```

### Weekly: Review & Iterate
```bash
# Check overall performance
cat var/fathom/pageviews.json | jq .

# Review component stats
cat var/component_stats.json | jq .

# Add new component variants if needed
# System will automatically test them
```

## Performance Tracking

Track optimization impact over time:

```bash
# View historical performance
grep "Overall Conversion" /opt/smart/var/landing_optimization.log

# Example output:
# 2025-10-15: Overall Conversion: 0.0245 (2.45%)
# 2025-10-16: Overall Conversion: 0.0267 (2.67%)  ← +9%
# 2025-10-17: Overall Conversion: 0.0289 (2.89%)  ← +18%
# 2025-10-18: Overall Conversion: 0.0312 (3.12%)  ← +27%
```

---

**Your landing page now optimizes itself based on real user behavior!** 📊🤖

Set it up once, and let the Smart Server continuously improve conversion rates while you sleep.

