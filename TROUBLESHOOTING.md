# 🔧 ReCloop AI Troubleshooting Guide

This guide helps resolve common issues during deployment of your ReCloop AI scheduling SaaS.

## 🚨 "Unable to correct problems, you have held broken packages"

This error occurs when there are conflicting package dependencies on your Ubuntu server.

### Quick Fix - Try These Commands:

```bash
# 1. Run the package fix script
./scripts/fix-packages.sh

# 2. If that doesn't work, try manual fixes:
sudo apt update
sudo apt --fix-broken install -y
sudo dpkg --configure -a
sudo apt autoremove -y
sudo apt clean

# 3. Reset package cache completely:
sudo apt clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt update
```

### Alternative: Use Minimal Setup

If the main setup script fails, use the minimal setup instead:

```bash
# Instead of ./scripts/setup-server.sh, run:
./scripts/minimal-setup.sh
```

This installs packages one by one and skips problematic dependencies.

## 🔧 Common Package Issues

### Issue: Node.js Installation Fails

**Solution:**
```bash
# Use NodeSource repository for reliable Node.js installation
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node --version
npm --version
```

### Issue: Nginx Installation Conflicts

**Solution:**
```bash
# Remove conflicting packages first
sudo apt remove --purge nginx nginx-common nginx-core
sudo apt autoremove
sudo apt clean

# Reinstall
sudo apt update
sudo apt install -y nginx
```

### Issue: Certbot Installation Problems

**Solution:**
```bash
# Use snap instead of apt for Certbot
sudo apt remove certbot
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot
```

## 🐛 Deployment Issues

### Issue: PM2 Services Won't Start

**Check Status:**
```bash
pm2 status
pm2 logs
```

**Common Fixes:**
```bash
# Restart all services
pm2 restart ecosystem.config.js

# Check if environment file exists
ls -la .env

# Check if build completed
ls -la frontend/dist/
```

### Issue: Frontend Not Loading

**Check Nginx:**
```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

**Check Frontend Build:**
```bash
cd frontend
npm run build
ls -la dist/
```

### Issue: Webhook Not Receiving

**Check Service:**
```bash
pm2 logs recloop-webhook
curl https://recloop.com/webhook/health
```

**Check Firewall:**
```bash
sudo ufw status
sudo ufw allow 'Nginx Full'
```

## 🔐 SSL Certificate Issues

### Issue: Certbot Fails

**Prerequisites:**
```bash
# Ensure domain points to server
nslookup recloop.com
dig recloop.com

# Ensure Nginx is running
sudo systemctl status nginx
```

**Manual Certificate:**
```bash
sudo certbot --nginx -d recloop.com -d www.recloop.com
```

### Issue: Auto-renewal Fails

**Test Renewal:**
```bash
sudo certbot renew --dry-run
```

**Check Cron Job:**
```bash
sudo crontab -l
# Should contain: 0 12 * * * /usr/bin/certbot renew --quiet
```

## 🌐 Domain and DNS Issues

### Issue: Domain Not Resolving

**Check DNS:**
```bash
nslookup recloop.com
dig recloop.com A
```

**Wait for Propagation:**
- DNS changes can take 24-48 hours to propagate globally
- Use [dnschecker.org](https://dnschecker.org) to verify

### Issue: Mixed Content Errors

**Solution:**
```bash
# Ensure all resources use HTTPS
# Check your .env file:
FRONTEND_URL=https://recloop.com
WEBHOOK_URL=https://recloop.com/webhook
```

## 🔑 Environment Configuration Issues

### Issue: Missing API Keys

**Check Required Variables:**
```bash
cat .env

# Required variables:
CONVEX_URL=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
OPENAI_API_KEY=
RESEND_API_KEY=
```

### Issue: Google OAuth Not Working

**Common Problems:**
1. **Authorized redirect URIs** not set to `https://recloop.com/auth/google/callback`
2. **Authorized JavaScript origins** not set to `https://recloop.com`
3. **Domain verification** not completed in Google Console

**Solution:**
```bash
# Check Google Cloud Console:
# 1. APIs & Services > Credentials
# 2. Edit OAuth 2.0 Client
# 3. Add correct URIs
```

## 📊 Performance Issues

### Issue: High Memory Usage

**Check PM2 Memory:**
```bash
pm2 monit
```

**Restart Services:**
```bash
pm2 restart ecosystem.config.js
```

### Issue: Slow Response Times

**Check Logs:**
```bash
pm2 logs
sudo tail -f /var/log/nginx/access.log
```

**Optimize Nginx:**
```bash
# Already configured in nginx/recloop.conf
# Includes gzip compression and caching
```

## 🔄 Git Deployment Issues

### Issue: Auto-deployment Not Working

**Check Git Hook:**
```bash
ls -la /var/git/recloop.git/hooks/
cat /var/git/recloop.git/hooks/post-receive
```

**Test Deployment:**
```bash
# From your local machine:
git push production main
```

### Issue: Permission Denied

**Fix Permissions:**
```bash
sudo chown -R $USER:$USER /var/www/recloop
sudo chown -R $USER:$USER /var/git/recloop.git
```

## 🆘 Emergency Recovery

### If Everything Breaks

**1. Stop All Services:**
```bash
pm2 stop all
sudo systemctl stop nginx
```

**2. Check System Resources:**
```bash
df -h        # Disk space
free -m      # Memory
top          # CPU usage
```

**3. Restore from Backup:**
```bash
ls /var/backups/recloop/
# Extract latest backup
tar -xzf /var/backups/recloop/backup-YYYYMMDD-HHMMSS.tar.gz
```

**4. Start Fresh:**
```bash
# Remove everything and start over
rm -rf /var/www/recloop
git clone https://github.com/recloopai/recloop-ai-assistant.git /var/www/recloop
cd /var/www/recloop
./scripts/minimal-setup.sh
```

## 📞 Getting Help

### Log Locations

- **PM2 Logs:** `/var/log/pm2/`
- **Nginx Logs:** `/var/log/nginx/`
- **Deployment Logs:** `/var/log/recloop-deploy.log`
- **System Logs:** `sudo journalctl -f`

### Useful Commands

```bash
# Check all service status
pm2 status
sudo systemctl status nginx
sudo ufw status

# View real-time logs
pm2 logs --lines 50
sudo tail -f /var/log/nginx/error.log

# Test configurations
sudo nginx -t
pm2 ecosystem.config.js --dry-run

# Restart everything
pm2 restart ecosystem.config.js
sudo systemctl restart nginx
```

### Still Having Issues?

1. **Check logs first** - most issues show up in PM2 or Nginx logs
2. **Verify environment variables** - missing API keys cause most failures
3. **Test individual components** - frontend, backend, webhook separately
4. **Check firewall and DNS** - network issues are common
5. **Use minimal setup** - if package conflicts persist

---

**Remember:** The `DEPLOYMENT.md` file contains the complete step-by-step guide, while this troubleshooting guide helps resolve specific issues that may arise.