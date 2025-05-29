#!/bin/bash

# FocusPad Database Connection Script
# Run from project root: ./scripts/db_connect.sh

echo "🎯 FocusPad Database Connection"
echo "=============================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if focuspad_db container is running
if ! docker ps | grep -q focuspad_db; then
    echo "❌ PostgreSQL container is not running."
    echo "💡 Start with: docker-compose up -d db"
    exit 1
fi

echo "✅ Connecting to PostgreSQL database..."
echo ""
echo "Available commands once connected:"
echo "  \\dt          - List all tables"
echo "  \\d users     - Describe users table"
echo "  \\q           - Quit"
echo ""
echo "📝 Sample queries available in: scripts/sql_scripts/common_queries.sql"
echo "🔄 Run migrations with: flask db upgrade"
echo ""

# Connect to PostgreSQL
docker exec -it focuspad_db psql -U focuspad_user -d focuspad 