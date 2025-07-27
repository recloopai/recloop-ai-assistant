# 🚀 ReCloop AI Production Deployment Guide

This guide will walk you through deploying your ReCloop AI scheduling SaaS on your Ubuntu server.

## 📋 Prerequisites Checklist

- [ ] Ubuntu server with SSH access
- [ ] Domain `recloop.com` pointing to your server IP
- [ ] Google Cloud Project with APIs enabled
- [ ] OpenAI API key
- [ ] Resend API key
- [ ] GitHub account for repository hosting

## 🔧 Step 1: Create Private GitHub Repository

1. **Create Repository on GitHub**
   ```bash
   # On GitHub.com, create a new private repository named "recloop-ai-assistant"
   ```

2. **Push Code to GitHub**
   ```bash
   # Add GitHub remote (replace with your repository URL)
   git remote add origin https://github.com/yourusername/recloop-ai-assistant.git
   git branch -M main
   git push -u origin main
   ```

## 🖥️ Step 2: Server Initial Setup

1. **Connect to Your Server**
   ```bash
   ssh root@your-server-ip
   # or
   ssh ubuntu@your-server-ip
   ```

2. **Run Server Setup Script**
   ```bash
   # Clone your repository
   git clone https://github.com/yourusername/recloop-ai-assistant.git /var/www/recloop
   cd /var/www/recloop

   # Run setup script
   chmod +x scripts/setup-server.sh
   ./scripts/setup-server.sh
   ```

3. **Configure PM2 Startup** (Follow the command shown in setup output)
   ```bash
   # Run the command shown by PM2 startup (example):
   sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu
   ```

## 🌐 Step 3: Domain and SSL Setup

1. **Verify Domain DNS**
   ```bash
   # Check if domain points to your server
   nslookup recloop.com
   dig recloop.com
   ```

2. **Set Up SSL Certificate**
   ```bash
   sudo certbot --nginx -d recloop.com -d www.recloop.com
   ```

3. **Test SSL Auto-Renewal**
   ```bash
   sudo certbot renew --dry-run
   ```

## ⚙️ Step 4: Configure APIs and Services

### Google Cloud Setup

1. **Create Google Cloud Project**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create new project: "recloop-ai-scheduling"

2. **Enable Required APIs**
   ```bash
   # Enable these APIs in Google Cloud Console:
   - Gmail API
   - Google Calendar API
   - Google Cloud Pub/Sub API
   ```

3. **Create OAuth 2.0 Credentials**
   - Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
   - Application type: **Web application**
   - Authorized redirect URIs: `https://recloop.com/auth/google/callback`
   - Authorized JavaScript origins: `https://recloop.com`

4. **Set Up Pub/Sub for Gmail Push Notifications**
   ```bash
   # Install Google Cloud SDK if not already installed
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init

   # Create Pub/Sub topic and subscription
   gcloud pubsub topics create gmail-notifications
   gcloud pubsub subscriptions create gmail-notifications-sub --topic=gmail-notifications

   # Set webhook endpoint
   gcloud pubsub subscriptions modify-push-config gmail-notifications-sub \
     --push-endpoint=https://recloop.com/webhook/gmail
   ```

### Convex Backend Setup

1. **Install Convex CLI**
   ```bash
   npm install -g convex
   ```

2. **Deploy Convex Backend**
   ```bash
   cd /var/www/recloop/backend
   
   # Login to Convex
   npx convex login
   
   # Deploy backend
   npx convex deploy
   
   # Note the deployment URL for environment configuration
   ```

## 🔐 Step 5: Environment Configuration

1. **Configure Environment Variables**
   ```bash
   cd /var/www/recloop
   cp .env.example .env
   nano .env
   ```

2. **Fill in Environment Variables**
   ```env
   # Domain Configuration
   DOMAIN=recloop.com
   FRONTEND_URL=https://recloop.com
   WEBHOOK_URL=https://recloop.com/webhook

   # Convex Configuration (from step above)
   CONVEX_URL=https://your-deployment.convex.cloud
   CONVEX_DEPLOY_KEY=your-convex-deploy-key

   # Google Workspace OAuth (from Google Cloud Console)
   GOOGLE_CLIENT_ID=your-google-client-id.googleusercontent.com
   GOOGLE_CLIENT_SECRET=your-google-client-secret
   GOOGLE_REDIRECT_URI=https://recloop.com/auth/google/callback

   # Gmail API Configuration
   GMAIL_SCOPES=https://www.googleapis.com/auth/gmail.readonly,https://www.googleapis.com/auth/gmail.send,https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/pubsub

   # Google Calendar API
   CALENDAR_SCOPES=https://www.googleapis.com/auth/calendar,https://www.googleapis.com/auth/calendar.events

   # OpenAI Configuration
   OPENAI_API_KEY=sk-your-openai-api-key
   OPENAI_MODEL=gpt-4

   # Resend API (for notifications)
   RESEND_API_KEY=re_your-resend-api-key
   RESEND_FROM_EMAIL=noreply@recloop.com

   # Google Pub/Sub
   GOOGLE_PUBSUB_TOPIC=gmail-notifications
   GOOGLE_PUBSUB_SUBSCRIPTION=gmail-notifications-sub
   GOOGLE_CLOUD_PROJECT_ID=your-gcp-project-id

   # Security
   JWT_SECRET=your-random-32-character-secret-key
   ENCRYPTION_KEY=your-32-character-encryption-key

   # Server Configuration
   NODE_ENV=production
   PORT=3001
   FRONTEND_PORT=3000
   ```

3. **Configure Frontend Environment**
   ```bash
   cd /var/www/recloop/frontend
   cat > .env.local << EOF
   VITE_CONVEX_URL=https://your-deployment.convex.cloud
   VITE_GOOGLE_CLIENT_ID=your-google-client-id.googleusercontent.com
   VITE_API_URL=https://recloop.com/api
   EOF
   ```

## 🚀 Step 6: Deploy Application

1. **Run Quick Deployment**
   ```bash
   cd /var/www/recloop
   chmod +x scripts/quick-deploy.sh
   ./scripts/quick-deploy.sh
   ```

2. **Verify Services are Running**
   ```bash
   pm2 status
   pm2 logs
   ```

3. **Test Application**
   ```bash
   # Test frontend
   curl https://recloop.com

   # Test webhook health
   curl https://recloop.com/webhook/health

   # Test nginx status
   sudo systemctl status nginx
   ```

## 🔄 Step 7: Set Up Auto-Deployment

### Option A: Git Hook Deployment (Recommended)

1. **Add Production Remote**
   ```bash
   # On your local machine
   git remote add production ubuntu@your-server-ip:/var/git/recloop.git
   ```

2. **Deploy by Pushing**
   ```bash
   # Deploy latest changes
   git push production main
   ```

### Option B: GitHub Webhook (Alternative)

1. **Set Up Webhook Endpoint**
   - Add webhook handler to your webhook server
   - Point GitHub webhook to `https://recloop.com/webhook/deploy`

## 📊 Step 8: Monitoring Setup

1. **Set Up Log Monitoring**
   ```bash
   # View real-time logs
   pm2 logs

   # View specific service logs
   pm2 logs recloop-frontend
   pm2 logs recloop-webhook
   pm2 logs recloop-backend
   ```

2. **Set Up Health Monitoring**
   ```bash
   # Add to crontab for health checks
   crontab -e
   
   # Add these lines:
   */5 * * * * curl -f https://recloop.com/health || echo "Frontend down" | mail -s "ReCloop Alert" your-email@domain.com
   */5 * * * * curl -f https://recloop.com/webhook/health || echo "Webhook down" | mail -s "ReCloop Alert" your-email@domain.com
   ```

## 🧪 Step 9: Testing the Complete Workflow

1. **Create Test User**
   - Visit `https://recloop.com`
   - Sign up with your Gmail account
   - Choose AI assistant name (e.g., "nick")
   - Complete OAuth flow for Gmail and Calendar

2. **Test Email Scheduling**
   ```
   # Send test email to yourself with CC to nick@recloop.com
   Subject: Meeting Request
   Body: "Hi, can we schedule a meeting for tomorrow at 2pm?"
   CC: nick@recloop.com
   ```

3. **Verify AI Response**
   - Check Gmail for AI response
   - Check Google Calendar for created event
   - Check webhook logs: `pm2 logs recloop-webhook`

## 🔒 Step 10: Security Hardening

1. **Review Security Settings**
   ```bash
   # Check firewall status
   sudo ufw status

   # Check fail2ban status
   sudo fail2ban-client status

   # Review SSH configuration
   sudo nano /etc/ssh/sshd_config
   ```

2. **Set Up Backup Strategy**
   ```bash
   # Create backup script
   cat > /home/ubuntu/backup-recloop.sh << 'EOF'
   #!/bin/bash
   DATE=$(date +%Y%m%d-%H%M%S)
   tar -czf /var/backups/recloop/manual-backup-$DATE.tar.gz /var/www/recloop
   echo "Backup created: manual-backup-$DATE.tar.gz"
   EOF

   chmod +x /home/ubuntu/backup-recloop.sh

   # Add to crontab for daily backups
   crontab -e
   # Add: 0 2 * * * /home/ubuntu/backup-recloop.sh
   ```

## ✅ Final Deployment Checklist

- [ ] Server setup script completed successfully
- [ ] Domain DNS points to server IP
- [ ] SSL certificates installed and auto-renewal working
- [ ] All environment variables configured
- [ ] Google Cloud APIs enabled and configured
- [ ] Convex backend deployed and accessible
- [ ] Pub/Sub topic and subscription created
- [ ] PM2 services running (all should show "online")
- [ ] Nginx serving frontend correctly
- [ ] Webhook endpoints responding
- [ ] Health checks passing
- [ ] Auto-deployment working (git push or webhook)
- [ ] Test user created and Gmail/Calendar connected
- [ ] End-to-end email scheduling test successful
- [ ] Monitoring and logging configured
- [ ] Backup strategy implemented

## 🆘 Troubleshooting Common Issues

### Services Not Starting
```bash
# Check PM2 logs
pm2 logs

# Check environment variables
cat .env

# Restart all services
pm2 restart ecosystem.config.js
```

### SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Test nginx configuration
sudo nginx -t
sudo systemctl reload nginx
```

### Gmail API Issues
```bash
# Check Google Cloud Console quotas
# Verify Pub/Sub topic and subscription
# Check webhook logs for errors
pm2 logs recloop-webhook
```

### Frontend Not Loading
```bash
# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Verify frontend build
ls -la /var/www/recloop-frontend/

# Check nginx configuration
sudo nginx -t
```

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review PM2 and Nginx logs
3. Verify all environment variables are set
4. Test individual components (frontend, webhook, backend)
5. Check Google Cloud Console for API quotas and errors

## 🎉 Success!

Once all items in the checklist are complete, your ReCloop AI scheduling assistant should be fully operational at `https://recloop.com`!

Users can now:
1. Sign up and connect their Gmail/Calendar
2. Get their own AI assistant email (e.g., nick@recloop.com)
3. CC their AI assistant on scheduling emails
4. Have meetings automatically scheduled with AI responses

---

**🔄 ReCloop AI** - Your AI-powered scheduling assistant is now live!