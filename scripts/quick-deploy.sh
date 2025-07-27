#!/bin/bash

# ReCloop AI Quick Deployment Script
# Run this on your Ubuntu server after cloning the repository

set -e

echo "🚀 Starting ReCloop AI Quick Deployment..."

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Install root dependencies
echo "📦 Installing root dependencies..."
npm install

# Install frontend dependencies
echo "📦 Installing frontend dependencies..."
cd frontend && npm install && cd ..

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend && npm install && cd ..

# Install webhook server dependencies
echo "📦 Installing webhook server dependencies..."
cd webhook-server && npm install && cd ..

# Build frontend
echo "🔨 Building frontend..."
cd frontend && npm run build && cd ..

# Copy built frontend to nginx directory
echo "📁 Setting up frontend files..."
sudo mkdir -p /var/www/recloop-frontend
sudo cp -r frontend/dist/* /var/www/recloop-frontend/
sudo chown -R www-data:www-data /var/www/recloop-frontend

# Copy nginx configuration
echo "🌐 Setting up Nginx configuration..."
sudo cp nginx/recloop.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/recloop.conf /etc/nginx/sites-enabled/
sudo nginx -t

# Create environment file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "⚙️ Creating environment file..."
    cp .env.example .env
    echo "❗ IMPORTANT: Please edit .env file with your actual values before starting services"
fi

# Set up PM2 log directories
sudo mkdir -p /var/log/pm2
sudo chown -R $USER:$USER /var/log/pm2

# Start services with PM2
echo "🔄 Starting services with PM2..."
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

echo "✅ Quick deployment completed!"
echo ""
echo "🔧 Next steps:"
echo "1. Edit .env file with your actual API keys and configuration"
echo "2. Set up SSL certificate: sudo certbot --nginx -d recloop.com -d www.recloop.com"
echo "3. Restart services: pm2 restart ecosystem.config.js"
echo "4. Check status: pm2 status"
echo "5. View logs: pm2 logs"
echo ""
echo "🌐 Your application should be available at: https://recloop.com"
echo "📊 Health check: https://recloop.com/webhook/health"