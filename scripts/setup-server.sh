#!/bin/bash

# 🚀 ReCloop AI Production Server Setup Script
# Run this script on your Ubuntu server to set up the complete production environment
# Usage: chmod +x scripts/setup-server.sh && ./scripts/setup-server.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please run this script as a regular user with sudo privileges, not as root"
fi

# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    error "This script is designed for Ubuntu. Detected: $(cat /etc/os-release | grep PRETTY_NAME)"
fi

log "🚀 Starting ReCloop AI production server setup..."

# ===========================================
# 📦 SYSTEM UPDATES AND PACKAGES
# ===========================================
log "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

log "📦 Installing essential packages..."
sudo apt install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    curl \
    wget \
    git \
    htop \
    iotop \
    nload \
    ufw \
    fail2ban \
    logrotate \
    unzip \
    zip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential

# ===========================================
# 🟢 NODE.JS AND NPM INSTALLATION
# ===========================================
log "🟢 Installing Node.js and NPM..."

# Install Node.js 20.x LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node_version=$(node --version)
npm_version=$(npm --version)
log "Node.js version: $node_version"
log "NPM version: $npm_version"

# Install PM2 globally
log "📦 Installing PM2 process manager..."
sudo npm install -g pm2

# ===========================================
# 📁 DIRECTORY STRUCTURE
# ===========================================
log "📁 Creating application directories..."
sudo mkdir -p /var/www/recloop
sudo mkdir -p /var/www/recloop-frontend
sudo mkdir -p /var/www/recloop-backend
sudo mkdir -p /var/log/recloop
sudo mkdir -p /var/log/pm2
sudo mkdir -p /var/backups/recloop
sudo mkdir -p /var/git
sudo mkdir -p /home/$USER/.ssh

# Create git repository for deployments
log "📁 Setting up Git deployment repository..."
sudo mkdir -p /var/git/recloop.git
cd /var/git/recloop.git
sudo git init --bare
sudo chown -R $USER:$USER /var/git

# ===========================================
# 🔐 PERMISSIONS AND OWNERSHIP
# ===========================================
log "🔐 Setting proper permissions..."
sudo chown -R $USER:$USER /var/www/recloop*
sudo chown -R $USER:$USER /var/log/recloop
sudo chown -R $USER:$USER /var/log/pm2
sudo chown -R $USER:$USER /var/backups/recloop
sudo chown -R www-data:www-data /var/www
sudo chmod -R 755 /var/www

# ===========================================
# 🔥 FIREWALL CONFIGURATION
# ===========================================
log "🔥 Configuring UFW firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
sudo ufw --force enable

# ===========================================
# 🛡️ FAIL2BAN CONFIGURATION
# ===========================================
log "🛡️ Configuring Fail2Ban..."
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Create custom Fail2Ban configuration for Nginx
sudo tee /etc/fail2ban/jail.d/nginx-recloop.conf > /dev/null <<EOF
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 600
findtime = 600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 600
findtime = 600
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# ===========================================
# 🌐 NGINX CONFIGURATION
# ===========================================
log "🌐 Configuring Nginx..."

# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Create Nginx configuration for ReCloop
sudo tee /etc/nginx/sites-available/recloop > /dev/null <<'EOF'
# ReCloop AI Nginx Configuration
server {
    listen 80;
    server_name recloop.com www.recloop.com;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=webhook:10m rate=5r/s;
    
    # Frontend - Serve static files
    location / {
        root /var/www/recloop-frontend/dist;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # API endpoints - Proxy to backend
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://localhost:3001/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Webhook endpoints
    location /webhook/ {
        limit_req zone=webhook burst=10 nodelay;
        proxy_pass http://localhost:3001/webhook/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Security: Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/recloop /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t || error "Nginx configuration test failed"

# ===========================================
# 📊 LOG ROTATION CONFIGURATION
# ===========================================
log "📊 Setting up log rotation..."

sudo tee /etc/logrotate.d/recloop > /dev/null <<EOF
/var/log/recloop/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        pm2 reloadLogs
    endscript
}

/var/log/pm2/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

# ===========================================
# ⏰ CRON JOBS FOR MAINTENANCE
# ===========================================
log "⏰ Setting up maintenance cron jobs..."

# Add cron jobs for automated maintenance
(crontab -l 2>/dev/null; echo "# ReCloop AI Maintenance Tasks") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/bin/certbot renew --quiet") | crontab -
(crontab -l 2>/dev/null; echo "0 3 * * * tar -czf /var/backups/recloop/backup-$(date +%Y%m%d-%H%M%S).tar.gz /var/www/recloop") | crontab -
(crontab -l 2>/dev/null; echo "0 4 * * * find /var/backups/recloop -name '*.tar.gz' -mtime +30 -delete") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * curl -fs http://localhost/health > /dev/null || pm2 restart ecosystem.config.js") | crontab -

# ===========================================
# 🔄 GIT DEPLOYMENT HOOKS
# ===========================================
log "🔄 Setting up Git deployment hooks..."

# Create post-receive hook for automatic deployment
tee /var/git/recloop.git/hooks/post-receive > /dev/null <<'EOF'
#!/bin/bash

# ReCloop AI Git Post-Receive Hook
# This script runs automatically when code is pushed to the production repository

set -e

APP_DIR="/var/www/recloop"
FRONTEND_DIR="/var/www/recloop-frontend"
BACKEND_DIR="/var/www/recloop-backend"
LOG_FILE="/var/log/recloop/deploy.log"
USER="recloop"

echo "$(date): Starting deployment..." >> $LOG_FILE

# Checkout the latest code
cd $APP_DIR
git --git-dir=/var/git/recloop.git --work-tree=$APP_DIR checkout main -f

# Install dependencies and build
echo "$(date): Installing dependencies..." >> $LOG_FILE
npm run install:all >> $LOG_FILE 2>&1

echo "$(date): Building applications..." >> $LOG_FILE
npm run build >> $LOG_FILE 2>&1

# Copy built frontend to serve directory
echo "$(date): Deploying frontend..." >> $LOG_FILE
cp -r $APP_DIR/frontend/dist/* $FRONTEND_DIR/

# Deploy backend
echo "$(date): Deploying backend..." >> $LOG_FILE
rsync -av --delete $APP_DIR/backend/ $BACKEND_DIR/
rsync -av --delete $APP_DIR/webhook-server/ $APP_DIR/

# Restart services
echo "$(date): Restarting services..." >> $LOG_FILE
pm2 restart ecosystem.config.js >> $LOG_FILE 2>&1

# Reload Nginx
nginx -t && systemctl reload nginx >> $LOG_FILE 2>&1

echo "$(date): Deployment completed successfully!" >> $LOG_FILE
EOF

chmod +x /var/git/recloop.git/hooks/post-receive

# ===========================================
# 🔧 PM2 STARTUP CONFIGURATION
# ===========================================
log "🔧 Configuring PM2 startup..."

# Generate PM2 startup script
pm2 startup systemd -u $USER --hp /home/$USER
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp /home/$USER

# ===========================================
# 🛠️ SYSTEM OPTIMIZATION
# ===========================================
log "🛠️ Optimizing system settings..."

# Increase file descriptor limits
sudo tee -a /etc/security/limits.conf > /dev/null <<EOF
$USER soft nofile 65536
$USER hard nofile 65536
EOF

# Optimize kernel parameters
sudo tee -a /etc/sysctl.conf > /dev/null <<EOF
# ReCloop AI Optimizations
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.ip_local_port_range = 1024 65536
vm.swappiness = 10
EOF

sudo sysctl -p

# ===========================================
# 🔄 SERVICE STARTUP
# ===========================================
log "🔄 Starting and enabling services..."

sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# ===========================================
# ✅ FINAL SETUP
# ===========================================
log "✅ Finalizing setup..."

# Create a deployment user (optional)
if ! id "recloop" &>/dev/null; then
    sudo useradd -m -s /bin/bash recloop
    sudo usermod -aG sudo recloop
    sudo mkdir -p /home/recloop/.ssh
    sudo chown -R recloop:recloop /home/recloop
fi

# Set up SSH key for deployment (if provided)
if [ -f "/tmp/deploy_key.pub" ]; then
    sudo cp /tmp/deploy_key.pub /home/recloop/.ssh/authorized_keys
    sudo chown recloop:recloop /home/recloop/.ssh/authorized_keys
    sudo chmod 600 /home/recloop/.ssh/authorized_keys
fi

# Create initial health check files
echo "healthy" | sudo tee /var/www/recloop-frontend/health.txt > /dev/null

log "🎉 Server setup completed successfully!"
info "Next steps:"
info "1. Configure your domain DNS to point to this server"
info "2. Copy your .env files and configure environment variables"
info "3. Set up SSL certificates: sudo certbot --nginx -d recloop.com"
info "4. Deploy your application: git push production main"
info "5. Start PM2 processes: pm2 start ecosystem.config.js"

warn "Important: Remember to:"
warn "- Configure your environment variables in .env files"
warn "- Set up Google Cloud APIs and OAuth"
warn "- Configure Convex deployment"
warn "- Test all endpoints after deployment"

log "Server is ready for ReCloop AI deployment! 🚀"