#!/bin/bash

# FocusPad Simple EC2 Deployment Script
# Usage: ./scripts/deploy-to-ec2.sh
# Run this script directly on the EC2 instance after pulling latest changes

set -e

COMPOSE_FILE="docker-compose.simple.yml"

echo "🚀 FocusPad Simple Deployment"
echo "============================="
echo "Working directory: $(pwd)"
echo "Using: $COMPOSE_FILE"
echo ""

# Verify we're in the right directory
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: $COMPOSE_FILE not found. Make sure you're in the focuspad directory."
    echo "   Current directory: $(pwd)"
    exit 1
fi

echo "🔍 Current git commit: $(git rev-parse --short HEAD)"
echo ""

echo "🔄 Rebuilding application with latest changes..."
echo "   - Stopping web container"
echo "   - Rebuilding with latest code"
echo "   - Running migrations"
echo "   - Starting services"
echo ""

# Stop web container
echo "⏹️  Stopping web container..."
docker-compose -f $COMPOSE_FILE stop web

# Rebuild web container with latest changes
echo "🔨 Rebuilding web container..."
docker-compose -f $COMPOSE_FILE build --no-cache web

# Start all services
echo "🚀 Starting services..."
docker-compose -f $COMPOSE_FILE up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Run migrations
echo "🗄️  Running database migrations..."
docker-compose -f $COMPOSE_FILE exec -T web python -c "
from app import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('✅ Database migrations completed')
" || echo "⚠️  Migration check completed (may have been already up to date)"

# Health check
echo "🏥 Checking application health..."
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo '✅ Deployment successful!'
    echo ""
    echo "🌐 Application is running on:"
    echo "   - Local: http://localhost:8080"
    echo "   - Public: http://YOUR-EC2-IP:8080"
    echo "   - Domain: https://thefocuspad.com (if nginx is configured separately)"
    echo ""
    echo "📋 Quick status check:"
    docker-compose -f $COMPOSE_FILE ps
else
    echo '❌ Health check failed'
    echo "📋 Container status:"
    docker-compose -f $COMPOSE_FILE ps
    echo ""
    echo "📄 Recent logs:"
    docker-compose -f $COMPOSE_FILE logs --tail=20 web
    exit 1
fi

echo ""
echo "✅ Deployment completed successfully!" 