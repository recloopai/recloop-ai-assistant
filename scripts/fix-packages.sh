#!/bin/bash

# ReCloop AI - Fix Broken Packages Script
# Run this script to resolve package dependency issues on Ubuntu

set -e

echo "🔧 Fixing broken packages and dependencies..."

# Update package lists
echo "📦 Updating package lists..."
sudo apt update

# Fix broken packages
echo "🔨 Fixing broken packages..."
sudo apt --fix-broken install -y

# Clean package cache
echo "🧹 Cleaning package cache..."
sudo apt clean
sudo apt autoclean

# Remove any orphaned packages
echo "🗑️ Removing orphaned packages..."
sudo apt autoremove -y

# Configure any unconfigured packages
echo "⚙️ Configuring unconfigured packages..."
sudo dpkg --configure -a

# Force fix any remaining issues
echo "💪 Force fixing remaining issues..."
sudo apt-get -f install -y

# Update again after fixes
echo "🔄 Updating after fixes..."
sudo apt update && sudo apt upgrade -y

# Check for any remaining issues
echo "🔍 Checking for remaining issues..."
if ! sudo apt check; then
    echo "⚠️ Some issues remain. Attempting additional fixes..."
    
    # Reset package database
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    sudo apt update
    
    # Try fixing again
    sudo apt --fix-broken install -y
    sudo dpkg --configure -a
fi

echo "✅ Package fixes completed!"
echo ""
echo "Now you can proceed with the installation:"
echo "1. Run: ./scripts/setup-server.sh"
echo "2. Or install individual packages as needed"