#!/bin/bash

# ReCloop AI Deployment Script
# This script handles automatic deployment when code is pushed to the repository

set -e  # Exit on any error

echo "🚀 Starting ReCloop AI deployment..."

# Configuration
PROJECT_ROOT="/var/www/recloop"
BACKUP_DIR="/var/backups/recloop"
LOG_FILE="/var/log/recloop-deploy.log"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    log "❌ ERROR: Deployment failed at step: $1"
    exit 1
}

# Backup current deployment
log "📦 Creating backup of current deployment..."
if [ -d "$PROJECT_ROOT" ]; then
    tar -czf "$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz" -C "$PROJECT_ROOT" . || handle_error "backup creation"
fi

# Navigate to project directory
cd "$PROJECT_ROOT" || handle_error "navigation to project directory"

# Pull latest changes
log "📥 Pulling latest changes from Git..."
git fetch origin main || handle_error "git fetch"
git reset --hard origin/main || handle_error "git reset"

# Install/update dependencies
log "📦 Installing dependencies..."
npm run install:all || handle_error "dependency installation"

# Build applications
log "🔨 Building applications..."
npm run build || handle_error "build process"

# Restart services with PM2
log "🔄 Restarting services..."
pm2 restart ecosystem.config.js || handle_error "service restart"

# Health check
log "🏥 Performing health check..."
sleep 10

# Check if services are running
if pm2 list | grep -q "online"; then
    log "✅ Health check passed - services are running"
else
    log "❌ Health check failed - services may not be running properly"
    pm2 status
    exit 1
fi

# Clean up old backups (keep last 5)
log "🧹 Cleaning up old backups..."
cd "$BACKUP_DIR"
ls -t backup-*.tar.gz | tail -n +6 | xargs -r rm

log "🎉 Deployment completed successfully!"
log "📊 Service status:"
pm2 status

# Send deployment notification (optional)
# curl -X POST "YOUR_WEBHOOK_URL" -d "Deployment completed successfully at $(date)"

echo "Deployment completed! Check logs at $LOG_FILE"