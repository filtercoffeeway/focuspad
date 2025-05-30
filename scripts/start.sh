#!/bin/bash

# FocusPad Start Script
# Start the FocusPad application containers

set -e

echo "🚀 Starting FocusPad Application"
echo "==============================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Check if we're in the right directory
if [ ! -f "docker-compose.prod.yml" ]; then
    echo "❌ Error: docker-compose.prod.yml not found"
    echo "Please run this script from the FocusPad project directory"
    exit 1
fi

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo "❌ Error: .env.production not found"
    echo "Please run ./scripts/deploy.sh first"
    exit 1
fi

# Start containers
echo "🗄️  Starting database..."
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d db

# Wait for database
echo "⏳ Waiting for database to be ready..."
timeout=30
counter=0
while ! docker-compose -f docker-compose.prod.yml --env-file .env.production exec db pg_isready -U focuspad_user &>/dev/null; do
    sleep 2
    counter=$((counter + 2))
    if [ $counter -ge $timeout ]; then
        echo "❌ Database failed to start within $timeout seconds"
        exit 1
    fi
    echo "Waiting for database... ($counter/$timeout seconds)"
done

echo "✅ Database is ready"

# Start web application
echo "🚀 Starting web application..."
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d web

# Wait for application
echo "⏳ Waiting for application to be ready..."
sleep 10

# Health check
echo "🏥 Running health check..."
for i in {1..6}; do
    if curl -f -s http://localhost:8080/health > /dev/null; then
        echo "✅ Application is healthy!"
        break
    elif [ $i -eq 6 ]; then
        echo "❌ Health check failed"
        echo "📋 Check logs: docker-compose -f docker-compose.prod.yml --env-file .env.production logs web"
        exit 1
    else
        echo "Waiting for health check... ($i/6)"
        sleep 5
    fi
done

# Check containers status
echo ""
echo "📊 Container Status:"
docker-compose -f docker-compose.prod.yml --env-file .env.production ps

echo ""
echo "✅ FocusPad application started successfully!"
echo ""
echo "🌐 Application is accessible at:"
echo "   Local: http://localhost:8080"
echo "   Nginx: http://localhost"
echo "   Domain: https://thefocuspad.com"
echo ""
echo "📊 Useful Commands:"
echo "   View logs:    docker-compose -f docker-compose.prod.yml --env-file .env.production logs -f"
echo "   Stop app:     ./scripts/stop.sh"
echo "   Deploy:       ./scripts/deploy.sh" 