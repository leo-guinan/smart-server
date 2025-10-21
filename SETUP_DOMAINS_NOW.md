# Set Up Domains and SSL - Quick Guide

**Server IP**: 178.156.207.21

## Step 1: Configure DNS

Before we can set up SSL, you need to point your domain to the server.

### Option A: Wildcard (Recommended)
Add a single DNS record in your domain provider:
```
Type: A
Name: *
Value: 178.156.207.21
TTL: Automatic
```

This covers all subdomains automatically.

### Option B: Individual Subdomains
Add these DNS records:
```
dashboard.yourdomain.com → 178.156.207.21 (A record)
exp-001.yourdomain.com   → 178.156.207.21 (A record)
exp-002.yourdomain.com   → 178.156.207.21 (A record)
```

## Step 2: Wait for DNS Propagation

Check if DNS is working:
```bash
dig dashboard.yourdomain.com +short
# Should return: 178.156.207.21
```

Usually takes 5-30 minutes.

## Step 3: Pull Latest Code on Server

```bash
ssh root@178.156.207.21
cd /opt/smart-repo
git pull
cp bin/*.sh /opt/smart/bin/
cp domain.conf /opt/smart/
chmod +x /opt/smart/bin/*.sh
```

## Step 4: Configure Your Domain

```bash
cd /opt/smart

# Edit domain.conf
nano domain.conf
```

Set these values:
```bash
BASE_DOMAIN="yourdomain.com"  # Your actual domain
SSL_EMAIL="admin@yourdomain.com"  # Your email
```

Save and exit (Ctrl+X, Y, Enter)

## Step 5: Generate Virtual Hosts

```bash
bash bin/generate_vhosts.sh
```

This creates nginx configurations for each experiment subdomain.

## Step 6: Set Up SSL

```bash
bash bin/setup_ssl.sh
```

This will:
- Install certbot
- Request SSL certificates for all domains
- Configure HTTPS
- Set up auto-renewal

## Step 7: Access Your Sites

Open in browser:
- `https://dashboard.yourdomain.com` - Main dashboard
- `https://exp-001.yourdomain.com` - Experiment 001
- `https://exp-002.yourdomain.com` - Experiment 002 (when you create it)

All with valid SSL certificates! 🎉

## Subdomain Pattern

With default settings:
- `exp-001.yourdomain.com` → Experiment 001_nginx_workers
- `exp-002.yourdomain.com` → Experiment 002_cache_ttl
- etc.

Each experiment gets its own subdomain automatically.

## What domain do you want to use?

Let me know your domain and I can help configure it!

