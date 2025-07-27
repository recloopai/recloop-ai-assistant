# 🔄 ReCloop AI - AI-Powered Email Scheduling Assistant

ReCloop AI is a full-stack SaaS application that allows users to CC an AI agent on email threads to automatically schedule meetings using Gmail + Google Calendar + OpenAI. The AI assistant analyzes email content, suggests optimal meeting times, creates calendar events, and responds professionally on behalf of users.

## 🚀 Features

- **AI-Powered Scheduling**: OpenAI GPT-4 analyzes emails and suggests optimal meeting times
- **Gmail Integration**: Push notifications via Google Pub/Sub for real-time email processing
- **Google Calendar**: Automatic event creation with smart conflict detection
- **Multi-User Support**: Each user gets their own AI assistant (e.g., nick@recloop.com, sana@recloop.com)
- **Smart Preferences**: Timezone, working hours, buffer time, and meeting duration settings
- **Production Ready**: Full deployment on your own VPS with PM2, Nginx, and SSL

## 🏗️ Architecture

```
Frontend (React/Vite) → Nginx → HTTPS (Let's Encrypt)
Backend (Convex) → Database & Real-time Functions
Webhook Server (Express) → Gmail Push Notifications → OpenAI → Calendar API
```

## 📋 Prerequisites

- Ubuntu server with SSH access
- Domain name pointing to your server (e.g., recloop.com)
- Google Cloud Project with Gmail and Calendar APIs enabled
- OpenAI API key
- Resend API key (for notifications)

## 🔧 Quick Start

### 1. Clone and Setup Repository

```bash
# Clone your repository
git clone <your-repo-url> /var/www/recloop
cd /var/www/recloop

# Install dependencies
npm run install:all
```

### 2. Server Setup

Run the automated server setup script:

```bash
chmod +x scripts/setup-server.sh
./scripts/setup-server.sh
```

This script will:
- Install Node.js, Nginx, PM2, Certbot
- Configure firewall and security
- Set up Git deployment hooks
- Configure log rotation
- Create necessary directories

### 3. Environment Configuration

Copy and configure your environment variables:

```bash
cp .env.example .env
nano .env
```

Fill in all the required values:

```env
# Domain Configuration
DOMAIN=recloop.com
FRONTEND_URL=https://recloop.com
WEBHOOK_URL=https://recloop.com/webhook

# Convex Configuration
CONVEX_URL=your-convex-deployment-url
CONVEX_DEPLOY_KEY=your-convex-deploy-key

# Google Workspace OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_REDIRECT_URI=https://recloop.com/auth/google/callback

# OpenAI Configuration
OPENAI_API_KEY=your-openai-api-key

# Resend API
RESEND_API_KEY=your-resend-api-key

# Other required variables...
```

### 4. SSL Certificate Setup

```bash
sudo certbot --nginx -d recloop.com -d www.recloop.com
```

### 5. Deploy Application

```bash
# Build and start all services
npm run build
npm run start

# Check status
pm2 status
pm2 logs
```

## 🔄 Auto-Deployment Setup

### Git Hook Deployment

The setup script creates a bare Git repository for automatic deployment:

```bash
# Add remote to your local repository
git remote add production user@your-server-ip:/var/git/recloop.git

# Deploy by pushing to production
git push production main
```

Every push to the production remote will:
1. Pull latest code
2. Install dependencies
3. Build applications
4. Restart PM2 services
5. Perform health checks

### Webhook Deployment (Alternative)

Set up GitHub webhook pointing to `https://recloop.com/webhook/deploy` for automatic deployment on push.

## 🔧 Google API Setup

### 1. Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project or select existing one
3. Enable Gmail API and Calendar API
4. Enable Google Pub/Sub API

### 2. OAuth Configuration

1. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client ID**
2. Set **Authorized redirect URIs** to: `https://recloop.com/auth/google/callback`
3. Add your domain to **Authorized JavaScript origins**

### 3. Gmail Push Notifications Setup

```bash
# Create Pub/Sub topic
gcloud pubsub topics create gmail-notifications

# Create subscription
gcloud pubsub subscriptions create gmail-notifications-sub --topic=gmail-notifications

# Set webhook endpoint
gcloud pubsub subscriptions modify-push-config gmail-notifications-sub \
  --push-endpoint=https://recloop.com/webhook/gmail
```

### 4. Gmail API Watch Setup

For each user, set up Gmail watch (this can be automated in your app):

```javascript
// This happens automatically when users connect their Gmail
gmail.users.watch({
  userId: 'me',
  resource: {
    topicName: 'projects/your-project/topics/gmail-notifications',
    labelIds: ['INBOX']
  }
});
```

## 🎯 Usage

### For End Users

1. **Sign Up**: Users create account and choose AI assistant name
2. **Connect Gmail**: OAuth flow to authorize Gmail access
3. **Connect Calendar**: OAuth flow to authorize Calendar access
4. **Configure Preferences**: Set timezone, working hours, meeting preferences
5. **Use AI Assistant**: CC their AI assistant (e.g., nick@recloop.com) on email threads about scheduling

### AI Assistant Workflow

1. **Email Detection**: Gmail push notification triggers when AI is CC'd
2. **Content Analysis**: OpenAI analyzes email content for scheduling intent
3. **Time Suggestion**: AI suggests optimal time based on user preferences and calendar availability
4. **Event Creation**: Creates Google Calendar event with all participants
5. **Email Response**: Sends professional response confirming the meeting

## 📊 Monitoring & Maintenance

### PM2 Process Management

```bash
# View status
pm2 status

# View logs
pm2 logs
pm2 logs recloop-frontend
pm2 logs recloop-backend
pm2 logs recloop-webhook

# Restart services
pm2 restart ecosystem.config.js

# Stop services
pm2 stop ecosystem.config.js
```

### Health Checks

- **Frontend**: `https://recloop.com/health`
- **Webhook Server**: `https://recloop.com/webhook/health`
- **Nginx Status**: `sudo systemctl status nginx`

### Log Files

- **Application Logs**: `/var/log/pm2/`
- **Nginx Logs**: `/var/log/nginx/`
- **Deployment Logs**: `/var/log/recloop-deploy.log`

### Database Monitoring

Convex provides built-in monitoring dashboard. Access via your Convex deployment URL.

## 🔒 Security Features

- **HTTPS**: Let's Encrypt SSL certificates with auto-renewal
- **Rate Limiting**: Webhook endpoints protected against abuse
- **Firewall**: UFW configured to only allow necessary ports
- **Fail2ban**: Protection against brute force attacks
- **Security Headers**: Comprehensive security headers in Nginx
- **Token Encryption**: User tokens encrypted at rest
- **Input Validation**: All webhook inputs validated

## 🚀 Advanced Configuration

### Custom Email Domains

To use your own domain for AI assistants:

1. Set up MX records pointing to your server
2. Configure Postfix for email handling
3. Update `EMAIL_DOMAIN` in environment variables

### Scaling

For high-volume usage:

1. **Database**: Convex automatically scales
2. **Webhook Server**: Increase PM2 instances in `ecosystem.config.js`
3. **Rate Limits**: Adjust Nginx rate limiting
4. **Server Resources**: Monitor CPU/memory usage

### Backup Strategy

```bash
# Automated backups are created on each deployment
ls /var/backups/recloop/

# Manual backup
tar -czf backup-$(date +%Y%m%d).tar.gz /var/www/recloop
```

## 🛠️ Development

### Local Development

```bash
# Install dependencies
npm run install:all

# Start development servers
npm run dev

# Frontend: http://localhost:3000
# Webhook server: http://localhost:3001
# Backend: Convex dev dashboard
```

### Testing Webhooks Locally

Use ngrok to expose local webhook server:

```bash
ngrok http 3001
# Use the ngrok URL for Google Pub/Sub webhook endpoint
```

## 🐛 Troubleshooting

### Common Issues

1. **Gmail API Quota Exceeded**
   - Check Google Cloud Console quotas
   - Implement exponential backoff

2. **Webhook Not Receiving**
   - Verify Pub/Sub topic and subscription
   - Check firewall settings
   - Validate webhook endpoint URL

3. **SSL Certificate Issues**
   - Ensure domain points to server
   - Run `sudo certbot renew --dry-run`

4. **PM2 Services Not Starting**
   - Check logs: `pm2 logs`
   - Verify environment variables
   - Check file permissions

### Support

- **Logs**: Always check PM2 and Nginx logs first
- **Health Checks**: Use built-in health endpoints
- **Monitoring**: Set up monitoring alerts for production

## 📝 API Documentation

### Webhook Endpoints

- `POST /webhook/gmail` - Gmail push notifications
- `GET /webhook/health` - Health check
- `POST /webhook/deploy` - Deployment webhook (optional)

### Frontend Environment Variables

Create `frontend/.env.local`:

```env
VITE_CONVEX_URL=your-convex-url
VITE_GOOGLE_CLIENT_ID=your-google-client-id
VITE_API_URL=https://recloop.com/api
```

## 🎉 Deployment Checklist

- [ ] Server setup script completed
- [ ] Domain DNS configured
- [ ] SSL certificates installed
- [ ] Environment variables configured
- [ ] Google APIs enabled and configured
- [ ] Pub/Sub topic and subscription created
- [ ] Gmail watch configured for test user
- [ ] PM2 services running
- [ ] Health checks passing
- [ ] Nginx serving frontend
- [ ] Webhook endpoints responding
- [ ] Test email scheduling workflow

## 📜 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create pull request

---

**🔄 ReCloop AI** - Making email scheduling effortless with AI
