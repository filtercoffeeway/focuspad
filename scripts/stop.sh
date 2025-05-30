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

# Check if .env.prod exists
if [ ! -f ".env.prod" ]; then
    echo "⚠️  .env.prod not found - using docker-compose without env file"
    ENV_FILE_FLAG=""
else
    ENV_FILE_FLAG="--env-file .env.prod"
fi

# Check current status
echo "📊 Current container status:"
if docker-compose -f docker-compose.prod.yml ps -q | grep -q .; then
    docker-compose -f docker-compose.prod.yml $ENV_FILE_FLAG ps
    echo ""
else
    echo "No containers are currently running"
    exit 0
fi

# Ask for confirmation unless --force flag is used
if [[ "$1" != "--force" ]]; then
    echo "This will stop all FocusPad services:"
    echo "  - Web application"
    echo "  - Database"
    echo "  - Redis cache"
    echo "  - Nginx proxy"
    echo ""
    read -p "Are you sure you want to stop all services? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Stop cancelled"
        exit 1
    fi
fi

# Stop containers gracefully
echo "🛑 Stopping containers gracefully..."
docker-compose -f docker-compose.prod.yml $ENV_FILE_FLAG stop

# Wait a moment for graceful shutdown
sleep 3

# Remove containers if --remove flag is used
if [[ "$1" == "--remove" ]] || [[ "$2" == "--remove" ]]; then
    echo "🗑️  Removing containers..."
    docker-compose -f docker-compose.prod.yml $ENV_FILE_FLAG down
else
    echo "💡 Containers stopped but not removed (use --remove to remove)"
fi

# Check if containers are stopped
echo ""
echo "📊 Final status:"
if docker-compose -f docker-compose.prod.yml ps -q | grep -q .; then
    echo "⚠️  Some containers are still running:"
    docker-compose -f docker-compose.prod.yml $ENV_FILE_FLAG ps
    echo ""
    echo "💡 If you want to force stop everything:"
    echo "   docker-compose -f docker-compose.prod.yml down --remove-orphans -v"
    echo "   or use: ./scripts/clean-docker-ec2.sh"
else
    echo "✅ All containers stopped successfully"
fi

echo ""
echo "✅ FocusPad application stopped"
echo ""
echo "📊 System Status:"
echo "   Active containers: $(docker ps --format 'table {{.Names}}' | tail -n +2 | wc -l)"
echo "   Total containers:  $(docker ps -a --format 'table {{.Names}}' | tail -n +2 | wc -l)"
echo "   Docker images:     $(docker images -q | wc -l)"
echo "   Docker volumes:    $(docker volume ls -q | wc -l)"
echo ""
echo "📊 Useful Commands:"
echo "   Start app:    ./scripts/start.sh"
echo "   Deploy:       ./scripts/deploy.sh"
echo "   Clean all:    ./scripts/clean-docker-ec2.sh"
echo "   View logs:    docker-compose -f docker-compose.prod.yml $ENV_FILE_FLAG logs"
echo ""
echo "💡 Usage examples:"
echo "   ./scripts/stop.sh              # Stop containers (keep for restart)"
echo "   ./scripts/stop.sh --remove     # Stop and remove containers"
echo "   ./scripts/stop.sh --force      # Skip confirmation prompt" 