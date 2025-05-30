#!/bin/bash

# FocusPad EC2 Deployment Script
# Usage: ./scripts/deploy-to-ec2.sh [quick|standard|safe]

set -e

# Configuration
EC2_KEY="/Users/elan/Documents/mahesh/code/aws/focuspad/focuspad.pem"
EC2_HOST="ubuntu@3.18.214.69"
APP_DIR="/home/ubuntu/focuspad"
DEPLOY_TYPE="${1:-standard}"

echo "🚀 FocusPad EC2 Deployment"
echo "=========================="
echo "Deploy type: $DEPLOY_TYPE"
echo "Target: $EC2_HOST"
echo ""

# Ensure we have latest local changes
if ! git diff --quiet; then
    echo "⚠️  You have uncommitted changes. Commit them first:"
    git status --short
    exit 1
fi

# Push to remote repository
echo "📤 Pushing latest changes to repository..."
git push origin main

case $DEPLOY_TYPE in
    "quick")
        echo "⚡ Quick deployment (restart only)..."
        ssh -i "$EC2_KEY" "$EC2_HOST" "
            cd $APP_DIR && 
            git pull origin main && 
            docker-compose -f docker-compose.prod.yml restart web &&
            sleep 5 &&
            curl -s https://thefocuspad.com/health > /dev/null && echo '✅ Quick deployment successful!' || echo '❌ Health check failed'
        "
        ;;
        
    "standard")
        echo "🔄 Standard deployment (rebuild web container)..."
        ssh -i "$EC2_KEY" "$EC2_HOST" "
            cd $APP_DIR && 
            git pull origin main && 
            docker-compose -f docker-compose.prod.yml down web &&
            docker-compose -f docker-compose.prod.yml build --no-cache web &&
            docker-compose -f docker-compose.prod.yml up -d &&
            sleep 10 &&
            curl -s https://thefocuspad.com/health > /dev/null && echo '✅ Standard deployment successful!' || echo '❌ Health check failed'
        "
        ;;
        
    "safe")
        echo "🛡️ Safe deployment (with backup)..."
        timestamp=$(date +%Y%m%d_%H%M%S)
        ssh -i "$EC2_KEY" "$EC2_HOST" "
            cd $APP_DIR && 
            echo '📦 Creating backup...' &&
            mkdir -p backups/deployments/$timestamp &&
            docker-compose -f docker-compose.prod.yml exec -T db pg_dump -U focuspad_user focuspad > backups/deployments/$timestamp/database_backup.sql &&
            docker-compose -f docker-compose.prod.yml logs > backups/deployments/$timestamp/container_logs.txt &&
            echo '📥 Pulling latest changes...' &&
            git pull origin main && 
            echo '🔄 Rebuilding containers...' &&
            docker-compose -f docker-compose.prod.yml down &&
            docker-compose -f docker-compose.prod.yml build --no-cache &&
            docker-compose -f docker-compose.prod.yml up -d &&
            sleep 15 &&
            curl -s https://thefocuspad.com/health > /dev/null && echo '✅ Safe deployment successful! Backup: $timestamp' || echo '❌ Health check failed. Backup available: $timestamp'
        "
        ;;
        
    *)
        echo "❌ Invalid deploy type. Use: quick, standard, or safe"
        exit 1
        ;;
esac

echo ""
echo "🌐 Application URL: https://thefocuspad.com"
echo "📊 Health Check: https://thefocuspad.com/health"
echo ""
echo "📋 Useful commands:"
echo "   Check logs: ssh -i $EC2_KEY $EC2_HOST 'cd $APP_DIR && docker-compose -f docker-compose.prod.yml logs -f web'"
echo "   Check status: ssh -i $EC2_KEY $EC2_HOST 'cd $APP_DIR && docker-compose -f docker-compose.prod.yml ps'"
echo "   Connect: ssh -i $EC2_KEY $EC2_HOST"
echo ""
echo "✅ Deployment completed!" 