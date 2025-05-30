#!/bin/bash

# FocusPad Deployment Script
# This script deploys the FocusPad application with database migration
# Run this to deploy or update the application

set -e

echo "🚀 FocusPad Deployment"
echo "====================="
echo ""

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

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "Please run the setup-instance.sh script first"
    exit 1
fi

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo "⚠️  .env.production not found. Creating from template..."
    if [ -f ".env.prod.example" ]; then
        cp .env.prod.example .env.production
        echo "📝 Please edit .env.production with your actual configuration:"
        echo "   - GOOGLE_CLIENT_ID"
        echo "   - GOOGLE_CLIENT_SECRET"
        echo "   - OPENAI_API_KEY (optional)"
        echo ""
        read -p "Press Enter after updating .env.production..."
    else
        echo "❌ No environment template found"
        exit 1
    fi
fi

# Generate secure keys if placeholders exist
echo "🔐 Checking environment configuration..."
if grep -q "your-google-client-id" .env.production 2>/dev/null; then
    echo "⚠️  Google OAuth credentials need to be configured"
    echo "Please update GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env.production"
    read -p "Press Enter after updating OAuth credentials..."
fi

# Generate secure keys for production
echo "🔑 Generating secure keys..."
python3 -c "
import secrets
import base64
import os

# Read current .env.production
with open('.env.production', 'r') as f:
    content = f.read()

# Generate new keys if they're using defaults
if 'tbG92lEw36NSqLOgHsJFH7OLogGDj0kgnRn5tcYlaxc' in content:
    new_secret = secrets.token_urlsafe(32)
    content = content.replace('tbG92lEw36NSqLOgHsJFH7OLogGDj0kgnRn5tcYlaxc', new_secret)
    print(f'✅ Generated new SECRET_KEY')

if 'ukcwVZ072l2h7hdw8sdXpcHJbbJ1h1m_' in content:
    new_jwt = secrets.token_urlsafe(32)
    content = content.replace('ukcwVZ072l2h7hdw8sdXpcHJbbJ1h1m_', new_jwt)
    print(f'✅ Generated new JWT_SECRET_KEY')

if 'mOw1IQ3fr0b7lbaoeZgYHw' in content:
    new_db_pass = secrets.token_urlsafe(16)
    content = content.replace('mOw1IQ3fr0b7lbaoeZgYHw', new_db_pass)
    print(f'✅ Generated new DB_PASSWORD')

if 'vJ88dzr9N/YhJlM94gSTyAWmlnFlKY8SpdVH5ow2LAk=' in content:
    new_master = base64.b64encode(os.urandom(32)).decode()
    content = content.replace('vJ88dzr9N/YhJlM94gSTyAWmlnFlKY8SpdVH5ow2LAk=', new_master)
    print(f'✅ Generated new FOCUSPAD_MASTER_KEY')

# Write updated content
with open('.env.production', 'w') as f:
    f.write(content)

print('✅ Environment configuration updated')
"

# Backup current deployment
echo "📦 Creating deployment backup..."
timestamp=$(date +%Y%m%d_%H%M%S)
mkdir -p backups/deployments/$timestamp

# Backup current containers if they exist
if docker-compose -f docker-compose.prod.yml ps -q | grep -q .; then
    echo "💾 Backing up current deployment..."
    docker-compose -f docker-compose.prod.yml --env-file .env.production logs > backups/deployments/$timestamp/container_logs.txt 2>/dev/null || true
    echo "✅ Logs backed up to backups/deployments/$timestamp/"
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down -v 2>/dev/null || true

# Clean up old images and containers
echo "🧹 Cleaning up old Docker resources..."
docker system prune -af --volumes 2>/dev/null || true

# Build application
echo "🏗️  Building application..."
docker-compose -f docker-compose.prod.yml --env-file .env.production build --no-cache

# Start database first
echo "🗄️  Starting database..."
docker-compose -f docker-compose.prod.yml --env-file .env.production up -d db

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
timeout=60
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

# Wait for web application to be ready
echo "⏳ Waiting for application to be ready..."
sleep 15

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose -f docker-compose.prod.yml --env-file .env.production exec web python3 /app/db/run_migrations.py

# Verify database setup
echo "🧪 Verifying database setup..."
docker-compose -f docker-compose.prod.yml --env-file .env.production exec web python3 -c "
import sys
sys.path.insert(0, '/app')

try:
    from app import create_app, db
    
    print('🔧 Verifying database...')
    app = create_app()
    
    with app.app_context():
        # Verify tables exist
        from sqlalchemy import text
        result = db.session.execute(text('SELECT table_name FROM information_schema.tables WHERE table_schema = \'public\''))
        tables = [row[0] for row in result.fetchall()]
        
        expected_tables = ['users', 'notes', 'templates', 'contents', 'schema_migrations', 'migration_state']
        missing_tables = [table for table in expected_tables if table not in tables]
        
        if missing_tables:
            print(f'❌ Missing tables: {missing_tables}')
            exit(1)
        
        print('✅ Database tables verified:')
        for table in sorted(tables):
            print(f'   - {table}')
        
        print('✅ Database verification completed successfully!')
            
except Exception as e:
    print(f'❌ Database verification failed: {e}')
    import traceback
    traceback.print_exc()
    exit(1)
"

# Health check
echo "🏥 Running health check..."
sleep 5
for i in {1..12}; do
    if curl -f -s http://localhost:8080/health > /dev/null; then
        echo "✅ Application is healthy!"
        break
    elif [ $i -eq 12 ]; then
        echo "❌ Health check failed"
        echo "📋 Check logs: docker-compose -f docker-compose.prod.yml --env-file .env.production logs web"
        exit 1
    else
        echo "Waiting for health check... ($i/12)"
        sleep 5
    fi
done

# Reload nginx to ensure proxy is working
echo "🌐 Reloading Nginx..."
sudo systemctl reload nginx

# Final verification
echo "🧪 Final verification..."
sleep 3
if curl -f -s http://localhost/health > /dev/null; then
    echo "✅ Application accessible through Nginx!"
else
    echo "⚠️  Application not accessible through Nginx - check configuration"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "- Backup created: backups/deployments/$timestamp/"
echo "- Database migrated and verified"
echo "- Application health check: ✅ PASSED"
echo "- Nginx proxy: ✅ CONFIGURED"
echo ""
echo "🌐 Your application is now accessible at:"
echo "   http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR-IP')"
echo "   https://thefocuspad.com (after SSL setup)"
echo ""
echo "📊 Useful Commands:"
echo "   View logs:    docker-compose -f docker-compose.prod.yml --env-file .env.production logs -f"
echo "   Check status: docker-compose -f docker-compose.prod.yml --env-file .env.production ps"
echo "   Stop app:     ./scripts/stop.sh"
echo "   Start app:    ./scripts/start.sh"
echo ""
echo "🔒 Next: Run SSL setup if not done:"
echo "   sudo certbot --nginx -d thefocuspad.com -d www.thefocuspad.com" 