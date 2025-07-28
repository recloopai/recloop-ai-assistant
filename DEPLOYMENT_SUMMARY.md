# 🚀 ReCloop AI - Production Deployment Summary

**Repository**: `recloopai/recloop-ai-assistant`
**Domain**: `recloop.com`
**Stack**: React/Vite + Convex + Express/Node.js

---

## ⚡ Quick Start Commands

### 1. Initial Server Setup (One-time)
```bash
# Clone repository on your server
git clone https://github.com/recloopai/recloop-ai-assistant.git
cd recloop-ai-assistant

# Run automated setup
chmod +x scripts/setup-server.sh
./scripts/setup-server.sh
```

### 2. Configure Environment
```bash
# Copy and edit environment files
cp .env.example .env
cp frontend/.env.example frontend/.env.local
cp backend/.env.example backend/.env

# Edit with your actual values
nano .env
nano frontend/.env.local
nano backend/.env
```

### 3. Deploy Application
```bash
# From your local machine
git remote add production recloop@YOUR_SERVER_IP:/var/git/recloop.git
git push production main
```

### 4. Set Up SSL
```bash
# On server
sudo certbot --nginx -d recloop.com -d www.recloop.com
```

---

## 📋 Required API Keys & Credentials

### Google Cloud Platform
- **Client ID**: `123456789-abcdef.apps.googleusercontent.com`
- **Client Secret**: `GOCSPX-your-client-secret`
- **Project ID**: `your-google-project-id`
- **APIs to Enable**: Gmail API, Calendar API, Pub/Sub API

### OpenAI
- **API Key**: `sk-your-openai-api-key`

### Resend (Email Notifications)
- **API Key**: `re_your-resend-api-key`

### Convex (Backend Database)
- **Deployment URL**: `https://your-deployment.convex.cloud`
- **Deploy Key**: From Convex dashboard

---

## 🔧 Key File Locations

| Component | Location | Config File |
|-----------|----------|-------------|
| Frontend | `/var/www/recloop-frontend/` | `.env.local` |
| Backend | `/var/www/recloop-backend/` | `.env` |
| Webhook Server | `/var/www/recloop/webhook-server/` | Uses main `.env` |
| Nginx Config | `/etc/nginx/sites-available/recloop` | - |
| PM2 Config | `/var/www/recloop/ecosystem.config.js` | - |
| Logs | `/var/log/pm2/` and `/var/log/nginx/` | - |

---

## 🚦 Service Management

### PM2 Commands
```bash
pm2 status                    # Check service status
pm2 logs                      # View all logs
pm2 restart ecosystem.config.js  # Restart all services
pm2 save                      # Save current configuration
```

### Nginx Commands
```bash
sudo nginx -t                 # Test configuration
sudo nginx -s reload          # Reload configuration
sudo systemctl status nginx   # Check service status
```

### SSL Certificate Management
```bash
sudo certbot certificates     # List certificates
sudo certbot renew           # Manual renewal
sudo certbot renew --dry-run # Test auto-renewal
```

---

## 🔍 Health Checks & Testing

### Endpoint Tests
```bash
curl https://recloop.com/health           # Basic health check
curl https://recloop.com/webhook/health   # Webhook health check
curl -X POST https://recloop.com/webhook/gmail  # Test webhook
```

### Service Monitoring
```bash
# System resources
htop                          # CPU/Memory usage
df -h                        # Disk usage
netstat -tlnp                # Network connections

# Application logs
tail -f /var/log/pm2/recloop-*.log
tail -f /var/log/nginx/error.log
```

---

## 🔄 Deployment Workflow

### Regular Updates
```bash
# 1. Local development
git add .
git commit -m "Your changes"
git push origin main

# 2. Deploy to production
git push production main
```

### Emergency Rollback
```bash
# SSH to server
ssh recloop@YOUR_SERVER_IP

# Check git history
cd /var/www/recloop
git log --oneline -5

# Rollback to previous commit
git reset --hard PREVIOUS_COMMIT_HASH
pm2 restart ecosystem.config.js
```

---

## 🛠️ Troubleshooting Quick Reference

### Common Issues

| Problem | Solution |
|---------|----------|
| PM2 services not starting | `pm2 logs` → Check error messages → Fix env vars |
| Nginx 502 errors | Check if backend is running: `pm2 status` |
| SSL issues | `sudo certbot renew` or check DNS settings |
| Git push fails | Check SSH keys and repository permissions |
| Webhook not receiving | Verify Pub/Sub configuration and domain |

### Log Locations
```bash
# Application logs
/var/log/pm2/recloop-frontend.log
/var/log/pm2/recloop-backend.log  
/var/log/pm2/recloop-webhook.log

# System logs
/var/log/nginx/error.log
/var/log/nginx/access.log
/var/log/recloop/deploy.log
```

---

## 🔒 Security Checklist

- [ ] SSH key-based authentication only
- [ ] UFW firewall enabled (ports 22, 80, 443)
- [ ] Fail2Ban configured for intrusion prevention
- [ ] SSL certificates installed and auto-renewing
- [ ] Environment variables contain production values (not examples)
- [ ] Google OAuth restricted to your domain
- [ ] Rate limiting enabled in Nginx
- [ ] Regular security updates scheduled

---

## 🎯 Post-Deployment Testing

### 1. User Authentication Flow
- [ ] User can sign up with Google OAuth
- [ ] Gmail and Calendar permissions granted
- [ ] User dashboard loads correctly

### 2. Email Scheduling Workflow  
- [ ] User can create AI assistant (e.g., nick@recloop.com)
- [ ] CC'ing AI on email triggers processing
- [ ] AI suggests meeting times based on calendar
- [ ] Calendar events created successfully
- [ ] Confirmation emails sent

### 3. Admin Functions
- [ ] Health endpoints responding
- [ ] Logs showing normal activity
- [ ] Backup system working
- [ ] SSL auto-renewal configured

---

## 📞 Emergency Contacts & Resources

- **Documentation**: `/README.md` and `/PRODUCTION_DEPLOYMENT_GUIDE.md`
- **Convex Dashboard**: https://dashboard.convex.dev
- **Google Cloud Console**: https://console.cloud.google.com
- **Domain DNS**: Your domain registrar's control panel
- **Server Monitoring**: PM2 built-in monitoring

---

**🚀 You're all set! Your ReCloop AI scheduling assistant is now running in production.**

For detailed setup instructions, see `PRODUCTION_DEPLOYMENT_GUIDE.md`.
For ongoing maintenance, monitor logs and run regular updates.