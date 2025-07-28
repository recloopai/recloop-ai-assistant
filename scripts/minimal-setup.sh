#!/bin/bash

# ReCloop AI - Minimal Server Setup Script
# Use this if the main setup script encounters package conflicts

set -e

echo "🚀 Starting minimal ReCloop AI server setup..."

# Function to safely install packages
safe_install() {
    local package=$1
    echo "📦 Installing $package..."
    if sudo apt install -y "$package"; then
        echo "✅ Successfully installed $package"
    else
        echo "❌ Failed to install $package - continuing anyway"
    fi
}

# Update system first
echo "📦 Updating system packages..."
sudo apt update

# Install essential packages one by one
echo "📦 Installing essential packages..."

# Core system tools
safe_install curl
safe_install wget
safe_install git
safe_install htop

# Install Node.js using NodeSource repository (more reliable)
echo "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
safe_install nodejs

# Verify Node.js installation
if command -v node > /dev/null 2>&1; then
    echo "✅ Node.js installed: $(node --version)"
    echo "✅ npm installed: $(npm --version)"
else
    echo "❌ Node.js installation failed"
    exit 1
fi

# Install PM2 globally
echo "📦 Installing PM2..."
if sudo npm install -g pm2; then
    echo "✅ PM2 installed successfully"
else
    echo "❌ PM2 installation failed"
    exit 1
fi

# Install Nginx
echo "📦 Installing Nginx..."
safe_install nginx

# Install Certbot for SSL
echo "📦 Installing Certbot..."
safe_install snapd
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# Install firewall
echo "📦 Installing UFW firewall..."
safe_install ufw

# Configure firewall
echo "🔥 Configuring firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

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

# Start and enable Nginx
echo "🔄 Starting services..."
sudo systemctl start nginx
sudo systemctl enable nginx

# Set up PM2 startup
echo "⚙️ Configuring PM2 startup..."
pm2 startup
echo "❗ IMPORTANT: Run the command shown above as root to complete PM2 startup configuration"

echo "✅ Minimal setup complete!"
echo ""
echo "Next steps:"
echo "1. Point your domain 'recloop.com' to this server's IP address"
echo "2. Clone your repository: git clone https://github.com/recloopai/recloop-ai-assistant.git /var/www/recloop"
echo "3. Configure environment: cd /var/www/recloop && cp .env.example .env"
echo "4. Edit .env with your API keys"
echo "5. Run: ./scripts/quick-deploy.sh"
echo "6. Set up SSL: sudo certbot --nginx -d recloop.com -d www.recloop.com"
echo ""
echo "🔄 Git deployment URL: $USER@$(hostname -I | awk '{print $1}'):/var/git/recloop.git"