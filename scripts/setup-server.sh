#!/bin/bash

# ReCloop AI Server Setup Script
# Run this script on your Ubuntu server to set up the production environment

set -e

echo "🚀 Setting up ReCloop AI production server..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
sudo apt install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    nodejs \
    npm \
    git \
    curl \
    htop \
    ufw \
    fail2ban \
    logrotate

# Install PM2 globally
echo "📦 Installing PM2..."
sudo npm install -g pm2

# Create application directories
echo "📁 Creating application directories..."
sudo mkdir -p /var/www/recloop-frontend
sudo mkdir -p /var/www/recloop-backend
sudo mkdir -p /var/www/recloop
sudo mkdir -p /var/log/pm2
sudo mkdir -p /var/backups/recloop

# Set proper permissions
echo "🔐 Setting permissions..."
sudo chown -R $USER:$USER /var/www/recloop*
sudo chown -R $USER:$USER /var/log/pm2
sudo chown -R $USER:$USER /var/backups/recloop

# Configure firewall
echo "🔥 Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Configure fail2ban
echo "🛡️ Configuring fail2ban..."
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

cat > /tmp/nginx-noscript.conf << 'EOF'
[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

sudo cp /tmp/nginx-noscript.conf /etc/fail2ban/jail.d/
sudo systemctl restart fail2ban

# Configure Git for deployment
echo "📋 Setting up Git deployment..."
sudo mkdir -p /var/git/recloop.git
sudo chown -R $USER:$USER /var/git
cd /var/git/recloop.git
git init --bare

# Create post-receive hook
cat > hooks/post-receive << 'EOF'
#!/bin/bash
cd /var/www/recloop
git --git-dir=/var/git/recloop.git --work-tree=/var/www/recloop checkout -f
./scripts/deploy.sh
EOF

chmod +x hooks/post-receive

# Configure log rotation
echo "📊 Setting up log rotation..."
cat > /tmp/recloop-logrotate << 'EOF'
/var/log/recloop*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
        pm2 reloadLogs
    endscript
}

/var/log/pm2/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

sudo cp /tmp/recloop-logrotate /etc/logrotate.d/recloop

# Set up PM2 startup
echo "⚙️ Configuring PM2 startup..."
pm2 startup
echo "❗ IMPORTANT: Run the command shown above as root to complete PM2 startup configuration"

# Configure Nginx
echo "🌐 Configuring Nginx..."
sudo rm -f /etc/nginx/sites-enabled/default

# Copy nginx config (this assumes you've created the nginx config file)
if [ -f "/var/www/recloop/nginx/recloop.conf" ]; then
    sudo cp /var/www/recloop/nginx/recloop.conf /etc/nginx/sites-available/
    sudo ln -sf /etc/nginx/sites-available/recloop.conf /etc/nginx/sites-enabled/
else
    echo "⚠️ Nginx config file not found. You'll need to configure it manually."
fi

# Test nginx configuration
sudo nginx -t || echo "⚠️ Nginx configuration test failed. Please check the config."

# Create systemd services for monitoring
echo "🔧 Creating systemd services..."
cat > /tmp/recloop-monitor.service << 'EOF'
[Unit]
Description=ReCloop AI Monitor Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/bin/bash -c 'while true; do pm2 status | grep -q "online" || pm2 restart ecosystem.config.js; sleep 60; done'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/recloop-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable recloop-monitor

# Set up SSL certificates (Let's Encrypt)
echo "🔒 Setting up SSL certificates..."
echo "ℹ️ We'll set up a basic cert. You'll need to run certbot after your domain points to this server."

# Create a basic HTML page for initial testing
cat > /tmp/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>ReCloop AI - Coming Soon</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .logo { font-size: 2em; color: #333; margin-bottom: 20px; }
        .status { background: #e8f5e8; padding: 20px; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🔄 ReCloop AI</div>
        <div class="status">
            <h2>Server Setup Complete!</h2>
            <p>Your ReCloop AI scheduling assistant is being configured.</p>
            <p>Server Time: <span id="time"></span></p>
        </div>
    </div>
    <script>
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
EOF

sudo mkdir -p /var/www/html
sudo cp /tmp/index.html /var/www/html/

# Start services
echo "🔄 Starting services..."
sudo systemctl restart nginx
sudo systemctl enable nginx

# Security hardening
echo "🔒 Applying security hardening..."
# Disable root login
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable password authentication (uncomment if you want to use only key-based auth)
# sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

sudo systemctl restart ssh

echo "✅ Server setup complete!"
echo ""
echo "Next steps:"
echo "1. Point your domain 'recloop.com' to this server's IP address"
echo "2. Run: sudo certbot --nginx -d recloop.com -d www.recloop.com"
echo "3. Clone your repository to /var/www/recloop"
echo "4. Configure your environment variables in /var/www/recloop/.env"
echo "5. Run the deployment script: ./scripts/deploy.sh"
echo ""
echo "Server Information:"
echo "- Web root: /var/www/recloop-frontend"
echo "- Application: /var/www/recloop"
echo "- Logs: /var/log/pm2/ and /var/log/nginx/"
echo "- Git repository: /var/git/recloop.git"
echo ""
echo "🔄 Git deployment URL: $USER@$(hostname -I | awk '{print $1}'):/var/git/recloop.git"