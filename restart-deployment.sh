#!/bin/bash

# Restart FocusPad deployment with proper environment configuration
# This script ensures the .env.production file is loaded correctly

set -e

echo "🔄 Restarting FocusPad deployment..."
echo "==================================="
echo ""

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo "❌ Error: .env.production file not found"
    echo "Please run ./setup-env-micro.sh first"
    exit 1
fi

# Stop containers
echo "🛑 Stopping containers..."
docker-compose -f docker-compose.micro.yml down --remove-orphans

# Clean up Docker resources
echo "🧹 Cleaning up Docker resources..."
docker system prune -af --volumes 2>/dev/null || true

# Wait a moment
sleep 5

# Start containers with environment file
echo "🚀 Starting containers with environment configuration..."
docker-compose -f docker-compose.micro.yml --env-file .env.production up -d

# Wait for containers to start
echo "⏳ Waiting for containers to start..."
sleep 15

# Check status
echo "📊 Container status:"
docker-compose -f docker-compose.micro.yml --env-file .env.production ps

# Test health endpoint
echo ""
echo "🏥 Testing health endpoint..."
sleep 5
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✅ Application is healthy!"
    echo "🌐 Access your app at: https://thefocuspad.com"
else
    echo "⚠️  Health check failed. Check logs:"
    echo "   docker-compose -f docker-compose.micro.yml --env-file .env.production logs -f web"
fi

echo ""
echo "✅ Restart completed!" 