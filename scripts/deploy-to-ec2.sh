#!/bin/bash

# FocusPad Local EC2 Deployment Script
# Usage: ./scripts/deploy-to-ec2.sh [quick|standard|safe]
# Run this script directly on the EC2 instance after pulling latest changes

set -e

# Configuration
APP_DIR="/home/ubuntu/focuspad"
DEPLOY_TYPE="${1:-standard}"
DOMAIN="thefocuspad.com"

echo "🚀 FocusPad Local EC2 Deployment"
echo "================================"
echo "Deploy type: $DEPLOY_TYPE"
echo "Working directory: $(pwd)"
echo ""

# Verify we're in the right directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo "❌ Error: docker-compose.prod.yml not found. Make sure you're in the focuspad directory."
    echo "   Current directory: $(pwd)"
    echo "   Expected directory: $APP_DIR"
    exit 1
fi

# Check if we have the latest changes
echo "📋 Checking git status..."
git_status=$(git status --porcelain)
if [ -n "$git_status" ]; then
    echo "⚠️  Warning: You have uncommitted local changes:"
    git status --short
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled"
        exit 1
    fi
fi

echo "🔍 Current git commit: $(git rev-parse --short HEAD)"
echo "🌿 Current branch: $(git branch --show-current)"
echo ""

case $DEPLOY_TYPE in
    "quick")
        echo "⚡ Quick deployment (restart only)..."
        echo "   - Restarting web container"
        echo "   - No rebuild, fastest deployment (~30s)"
        echo ""
        
        docker-compose -f docker-compose.prod.yml restart web
        echo "⏳ Waiting for container to start..."
        sleep 5
        
        if curl -s https://$DOMAIN/health > /dev/null; then
            echo '✅ Quick deployment successful!'
        else
            echo '❌ Health check failed'
            exit 1
        fi
        ;;
        
    "standard")
        echo "🔄 Standard deployment (rebuild web container)..."
        echo "   - Stopping web container"
        echo "   - Rebuilding with latest changes"
        echo "   - Starting all services"
        echo "   - Estimated time: ~2-3 minutes"
        echo ""
        
        docker-compose -f docker-compose.prod.yml down web
        echo "🔨 Building web container..."
        docker-compose -f docker-compose.prod.yml build --no-cache web
        echo "🚀 Starting services..."
        docker-compose -f docker-compose.prod.yml up -d
        
        echo "⏳ Waiting for services to stabilize..."
        sleep 10
        
        if curl -s https://$DOMAIN/health > /dev/null; then
            echo '✅ Standard deployment successful!'
        else
            echo '❌ Health check failed'
            echo "📋 Checking container status..."
            docker-compose -f docker-compose.prod.yml ps
            exit 1
        fi
        ;;
        
    "safe")
        echo "🛡️ Safe deployment (with backup)..."
        echo "   - Creating database backup"
        echo "   - Full container rebuild"
        echo "   - Complete service restart"
        echo "   - Estimated time: ~5 minutes"
        echo ""
        
        timestamp=$(date +%Y%m%d_%H%M%S)
        backup_dir="backups/deployments/$timestamp"
        
        echo "📦 Creating backup directory: $backup_dir"
        mkdir -p "$backup_dir"
        
        # Create database backup
        echo "💾 Creating database backup..."
        if docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U focuspad_user focuspad > "$backup_dir/database_backup.sql"; then
            echo "✅ Database backup created"
        else
            echo "⚠️  Database backup failed, continuing anyway..."
        fi
        
        # Save container logs
        echo "📄 Saving container logs..."
        docker-compose -f docker-compose.prod.yml logs > "$backup_dir/container_logs.txt" 2>&1
        
        # Full rebuild
        echo "🔄 Stopping all containers..."
        docker-compose -f docker-compose.prod.yml down
        
        echo "🔨 Rebuilding all containers..."
        docker-compose -f docker-compose.prod.yml build --no-cache
        
        echo "🚀 Starting all services..."
        docker-compose -f docker-compose.prod.yml up -d
        
        echo "⏳ Waiting for services to fully initialize..."
        sleep 15
        
        if curl -s https://$DOMAIN/health > /dev/null; then
            echo "✅ Safe deployment successful!"
            echo "📦 Backup saved to: $backup_dir"
        else
            echo "❌ Health check failed"
            echo "📦 Backup available at: $backup_dir"
            echo "📋 Checking container status..."
            docker-compose -f docker-compose.prod.yml ps
            exit 1
        fi
        ;;
        
    *)
        echo "❌ Invalid deploy type. Usage:"
        echo ""
        echo "  ./scripts/deploy-to-ec2.sh quick     # Restart only (~30s)"
        echo "  ./scripts/deploy-to-ec2.sh standard  # Rebuild web container (~2-3min)"
        echo "  ./scripts/deploy-to-ec2.sh safe      # Full rebuild with backup (~5min)"
        echo ""
        exit 1
        ;;
esac

echo ""
echo "🌐 Application URL: https://$DOMAIN"
echo "🏥 Health Check: https://$DOMAIN/health"
echo ""
echo "📋 Useful commands:"
echo "   Check logs:   docker-compose -f docker-compose.prod.yml logs -f web"
echo "   Check status: docker-compose -f docker-compose.prod.yml ps"
echo "   Check health: curl -s https://$DOMAIN/health"
echo ""
echo "✅ Deployment completed successfully!" 