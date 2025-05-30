#!/bin/bash

# FocusPad Local Development Start Script
# Start the FocusPad application for local development

set -e

echo "🚀 Starting FocusPad Local Development"
echo "===================================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Check if we're in the right directory
if [ ! -f "docker-compose.local.yml" ]; then
    echo "❌ Error: docker-compose.local.yml not found"
    echo "Please run this script from the FocusPad project directory"
    exit 1
fi

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "⚠️  .env.local not found. Creating from template..."
    if [ -f ".env.local.example" ]; then
        cp .env.local.example .env.local
        echo "📝 Please edit .env.local with your configuration:"
        echo "   - GOOGLE_CLIENT_ID (for localhost:5000)"
        echo "   - GOOGLE_CLIENT_SECRET"
        echo "   - OPENAI_API_KEY (optional)"
        echo ""
        read -p "Press Enter after updating .env.local..."
    else
        echo "❌ No environment template found"
        exit 1
    fi
fi

# Start all services
echo "🐳 Starting all services..."
docker-compose -f docker-compose.local.yml --env-file .env.local up -d

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
timeout=30
counter=0
while ! docker-compose -f docker-compose.local.yml --env-file .env.local exec db pg_isready -U focuspad_user &>/dev/null; do
    sleep 2
    counter=$((counter + 2))
    if [ $counter -ge $timeout ]; then
        echo "❌ Database failed to start within $timeout seconds"
        docker-compose -f docker-compose.local.yml --env-file .env.local logs db
        exit 1
    fi
    echo "Waiting for database... ($counter/$timeout seconds)"
done

echo "✅ Database is ready"

# Wait for web application
echo "⏳ Waiting for web application..."
sleep 10

# Health check
echo "🏥 Running health check..."
for i in {1..6}; do
    if curl -f -s http://localhost:5000/health > /dev/null; then
        echo "✅ Application is healthy!"
        break
    elif [ $i -eq 6 ]; then
        echo "❌ Health check failed"
        echo "📋 Check logs: docker-compose -f docker-compose.local.yml --env-file .env.local logs web"
        exit 1
    else
        echo "Waiting for health check... ($i/6)"
        sleep 5
    fi
done

# Show container status
echo ""
echo "📊 Container Status:"
docker-compose -f docker-compose.local.yml --env-file .env.local ps

echo ""
echo "✅ FocusPad local development environment started!"
echo ""
echo "🌐 Available Services:"
echo "   Application:  http://localhost:5000"
echo "   PgAdmin:      http://localhost:8080 (admin@focuspad.local / admin123)"
echo "   Redis:        localhost:6379"
echo "   PostgreSQL:   localhost:5432 (focuspad_user / focuspad_dev_password)"
echo ""
echo "📊 Useful Commands:"
echo "   View logs:    docker-compose -f docker-compose.local.yml --env-file .env.local logs -f"
echo "   Stop all:     docker-compose -f docker-compose.local.yml down"
echo "   Restart web:  docker-compose -f docker-compose.local.yml restart web"
echo "   Shell access: docker-compose -f docker-compose.local.yml exec web bash" 