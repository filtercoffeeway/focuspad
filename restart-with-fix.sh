#!/bin/bash

# Restart deployment with flask_cli fix
# This script rebuilds the containers and restarts the deployment

set -e

echo "🔧 Restarting deployment with flask_cli fix..."
echo "=============================================="
echo ""

cd /home/ubuntu/focuspad

# Stop all containers
echo "🛑 Stopping containers..."
docker-compose -f docker-compose.micro.yml down --remove-orphans

# Clean up Docker resources to save space
echo "🧹 Cleaning up Docker resources..."
docker system prune -af --volumes

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo "⚠️  .env.production missing, creating it..."
    ./setup-env-micro.sh
fi

# Check memory before rebuilding
echo "💾 Memory before rebuild:"
free -h

# Rebuild the web container (this includes the flask_cli fix)
echo "🏗️  Rebuilding web container with fix..."
docker-compose -f docker-compose.micro.yml build --no-cache web

# Start containers with proper sequencing
echo "🚀 Starting containers..."

# Start database first
echo "🗄️  Starting database..."
docker-compose -f docker-compose.micro.yml up -d db

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
for i in {1..30}; do
    if docker-compose -f docker-compose.micro.yml exec -T db pg_isready -U focuspad_user > /dev/null 2>&1; then
        echo "✅ Database is ready"
        break
    else
        echo "   Attempt $i/30: Waiting 5 seconds..."
        sleep 5
    fi
done

# Start web container
echo "🌐 Starting web container..."
docker-compose -f docker-compose.micro.yml up -d web

# Wait for web container to start
echo "⏳ Waiting for web container to start..."
sleep 30

# Check container status
echo "📊 Container status:"
docker-compose -f docker-compose.micro.yml ps

# Monitor logs for a few seconds
echo "📋 Recent web container logs:"
docker-compose -f docker-compose.micro.yml logs --tail=20 web

# Test health endpoints
echo ""
echo "🏥 Testing health endpoints..."
sleep 5

if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✅ Health endpoint is working!"
    echo "🎉 Deployment fixed successfully!"
    echo ""
    echo "📱 Access your app at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'your-ec2-ip')"
else
    echo "⚠️  Health endpoint still not responding"
    echo "📋 Latest logs:"
    docker-compose -f docker-compose.micro.yml logs --tail=10 web
    echo ""
    echo "🔧 Troubleshoot with:"
    echo "  docker-compose -f docker-compose.micro.yml logs -f web"
fi

echo ""
echo "✅ Restart script completed!" 