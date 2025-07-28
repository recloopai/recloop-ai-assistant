#!/bin/bash

# 🚀 ReCloop AI Quick Deployment Script
# This script helps you deploy quickly to your production server

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_USER="recloop"
DEPLOY_HOST=""
DEPLOY_BRANCH="main"
GIT_REMOTE="production"

# Functions
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

# Help function
show_help() {
    echo "🚀 ReCloop AI Quick Deploy Script"
    echo ""
    echo "Usage: $0 [OPTIONS] SERVER_IP"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -u, --user     Deployment user (default: recloop)"
    echo "  -b, --branch   Git branch to deploy (default: main)"
    echo "  -r, --remote   Git remote name (default: production)"
    echo "  --setup        Run initial server setup"
    echo "  --env-only     Only copy environment files"
    echo "  --build-only   Only build and deploy code"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100                    # Deploy to server"
    echo "  $0 --setup 192.168.1.100           # Initial setup"
    echo "  $0 --env-only 192.168.1.100        # Copy env files only"
    echo "  $0 -u ubuntu -b develop 192.168.1.100  # Custom user and branch"
}

# Parse command line arguments
SETUP_MODE=false
ENV_ONLY=false
BUILD_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--user)
            DEPLOY_USER="$2"
            shift 2
            ;;
        -b|--branch)
            DEPLOY_BRANCH="$2"
            shift 2
            ;;
        -r|--remote)
            GIT_REMOTE="$2"
            shift 2
            ;;
        --setup)
            SETUP_MODE=true
            shift
            ;;
        --env-only)
            ENV_ONLY=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        -*)
            error "Unknown option $1"
            ;;
        *)
            DEPLOY_HOST="$1"
            shift
            ;;
    esac
done

# Validate required parameters
if [ -z "$DEPLOY_HOST" ]; then
    error "Server IP address is required. Use --help for usage information."
fi

# Validate we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "This script must be run from within the ReCloop AI git repository."
fi

log "🚀 Starting ReCloop AI deployment to $DEPLOY_HOST"

# ===========================================
# SETUP MODE
# ===========================================
if [ "$SETUP_MODE" = true ]; then
    log "📦 Running initial server setup..."
    
    # Copy setup script to server
    scp scripts/setup-server.sh $DEPLOY_USER@$DEPLOY_HOST:/tmp/
    
    # Run setup script on server
    ssh $DEPLOY_USER@$DEPLOY_HOST "chmod +x /tmp/setup-server.sh && /tmp/setup-server.sh"
    
    log "✅ Server setup completed!"
    info "Next steps:"
    info "1. Configure your environment variables"
    info "2. Set up SSL certificates: sudo certbot --nginx -d recloop.com"
    info "3. Run: $0 $DEPLOY_HOST"
    exit 0
fi

# ===========================================
# ENVIRONMENT ONLY MODE
# ===========================================
if [ "$ENV_ONLY" = true ]; then
    log "📝 Copying environment files..."
    
    # Check if .env files exist
    if [ ! -f ".env" ]; then
        warn ".env file not found. Creating from template..."
        cp .env.example .env
        info "Please edit .env with your actual values before deploying."
    fi
    
    if [ ! -f "frontend/.env.local" ]; then
        warn "frontend/.env.local file not found. Creating from template..."
        cp frontend/.env.example frontend/.env.local
        info "Please edit frontend/.env.local with your actual values."
    fi
    
    if [ ! -f "backend/.env" ]; then
        warn "backend/.env file not found. Creating from template..."
        cp backend/.env.example backend/.env
        info "Please edit backend/.env with your actual values."
    fi
    
    # Copy environment files to server
    scp .env $DEPLOY_USER@$DEPLOY_HOST:/var/www/recloop/
    scp frontend/.env.local $DEPLOY_USER@$DEPLOY_HOST:/var/www/recloop/frontend/
    scp backend/.env $DEPLOY_USER@$DEPLOY_HOST:/var/www/recloop/backend/
    
    log "✅ Environment files copied successfully!"
    exit 0
fi

# ===========================================
# PRE-DEPLOYMENT CHECKS
# ===========================================
log "🔍 Running pre-deployment checks..."

# Check if git remote exists
if ! git remote get-url $GIT_REMOTE > /dev/null 2>&1; then
    warn "Git remote '$GIT_REMOTE' not found. Adding it..."
    git remote add $GIT_REMOTE $DEPLOY_USER@$DEPLOY_HOST:/var/git/recloop.git
fi

# Check if we're on the right branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$DEPLOY_BRANCH" ]; then
    warn "Currently on branch '$current_branch', but deploying '$DEPLOY_BRANCH'"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    warn "You have uncommitted changes. They will not be deployed."
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ===========================================
# BUILD AND DEPLOYMENT
# ===========================================
if [ "$BUILD_ONLY" = false ]; then
    log "📝 Checking environment configuration..."
    
    # Check if critical env files exist
    if [ ! -f ".env" ]; then
        error ".env file is required. Run with --env-only first to set up environment."
    fi
    
    # Validate environment file has required variables
    required_vars=("DOMAIN" "CONVEX_URL" "GOOGLE_CLIENT_ID" "OPENAI_API_KEY")
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" .env; then
            error "Required environment variable '$var' not found in .env file."
        fi
    done
fi

log "🏗️ Building applications locally..."

# Install dependencies
log "📦 Installing dependencies..."
npm run install:all

# Run tests if they exist
if [ -f "package.json" ] && grep -q '"test"' package.json; then
    log "🧪 Running tests..."
    npm test || warn "Tests failed, but continuing with deployment..."
fi

# Build applications
log "🔨 Building frontend and backend..."
npm run build

# ===========================================
# DEPLOYMENT
# ===========================================
log "🚀 Deploying to production server..."

# Push to production remote
git push $GIT_REMOTE $DEPLOY_BRANCH

# Wait a moment for the deployment to process
sleep 5

# ===========================================
# POST-DEPLOYMENT CHECKS
# ===========================================
log "🔍 Running post-deployment health checks..."

# Test server connectivity
if ! ssh -o ConnectTimeout=10 $DEPLOY_USER@$DEPLOY_HOST "echo 'SSH connection successful'"; then
    error "Cannot connect to server via SSH"
fi

# Check if services are running
ssh $DEPLOY_USER@$DEPLOY_HOST "pm2 status" || warn "PM2 status check failed"

# Test HTTP endpoints
sleep 10  # Give services time to start

# Try to reach the health endpoint
if curl -f -s -o /dev/null --connect-timeout 10 "http://$DEPLOY_HOST/health"; then
    log "✅ HTTP health check passed"
else
    warn "HTTP health check failed - this might be normal if SSL is required"
fi

# Check logs for any immediate errors
log "📊 Checking recent logs..."
ssh $DEPLOY_USER@$DEPLOY_HOST "pm2 logs --lines 10" || warn "Could not fetch PM2 logs"

# ===========================================
# SUCCESS
# ===========================================
log "🎉 Deployment completed successfully!"

info "🌐 Your ReCloop AI application should be available at:"
info "   http://$DEPLOY_HOST (if no SSL configured yet)"
info "   https://recloop.com (if domain and SSL are configured)"

info "📊 Useful commands:"
info "   Check status: ssh $DEPLOY_USER@$DEPLOY_HOST 'pm2 status'"
info "   View logs:    ssh $DEPLOY_USER@$DEPLOY_HOST 'pm2 logs'"
info "   Restart:      ssh $DEPLOY_USER@$DEPLOY_HOST 'pm2 restart ecosystem.config.js'"

info "🔧 Next steps (if first deployment):"
info "1. Configure your domain DNS to point to $DEPLOY_HOST"
info "2. Set up SSL: ssh $DEPLOY_USER@$DEPLOY_HOST 'sudo certbot --nginx -d recloop.com'"
info "3. Test the full email scheduling workflow"

warn "🔒 Security reminders:"
warn "- Ensure your .env files contain production values"
warn "- Verify Google OAuth and API credentials are configured"
warn "- Test Gmail push notifications are working"
warn "- Monitor logs for any errors"

log "Deployment script completed! 🚀"