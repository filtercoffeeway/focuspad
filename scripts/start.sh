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

# Check if .env.prod exists
if [ ! -f ".env.prod" ]; then
    echo "❌ Error: .env.prod not found"
    echo "Please run ./scripts/deploy.sh first"
    exit 1
fi

# Check if containers are already running
if docker-compose -f docker-compose.prod.yml --env-file .env.prod ps -q | grep -q .; then
    echo "⚠️  Some containers are already running:"
    docker-compose -f docker-compose.prod.yml --env-file .env.prod ps
    echo ""
    read -p "Do you want to restart them? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔄 Restarting containers..."
        docker-compose -f docker-compose.prod.yml --env-file .env.prod restart
    else
        echo "✅ Using existing containers"
    fi
else
    # Start containers
    echo "🗄️  Starting database..."
    docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d db

    # Wait for database
    echo "⏳ Waiting for database to be ready..."
    timeout=30
    counter=0
    while ! docker-compose -f docker-compose.prod.yml --env-file .env.prod exec db pg_isready -U focuspad_user &>/dev/null; do
        sleep 2
        counter=$((counter + 2))
        if [ $counter -ge $timeout ]; then
            echo "❌ Database failed to start within $timeout seconds"
            exit 1
        fi
        echo "Waiting for database... ($counter/$timeout seconds)"
    done

    echo "✅ Database is ready"

    # Start all services
    echo "🚀 Starting all services..."
    docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d

    # Wait for application
    echo "⏳ Waiting for application to be ready..."
    sleep 15
fi

# Health check
echo "🏥 Running health check..."
for i in {1..10}; do
    if curl -f -s http://localhost:8080/health > /dev/null; then
        echo "✅ Application is healthy!"
        break
    elif [ $i -eq 10 ]; then
        echo "❌ Health check failed"
        echo "📋 Check logs: docker-compose -f docker-compose.prod.yml --env-file .env.prod logs web"
        exit 1
    else
        echo "Waiting for health check... ($i/10)"
        sleep 3
    fi
done

# Check containers status
echo ""
echo "📊 Container Status:"
docker-compose -f docker-compose.prod.yml --env-file .env.prod ps

# Check service health
echo ""
echo "🏥 Service Health Checks:"

# Check database
if docker-compose -f docker-compose.prod.yml --env-file .env.prod exec db pg_isready -U focuspad_user &>/dev/null; then
    echo "   Database: ✅ HEALTHY"
else
    echo "   Database: ❌ UNHEALTHY"
fi

# Check web application
if curl -f -s http://localhost:8080/health > /dev/null; then
    echo "   Web App:  ✅ HEALTHY"
else
    echo "   Web App:  ❌ UNHEALTHY"
fi

# Check Redis (if running)
if docker-compose -f docker-compose.prod.yml --env-file .env.prod ps redis | grep -q "Up"; then
    if docker-compose -f docker-compose.prod.yml --env-file .env.prod exec redis redis-cli ping | grep -q "PONG"; then
        echo "   Redis:    ✅ HEALTHY"
    else
        echo "   Redis:    ❌ UNHEALTHY"
    fi
fi

# Check Nginx (if running)
if docker-compose -f docker-compose.prod.yml --env-file .env.prod ps nginx | grep -q "Up"; then
    if docker-compose -f docker-compose.prod.yml --env-file .env.prod exec nginx nginx -t &>/dev/null; then
        echo "   Nginx:    ✅ HEALTHY"
    else
        echo "   Nginx:    ❌ CONFIGURATION ERROR"
    fi
fi

echo ""
echo "✅ FocusPad application started successfully!"
echo ""
echo "🌐 Application is accessible at:"
echo "   Direct: http://localhost:8080"
echo "   Proxy:  http://localhost"
echo "   Domain: https://thefocuspad.com (if configured)"
echo ""
echo "📊 Useful Commands:"
echo "   View logs:    docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f"
echo "   Check status: docker-compose -f docker-compose.prod.yml --env-file .env.prod ps"
echo "   Stop app:     ./scripts/stop.sh"
echo "   Deploy:       ./scripts/deploy.sh"
echo "   Clean start:  ./scripts/clean-docker-ec2.sh && ./scripts/deploy.sh" 