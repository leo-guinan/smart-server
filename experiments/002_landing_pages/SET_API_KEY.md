# Setting Your Fathom API Key

## The Problem

When you set `FATHOM_API_KEY` in `.bashrc`, it only works in interactive shells. Scripts run via cron or SSH don't pick it up.

## The Solution

Set the API key directly in `fathom.conf`:

### Step 1: Get Your API Key

1. Go to: https://app.usefathom.com/api
2. Click "Create API Key"
3. Name it "Smart Server"
4. Copy the key (format: `fk_live_XXXXXXXXXX`)

### Step 2: Update fathom.conf

```bash
ssh root@178.156.207.21

# Edit the config file
nano /opt/smart/experiments/002_landing_pages/fathom.conf
```

Find this line:
```bash
FATHOM_API_KEY="${FATHOM_API_KEY:-}"
```

Replace with your actual key:
```bash
FATHOM_API_KEY="fk_live_YOUR_ACTUAL_KEY_HERE"
```

Save and exit (Ctrl+X, Y, Enter)

### Step 3: Test

```bash
cd /opt/smart/experiments/002_landing_pages
bash bin/fetch_fathom_data.sh
```

You should see:
```
✓ Fathom data fetched successfully
Summary:
  Total pageviews: 0
  Unique visitors: 0
```

Without any API error warnings!

### Step 4: Verify It Works

Visit your landing page a few times:
- https://exp-002.letleodoit.com

Then fetch data again:
```bash
bash bin/fetch_fathom_data.sh
```

You should now see actual data!

## Alternative: Environment File

If you prefer to keep secrets out of config files:

### Create .env file
```bash
cat > /opt/smart/experiments/002_landing_pages/.env << EOF
FATHOM_API_KEY="fk_live_YOUR_KEY"
EOF
chmod 600 /opt/smart/experiments/002_landing_pages/.env
```

### Update fetch script to source it
Edit `bin/fetch_fathom_data.sh`:
```bash
# Add after #!/usr/bin/env bash
if [ -f "${EXP_DIR}/.env" ]; then
  . "${EXP_DIR}/.env"
fi
```

## Why .bashrc Doesn't Work

`.bashrc` is only sourced for:
- ✅ Interactive login shells (when you SSH and get a prompt)
- ❌ Non-interactive shells (scripts run by cron)
- ❌ Commands run via `ssh user@host "command"`

Scripts need the key from:
- ✅ Config file (fathom.conf)
- ✅ .env file
- ✅ /etc/environment (system-wide)

## Recommended Approach

**Best for Smart Server**: Put it in `fathom.conf`

Why:
- Scripts automatically source it
- No extra file management
- Works with cron jobs
- Clear and documented
- Easy to update

**Save the API key in fathom.conf and you're all set!** 🔑

