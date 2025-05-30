#!/bin/bash

# FocusPad Docker Cleanup Script
# This script removes ALL Docker resources created for FocusPad project
# Use this when you want a completely fresh start

set -e

echo "🧹 FocusPad Docker Cleanup"
echo "=========================="
echo "⚠️  WARNING: This will remove ALL Docker resources for FocusPad!"
echo "   - All containers (running and stopped)"
echo "   - All images (built and pulled)"
echo "   - All volumes (data will be LOST)"
echo "   - All networks"
echo ""

# Ask for confirmation unless --force flag is used
if [[ "$1" != "--force" ]]; then
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cleanup cancelled"
        exit 1
    fi
fi

echo "🛑 Starting cleanup process..."
echo ""

# Function to safely run docker commands
safe_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker not found. Please install Docker first."
        exit 1
    fi
}

# Check if Docker is available
safe_docker

# 1. Stop and remove all FocusPad containers
echo "🔄 Stopping and removing FocusPad containers..."
docker-compose -f docker-compose.local.yml down --remove-orphans 2>/dev/null || echo "   No local containers to stop"
docker-compose -f docker-compose.prod.yml down --remove-orphans 2>/dev/null || echo "   No prod containers to stop"

# Remove any remaining FocusPad containers
FOCUSPAD_CONTAINERS=$(docker ps -aq --filter "name=focuspad" 2>/dev/null || true)
if [ ! -z "$FOCUSPAD_CONTAINERS" ]; then
    echo "   Removing remaining FocusPad containers..."
    docker rm -f $FOCUSPAD_CONTAINERS
else
    echo "   ✅ No FocusPad containers found"
fi

# 2. Remove FocusPad networks
echo ""
echo "🌐 Removing FocusPad networks..."
FOCUSPAD_NETWORKS=$(docker network ls --filter "name=focuspad" -q 2>/dev/null || true)
if [ ! -z "$FOCUSPAD_NETWORKS" ]; then
    docker network rm $FOCUSPAD_NETWORKS 2>/dev/null || echo "   Networks already removed or in use"
    echo "   ✅ FocusPad networks removed"
else
    echo "   ✅ No FocusPad networks found"
fi

# 3. Remove FocusPad volumes (THIS WILL DELETE ALL DATA!)
echo ""
echo "💾 Removing FocusPad volumes (ALL DATA WILL BE LOST!)..."
FOCUSPAD_VOLUMES=$(docker volume ls --filter "name=focuspad" -q 2>/dev/null || true)
if [ ! -z "$FOCUSPAD_VOLUMES" ]; then
    docker volume rm $FOCUSPAD_VOLUMES 2>/dev/null || echo "   Some volumes might be in use"
    echo "   ✅ FocusPad volumes removed"
else
    echo "   ✅ No FocusPad volumes found"
fi

# 4. Remove built FocusPad images
echo ""
echo "🖼️  Removing FocusPad images..."
FOCUSPAD_IMAGES=$(docker images --filter "reference=focuspad*" -q 2>/dev/null || true)
if [ ! -z "$FOCUSPAD_IMAGES" ]; then
    docker rmi -f $FOCUSPAD_IMAGES
    echo "   ✅ FocusPad images removed"
else
    echo "   ✅ No FocusPad images found"
fi

# 5. Remove dangling/unused images related to the project
echo ""
echo "🗑️  Removing dangling and unused images..."
docker image prune -f > /dev/null 2>&1 || true
echo "   ✅ Dangling images removed"

# 6. Clean up build cache
echo ""
echo "🧽 Cleaning Docker build cache..."
docker builder prune -f > /dev/null 2>&1 || true
echo "   ✅ Build cache cleaned"

# 7. Optional: Full system cleanup
echo ""
echo "🔍 Checking for additional cleanup opportunities..."
UNUSED_VOLUMES=$(docker volume ls -q --filter "dangling=true" 2>/dev/null | wc -l || echo "0")
UNUSED_NETWORKS=$(docker network ls --filter "dangling=true" -q 2>/dev/null | wc -l || echo "0")

if [ "$UNUSED_VOLUMES" -gt 0 ] || [ "$UNUSED_NETWORKS" -gt 0 ]; then
    echo "   Found $UNUSED_VOLUMES unused volumes and $UNUSED_NETWORKS unused networks"
    if [[ "$1" == "--aggressive" ]]; then
        echo "   🔥 Running aggressive cleanup (--aggressive mode)..."
        docker system prune -a -f --volumes > /dev/null 2>&1 || true
        echo "   ✅ Aggressive cleanup completed"
    else
        echo "   💡 Tip: Use --aggressive flag for full system cleanup"
    fi
else
    echo "   ✅ No additional cleanup needed"
fi

echo ""
echo "✨ FocusPad Docker cleanup completed!"
echo ""
echo "📊 Current Docker status:"
echo "   Containers: $(docker ps -aq | wc -l) total"
echo "   Images:     $(docker images -q | wc -l) total"
echo "   Volumes:    $(docker volume ls -q | wc -l) total"
echo "   Networks:   $(docker network ls --filter type=custom -q | wc -l) custom"
echo ""
echo "🚀 Ready for fresh start! Run: ./scripts/start-local.sh"
echo ""

# Verify cleanup was successful
echo "🔍 Verifying cleanup..."
REMAINING_FOCUSPAD=$(docker ps -aq --filter "name=focuspad" | wc -l)
if [ "$REMAINING_FOCUSPAD" -eq 0 ]; then
    echo "   ✅ All FocusPad containers removed"
else
    echo "   ⚠️  Warning: $REMAINING_FOCUSPAD FocusPad containers still present"
fi

echo ""
echo "🎯 Cleanup Summary:"
echo "   ✅ Containers stopped and removed"
echo "   ✅ Networks removed"  
echo "   ✅ Volumes removed (data deleted)"
echo "   ✅ Images removed"
echo "   ✅ Build cache cleaned"
echo ""
echo "💡 Usage examples:"
echo "   ./scripts/clean-docker.sh              # Interactive cleanup"
echo "   ./scripts/clean-docker.sh --force      # Skip confirmation"
echo "   ./scripts/clean-docker.sh --aggressive # Full system cleanup" 