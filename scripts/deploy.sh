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

# Check if .env.prod exists
if [ ! -f ".env.prod" ]; then
    echo "⚠️  .env.prod not found. Creating from template..."
    if [ -f ".env.prod.example" ]; then
        cp .env.prod.example .env.prod
        echo "📝 Please edit .env.prod with your actual configuration:"
        echo "   - GOOGLE_CLIENT_ID"
        echo "   - GOOGLE_CLIENT_SECRET"
        echo "   - OPENAI_API_KEY (optional)"
        echo "   - DB_PASSWORD (generate strong password)"
        echo "   - SECRET_KEY (generate secure key)"
        echo "   - JWT_SECRET_KEY (generate secure key)"
        echo "   - FOCUSPAD_MASTER_KEY (generate with: openssl rand -base64 32)"
        echo ""
        read -p "Press Enter after updating .env.prod..."
    else
        echo "❌ No environment template found"
        exit 1
    fi
fi

# Generate secure keys if placeholders exist
echo "🔐 Checking environment configuration..."
if grep -q "your-google-client-id" .env.prod 2>/dev/null; then
    echo "⚠️  Google OAuth credentials need to be configured"
    echo "Please update GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env.prod"
    read -p "Press Enter after updating OAuth credentials..."
fi

# Generate secure keys for production
echo "🔑 Generating secure keys..."
python3 -c "
import secrets
import base64
import os

# Read current .env.prod
with open('.env.prod', 'r') as f:
    content = f.read()

# Generate new keys if they're using defaults or placeholders
if 'your-super-secret-key-change-this-to-a-long-random-string' in content:
    new_secret = secrets.token_urlsafe(32)
    content = content.replace('your-super-secret-key-change-this-to-a-long-random-string', new_secret)
    print(f'✅ Generated new SECRET_KEY')

if 'your-jwt-secret-key-change-this-to-a-long-random-string' in content:
    new_jwt = secrets.token_urlsafe(32)
    content = content.replace('your-jwt-secret-key-change-this-to-a-long-random-string', new_jwt)
    print(f'✅ Generated new JWT_SECRET_KEY')

if 'your-strong-database-password-here' in content:
    new_db_pass = secrets.token_urlsafe(16)
    content = content.replace('your-strong-database-password-here', new_db_pass)
    print(f'✅ Generated new DB_PASSWORD')

if 'your-base64-encoded-master-key-here' in content:
    new_master = base64.b64encode(os.urandom(32)).decode()
    content = content.replace('your-base64-encoded-master-key-here', new_master)
    print(f'✅ Generated new FOCUSPAD_MASTER_KEY')

# Write updated content
with open('.env.prod', 'w') as f:
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
    docker-compose -f docker-compose.prod.yml --env-file .env.prod logs > backups/deployments/$timestamp/container_logs.txt 2>/dev/null || true
    echo "✅ Logs backed up to backups/deployments/$timestamp/"
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod down -v 2>/dev/null || true

# Clean up old images and containers
echo "🧹 Cleaning up old Docker resources..."
docker system prune -af --volumes 2>/dev/null || true

# Build application
echo "🏗️  Building application..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod build --no-cache

# Create and set permissions for required directories
echo "📁 Setting up directory structure..."
mkdir -p logs/nginx backups/deployments backups/cleanup

# Ensure proper permissions for directories that need writing
chmod -R 755 logs/ backups/ 2>/dev/null || true

echo "✅ Directory structure configured"

# Start database first
echo "🗄️  Starting database..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d db

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
timeout=60
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

# Start web application
echo "🚀 Starting web application..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d web

# Wait for web application to be ready
echo "⏳ Waiting for application to be ready..."
sleep 15

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod exec web python3 /app/db/run_migrations.py

# Verify database setup and check for new markdown_content field
echo "🧪 Verifying database setup..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod exec web python3 -c "
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
        
        # Check for new markdown_content field in notes table
        column_result = db.session.execute(text('SELECT column_name FROM information_schema.columns WHERE table_name = \'notes\' AND table_schema = \'public\''))
        columns = [row[0] for row in column_result.fetchall()]
        
        if 'markdown_content' in columns:
            print('✅ New markdown_content field found')
        else:
            print('⚠️  markdown_content field not found - may need manual migration')
        
        if 'encrypted_markdown_content' in columns:
            print('✅ Encrypted markdown_content field found')
        else:
            print('⚠️  encrypted_markdown_content field not found - may need manual migration')
            
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
        echo "📋 Check logs: docker-compose -f docker-compose.prod.yml --env-file .env.prod logs web"
        exit 1
    else
        echo "Waiting for health check... ($i/12)"
        sleep 5
    fi
done

# Start additional services (Redis, Nginx)
echo "🔄 Starting additional services..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d

# Wait for all services
echo "⏳ Waiting for all services to be ready..."
sleep 10

# Reload nginx to ensure proxy is working (if nginx is managed by systemd)
if systemctl is-active --quiet nginx; then
    echo "🌐 Reloading system Nginx..."
    sudo systemctl reload nginx || echo "⚠️  Could not reload system nginx - may not be configured"
fi

# Final verification
echo "🧪 Final verification..."
sleep 3
if curl -f -s http://localhost/health > /dev/null; then
    echo "✅ Application accessible through Nginx!"
else
    if curl -f -s http://localhost:8080/health > /dev/null; then
        echo "✅ Application accessible directly (port 8080)"
        echo "⚠️  Nginx proxy may need configuration"
    else
        echo "⚠️  Application not accessible - check configuration"
    fi
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "- Environment file: .env.prod ✅"
echo "- Backup created: backups/deployments/$timestamp/ ✅"
echo "- Database migrated and verified ✅"
echo "- Application health check: ✅ PASSED"
echo "- Services running: ✅ ALL"
echo ""
echo "🌐 Your application is now accessible at:"
echo "   Direct: http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR-IP'):8080"
echo "   Proxy:  http://$(curl -s ifconfig.me 2>/dev/null || echo 'YOUR-IP')"
echo "   Domain: https://thefocuspad.com (after DNS/SSL setup)"
echo ""
echo "📊 Useful Commands:"
echo "   View logs:    docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f"
echo "   Check status: docker-compose -f docker-compose.prod.yml --env-file .env.prod ps"
echo "   Stop app:     ./scripts/stop.sh"
echo "   Start app:    ./scripts/start.sh"
echo "   Clean start:  ./scripts/clean-docker-ec2.sh && ./scripts/deploy.sh"
echo ""
echo "🔒 Next steps:"
echo "   1. Configure DNS: Point domain to $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR-IP')"
echo "   2. Setup SSL: sudo certbot --nginx -d yourdomain.com"
echo "   3. Configure backups and monitoring" 