# Domain and SSL Setup Guide

This guide explains how to set up custom domains and SSL certificates for your Smart Server, with different experiments accessible on different subdomains.

## Overview

With domain configuration, you can:
- Access the main dashboard at `dashboard.yourdomain.com` (or just `yourdomain.com`)
- Each experiment gets its own subdomain: `exp-001.yourdomain.com`, `exp-002.yourdomain.com`, etc.
- Automatic SSL certificates via Let's Encrypt
- HTTPS by default

## Prerequisites

1. **A domain name** (e.g., `smartserver.dev`, `mycompany.com`)
2. **DNS configured** - Point your domain and subdomains to your server IP
3. **Server deployed** - Smart server already running

## DNS Configuration

You need to create DNS records pointing to your server IP (`178.156.207.21`):

### Option 1: Wildcard Subdomain (Easiest)

Create a single wildcard A record:
```
*.yourdomain.com  →  178.156.207.21  (A record)
```

This automatically covers:
- `dashboard.yourdomain.com`
- `exp-001.yourdomain.com`
- `exp-002.yourdomain.com`
- etc.

### Option 2: Individual Subdomains

Create individual A records:
```
dashboard.yourdomain.com  →  178.156.207.21  (A record)
exp-001.yourdomain.com    →  178.156.207.21  (A record)
exp-002.yourdomain.com    →  178.156.207.21  (A record)
```

## Setup Steps

### 1. Configure Domain

SSH into your server and edit the domain configuration:

```bash
ssh root@178.156.207.21
cd /opt/smart

# Edit domain.conf
nano domain.conf
```

Set your domain:
```bash
BASE_DOMAIN="smartserver.dev"  # Replace with your domain
SSL_EMAIL="admin@smartserver.dev"  # Your email for Let's Encrypt
```

### 2. Generate Virtual Hosts

```bash
bash bin/generate_vhosts.sh
```

This creates nginx configurations for:
- Main dashboard
- Each experiment subdomain

### 3. Test DNS Resolution

Before requesting SSL certificates, verify DNS is working:

```bash
# Check if your domains resolve to the server
dig dashboard.smartserver.dev +short
# Should return: 178.156.207.21

dig exp-001.smartserver.dev +short
# Should return: 178.156.207.21
```

If they don't resolve yet, **wait** for DNS propagation (can take 5-60 minutes).

### 4. Set Up SSL

Once DNS is working:

```bash
bash bin/setup_ssl.sh
```

This will:
- Install certbot
- Request SSL certificates for all domains
- Configure nginx for HTTPS
- Set up auto-renewal

### 5. Verify HTTPS

Open in browser:
- `https://dashboard.smartserver.dev`
- `https://exp-001.smartserver.dev`

All should load with valid SSL certificates! 🎉

## Configuration Options

### Customize Subdomain Pattern

Edit `domain.conf`:

```bash
# Use experiment name instead of ID
EXPERIMENT_SUBDOMAIN_PATTERN="{experiment_name}"
# Result: nginx-workers.yourdomain.com

# Use a prefix
EXPERIMENT_SUBDOMAIN_PATTERN="test-{experiment_id}"
# Result: test-001.yourdomain.com

# Use both
EXPERIMENT_SUBDOMAIN_PATTERN="{experiment_id}-{experiment_name}"
# Result: 001-nginx-workers.yourdomain.com
```

Available variables:
- `{experiment_id}` - e.g., `001`, `002`
- `{experiment_name}` - e.g., `nginx_workers`, `cache_ttl`

### Change Dashboard Subdomain

Edit `domain.conf`:

```bash
# Use "www" instead of "dashboard"
DASHBOARD_SUBDOMAIN="www"

# Use root domain (no subdomain)
DASHBOARD_SUBDOMAIN=""
```

## Adding New Experiments

When you add a new experiment:

1. Create the experiment directory
2. Regenerate virtual hosts: `bash bin/generate_vhosts.sh`
3. Update SSL certificates: `bash bin/setup_ssl.sh`

**Or use the helper script:**

```bash
bash bin/add_experiment.sh 002_cache_ttl
```

(We'll create this script next)

## DNS Providers

### Cloudflare
1. Go to DNS settings
2. Add A record: `*` pointing to `178.156.207.21`
3. Proxy status: DNS only (orange cloud off)

### Namecheap
1. Advanced DNS tab
2. Add Record: Type=A, Host=`*`, Value=`178.156.207.21`

### Google Domains / Cloud DNS
1. DNS settings
2. Add record: Name=`*`, Type=A, Data=`178.156.207.21`

### Hetzner DNS
```bash
# Using hcloud DNS
hcloud dns create --name smartserver.dev
hcloud dns add-record smartserver.dev --type A --name "*" --value 178.156.207.21
```

## Troubleshooting

### "DNS resolution failed"

**Problem**: Domains don't resolve to your server

**Solution**:
```bash
# Check DNS
dig yourdomain.com +short

# Wait for propagation (up to 60 minutes)
# Or use Cloudflare for faster propagation
```

### "Certificate request failed"

**Problem**: Certbot can't verify domain ownership

**Solution**:
```bash
# Ensure nginx is serving on port 80
systemctl status nginx

# Check if domain reaches your server
curl -I http://dashboard.yourdomain.com

# Try manual certificate request
certbot certonly --nginx -d dashboard.yourdomain.com --dry-run
```

### "Too many certificates"

**Problem**: Let's Encrypt rate limit (5 certs per domain per week)

**Solution**:
- Wait 7 days, or
- Use staging environment for testing:
  ```bash
  certbot --staging --nginx -d yourdomain.com
  ```

### "Nginx config test failed"

**Problem**: Invalid nginx configuration

**Solution**:
```bash
# Test config
nginx -t

# Check syntax
cat /etc/nginx/sites-available/smart-dashboard

# Reload after fixing
systemctl reload nginx
```

## SSL Certificate Renewal

Certificates auto-renew via systemd timer.

**Check renewal status:**
```bash
systemctl status certbot.timer
certbot renew --dry-run
```

**Manual renewal:**
```bash
certbot renew
systemctl reload nginx
```

## Security Best Practices

### Force HTTPS

After SSL is set up, redirect all HTTP to HTTPS:

Edit each vhost in `/etc/nginx/sites-available/`:

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    # ... rest of config
}
```

### Enable HSTS

Add to HTTPS server block:

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

### Firewall

Ensure only necessary ports are open:

```bash
ufw allow 80/tcp    # HTTP (for Let's Encrypt verification)
ufw allow 443/tcp   # HTTPS
ufw allow 22/tcp    # SSH
ufw enable
```

## Example: Complete Setup

```bash
# 1. Configure DNS (in your DNS provider)
# Add: *.smartserver.dev → 178.156.207.21

# 2. SSH to server
ssh root@178.156.207.21

# 3. Configure domain
cd /opt/smart
echo 'BASE_DOMAIN="smartserver.dev"' > domain.conf
echo 'SSL_EMAIL="admin@smartserver.dev"' >> domain.conf

# 4. Generate vhosts
bash bin/generate_vhosts.sh

# 5. Wait for DNS (check with dig)
dig dashboard.smartserver.dev +short

# 6. Set up SSL
bash bin/setup_ssl.sh

# 7. Test
curl -I https://dashboard.smartserver.dev
```

## Advanced: Per-Experiment Configuration

You can customize nginx configuration per experiment by editing the generated vhost files:

```bash
# Edit experiment vhost
nano /etc/nginx/sites-available/smart-exp-001

# Add custom config
server {
    # ... existing config ...
    
    # Custom rate limiting for this experiment
    limit_req_zone $binary_remote_addr zone=exp001:10m rate=10r/s;
    limit_req zone=exp001 burst=20;
}

# Reload
nginx -t && systemctl reload nginx
```

## Cost

- **Domain**: $10-15/year
- **SSL certificates**: FREE (Let's Encrypt)
- **Server**: $3.50/month (unchanged)

Total additional cost: ~$1/month

---

**Next Steps:**
- Set up your domain's DNS
- Run through the setup steps
- Access your dashboard via HTTPS!

