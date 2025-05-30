#!/bin/bash

# FocusPad Stop Script
# Stop the FocusPad application containers

set -e

echo "🛑 Stopping FocusPad Application"
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

# Check current status
echo "📊 Current container status:"
if docker-compose -f docker-compose.prod.yml ps -q | grep -q .; then
    docker-compose -f docker-compose.prod.yml --env-file .env.production ps
    echo ""
else
    echo "No containers are currently running"
    exit 0
fi

# Stop containers gracefully
echo "🛑 Stopping containers gracefully..."
docker-compose -f docker-compose.prod.yml --env-file .env.production stop

# Wait a moment
sleep 3

# Remove containers
echo "🗑️  Removing containers..."
docker-compose -f docker-compose.prod.yml --env-file .env.production down

# Check if containers are stopped
echo ""
echo "📊 Final status:"
if docker-compose -f docker-compose.prod.yml ps -q | grep -q .; then
    echo "⚠️  Some containers are still running:"
    docker-compose -f docker-compose.prod.yml --env-file .env.production ps
    echo ""
    echo "💡 If you want to force stop everything:"
    echo "   docker-compose -f docker-compose.prod.yml down --remove-orphans"
else
    echo "✅ All containers stopped successfully"
fi

echo ""
echo "✅ FocusPad application stopped"
echo ""
echo "📊 Useful Commands:"
echo "   Start app:    ./scripts/start.sh"
echo "   Deploy:       ./scripts/deploy.sh"
echo "   View logs:    docker-compose -f docker-compose.prod.yml --env-file .env.production logs" 