# 🚀 ReCloop AI Production Deployment Guide

Complete step-by-step guide to deploy ReCloop AI on your CloudCone Ubuntu server.

## 📋 Prerequisites

### Server Requirements
- Ubuntu 20.04+ VPS with at least 2GB RAM and 20GB storage
- Root or sudo access to the server
- Domain name pointing to your server IP (e.g., `recloop.com`)

### Required Accounts & API Keys
- Google Cloud Platform account with Gmail and Calendar APIs enabled
- OpenAI API account
- Resend account for email notifications
- GitHub account (repository already set up)

---

## Step 1: Initial Server Setup

### 1.1 Connect to Your Server
```bash
ssh root@your-server-ip
# or if using a non-root user:
ssh username@your-server-ip
```

### 1.2 Create a Deployment User (if not already done)
```bash
adduser recloop
usermod -aG sudo recloop
su - recloop
```

### 1.3 Set Up SSH Keys (Recommended)
```bash
# On your local machine, generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key to server
ssh-copy-id recloop@your-server-ip
```

---

## Step 2: Clone Repository and Run Setup

### 2.1 Clone the Repository
```bash
cd /home/recloop
git clone https://github.com/recloopai/recloop-ai-assistant.git
cd recloop-ai-assistant
```

### 2.2 Run the Setup Script
```bash
chmod +x scripts/setup-server.sh
./scripts/setup-server.sh
```

This script will:
- ✅ Install Node.js, Nginx, PM2, and all dependencies
- ✅ Configure firewall and security settings
- ✅ Set up directory structure
- ✅ Configure Nginx with production settings
- ✅ Set up log rotation and monitoring
- ✅ Create Git deployment hooks
- ✅ Configure PM2 for process management

---

## Step 3: Configure Environment Variables

### 3.1 Main Environment Configuration
```bash
cp .env.example .env
nano .env
```

Fill in your actual values:

```env
# Domain Configuration
DOMAIN=recloop.com
FRONTEND_URL=https://recloop.com
WEBHOOK_URL=https://recloop.com/webhook
API_URL=https://recloop.com/api

# Convex Configuration
CONVEX_URL=https://your-convex-deployment.convex.cloud
CONVEX_DEPLOY_KEY=your-convex-deploy-key

# Google OAuth & APIs
GOOGLE_CLIENT_ID=123456789-abcdef.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-client-secret
GOOGLE_PROJECT_ID=your-google-project-id

# OpenAI
OPENAI_API_KEY=sk-your-openai-api-key

# Email & Notifications
RESEND_API_KEY=re_your-resend-api-key
EMAIL_DOMAIN=recloop.com

# Security
JWT_SECRET=your-super-secure-jwt-secret-key-minimum-32-chars
ENCRYPTION_KEY=your-32-character-encryption-key-here
SESSION_SECRET=your-session-secret-key

# Server Config
NODE_ENV=production
PORT=3001
FRONTEND_PORT=3000
```

### 3.2 Frontend Environment
```bash
cp frontend/.env.example frontend/.env.local
nano frontend/.env.local
```

```env
VITE_CONVEX_URL=https://your-convex-deployment.convex.cloud
VITE_GOOGLE_CLIENT_ID=123456789-abcdef.apps.googleusercontent.com
VITE_API_URL=https://recloop.com/api
VITE_WEBHOOK_URL=https://recloop.com/webhook
```

### 3.3 Backend Environment
```bash
cp backend/.env.example backend/.env
nano backend/.env
```

```env
CONVEX_DEPLOYMENT=your-convex-deployment-name
CONVEX_DEPLOY_KEY=your-convex-deploy-key
GOOGLE_CLIENT_ID=123456789-abcdef.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-client-secret
OPENAI_API_KEY=sk-your-openai-api-key
RESEND_API_KEY=re_your-resend-api-key
NODE_ENV=production
```

---

## Step 4: Google Cloud Platform Setup

### 4.1 Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Note your Project ID

### 4.2 Enable Required APIs
```bash
# Enable APIs via gcloud CLI or in the console
gcloud services enable gmail.googleapis.com
gcloud services enable calendar-json.googleapis.com
gcloud services enable pubsub.googleapis.com
```

Or enable manually in the console:
- Gmail API
- Google Calendar API
- Google Pub/Sub API

### 4.3 Create OAuth 2.0 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth 2.0 Client ID**
3. Choose **Web application**
4. Set **Authorized JavaScript origins**: `https://recloop.com`
5. Set **Authorized redirect URIs**: `https://recloop.com/auth/google/callback`
6. Save the Client ID and Client Secret

### 4.4 Set Up Pub/Sub for Gmail Push Notifications
```bash
# Create topic
gcloud pubsub topics create gmail-notifications

# Create subscription pointing to your webhook
gcloud pubsub subscriptions create gmail-notifications-sub \
  --topic=gmail-notifications \
  --push-endpoint=https://recloop.com/webhook/gmail
```

---

## Step 5: SSL Certificate Setup

### 5.1 Ensure DNS is Configured
Make sure your domain points to your server IP:
```bash
dig recloop.com
```

### 5.2 Install SSL Certificate
```bash
sudo certbot --nginx -d recloop.com -d www.recloop.com
```

Follow the prompts and choose to redirect HTTP to HTTPS.

### 5.3 Test Auto-Renewal
```bash
sudo certbot renew --dry-run
```

---

## Step 6: Deploy the Application

### 6.1 Set Up Git Remote for Deployment
```bash
# On your local machine
git remote add production recloop@your-server-ip:/var/git/recloop.git
```

### 6.2 Deploy via Git Push
```bash
# First deployment
git push production main
```

This will automatically:
- Install all dependencies
- Build frontend and backend
- Deploy to production directories
- Restart PM2 services

### 6.3 Manual Deployment Alternative
If Git deployment doesn't work, deploy manually:
```bash
# On the server
cd /var/www/recloop

# Install dependencies
npm run install:all

# Build applications
npm run build

# Copy frontend build
cp -r frontend/dist/* /var/www/recloop-frontend/

# Start PM2 services
pm2 start ecosystem.config.js
pm2 save
```

---

## Step 7: Configure Convex Backend

### 7.1 Deploy Convex Functions
```bash
cd backend
npx convex deploy --cmd deploy
```

### 7.2 Set Convex Environment Variables
```bash
npx convex env set GOOGLE_CLIENT_ID "your-google-client-id"
npx convex env set GOOGLE_CLIENT_SECRET "your-google-client-secret"
npx convex env set OPENAI_API_KEY "sk-your-openai-api-key"
npx convex env set RESEND_API_KEY "re_your-resend-api-key"
```

---

## Step 8: Start Services and Test

### 8.1 Start All Services
```bash
# Start PM2 processes
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Check status
pm2 status
```

### 8.2 Test Your Deployment

#### Health Checks
```bash
# Test basic health
curl http://localhost/health

# Test HTTPS
curl https://recloop.com/health

# Test webhook endpoint
curl https://recloop.com/webhook/health
```

#### Service Checks
```bash
# Check PM2 services
pm2 logs

# Check Nginx
sudo nginx -t
sudo systemctl status nginx

# Check logs
tail -f /var/log/pm2/*.log
tail -f /var/log/nginx/error.log
```

---

## Step 9: Gmail Push Notifications Setup

### 9.1 Domain Verification
1. Go to [Google Search Console](https://search.google.com/search-console)
2. Add and verify your domain `recloop.com`
3. Download the verification file and place it in your web root

### 9.2 Configure Pub/Sub Push Endpoint
```bash
# Test that your webhook endpoint is accessible
curl -X POST https://recloop.com/webhook/gmail \
  -H "Content-Type: application/json" \
  -d '{"test": "webhook"}'
```

### 9.3 Set Up Gmail Watch (Programmatically)
This happens automatically when users connect their Gmail through your app's OAuth flow.

---

## Step 10: Multi-User Email Aliases

### 10.1 Configure Email Domain (Optional)
If you want to use custom email aliases like `nick@recloop.com`:

1. Set up MX records in your DNS:
```
MX 10 recloop.com
```

2. Install and configure Postfix:
```bash
sudo apt install postfix
sudo dpkg-reconfigure postfix
```

3. Configure virtual aliases in `/etc/postfix/virtual`:
```
nick@recloop.com    recloop@localhost
sana@recloop.com    recloop@localhost
```

---

## Step 11: Monitoring and Maintenance

### 11.1 Set Up Log Monitoring
```bash
# View real-time logs
pm2 logs

# Monitor system resources
htop

# Check disk usage
df -h

# Monitor network
nload
```

### 11.2 Automated Backups
Backups are automatically configured via cron:
- Daily database backups at 3:00 AM
- Log rotation
- SSL certificate auto-renewal

### 11.3 Update Deployment
For future updates:
```bash
# Local machine
git add .
git commit -m "Production update"
git push production main
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. PM2 Services Not Starting
```bash
# Check logs
pm2 logs

# Restart services
pm2 restart ecosystem.config.js

# Reload PM2 configuration
pm2 reload ecosystem.config.js
```

#### 2. Nginx Configuration Issues
```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo nginx -s reload

# Check error logs
sudo tail -f /var/log/nginx/error.log
```

#### 3. SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Manual renewal
sudo certbot renew

# Check renewal logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

#### 4. Git Deployment Issues
```bash
# Check hook permissions
ls -la /var/git/recloop.git/hooks/

# Make sure post-receive hook is executable
chmod +x /var/git/recloop.git/hooks/post-receive

# Check deployment logs
tail -f /var/log/recloop/deploy.log
```

#### 5. Environment Variable Issues
```bash
# Check if variables are loaded
printenv | grep CONVEX
printenv | grep GOOGLE

# Restart services after env changes
pm2 restart ecosystem.config.js
```

---

## 📊 Performance Optimization

### 1. Enable Gzip Compression
Already configured in Nginx, but you can verify:
```bash
curl -H "Accept-Encoding: gzip" -I https://recloop.com
```

### 2. Monitor Resource Usage
```bash
# Memory usage
free -h

# CPU usage
top

# Disk I/O
iotop

# Network usage
nload
```

### 3. Scale PM2 Processes
If you need more capacity:
```bash
# Scale specific apps
pm2 scale recloop-webhook 2

# Monitor performance
pm2 monit
```

---

## 🔒 Security Best Practices

### 1. Regular Updates
```bash
# Monthly security updates
sudo apt update && sudo apt upgrade

# Update Node.js packages
npm audit && npm audit fix
```

### 2. Monitor Logs
```bash
# Check for suspicious activity
sudo tail -f /var/log/auth.log
sudo tail -f /var/log/fail2ban.log
```

### 3. Backup Strategy
- Database backups: Daily at 3 AM
- Code backups: Git repository
- Configuration backups: Include in daily backup
- Test restore procedures monthly

---

## ✅ Production Checklist

Before going live:

- [ ] Domain DNS configured correctly
- [ ] SSL certificates installed and auto-renewal working
- [ ] All environment variables configured
- [ ] Google APIs enabled and OAuth configured
- [ ] Convex backend deployed and configured
- [ ] PM2 services running and saved
- [ ] Nginx configuration tested
- [ ] Health checks passing
- [ ] Gmail push notifications configured
- [ ] Backup systems working
- [ ] Monitoring and logging set up
- [ ] Security configurations applied
- [ ] Test user authentication flow
- [ ] Test email scheduling workflow
- [ ] Load testing completed

---

## 🎉 Success!

Your ReCloop AI scheduling assistant is now fully deployed and ready for production use!

**Access your application at**: https://recloop.com

**Admin endpoints**:
- Health check: https://recloop.com/health
- Webhook health: https://recloop.com/webhook/health

For ongoing maintenance and updates, refer to the troubleshooting section above.

---

**Need help?** Check the logs first:
```bash
pm2 logs
sudo tail -f /var/log/nginx/error.log
tail -f /var/log/recloop/deploy.log
```