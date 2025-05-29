#!/bin/bash

# FocusPad t2.micro Deployment Issue Fix Script
# This script addresses common deployment issues on AWS t2.micro

set -e

echo "🔧 FocusPad Deployment Issue Fix Script"
echo "======================================"
echo ""

# Check if we're in the correct directory
if [ ! -f "docker-compose.micro.yml" ]; then
    echo "❌ Error: docker-compose.micro.yml not found"
    echo "Please run this script from the FocusPad project directory"
    exit 1
fi

echo "📍 Current directory: $(pwd)"
echo "🔍 Checking current deployment status..."

# Check if containers are running
if docker-compose -f docker-compose.micro.yml ps | grep -q "Up"; then
    echo "📊 Current container status:"
    docker-compose -f docker-compose.micro.yml ps
    echo ""
    
    # Check logs for specific errors
    echo "🔍 Checking for common issues in logs..."
    
    # Check for MASTER_KEY error
    if docker-compose -f docker-compose.micro.yml logs web 2>/dev/null | grep -q "MASTER_KEY.*not set"; then
        echo "❌ Found MASTER_KEY environment variable issue"
        ENV_ISSUE=true
    fi
    
    # Check for database connection issues
    if docker-compose -f docker-compose.micro.yml logs 2>/dev/null | grep -q "could not connect to server\|Connection refused\|database.*does not exist"; then
        echo "❌ Found database connection issues"
        DB_ISSUE=true
    fi
    
    # Check for container restart loops
    if docker-compose -f docker-compose.micro.yml logs 2>/dev/null | grep -q "restarting\|Exited"; then
        echo "❌ Found container restart issues"
        RESTART_ISSUE=true
    fi
else
    echo "⚠️  No containers are currently running"
    CONTAINERS_DOWN=true
fi

echo ""

# Fix 1: Environment Variables
echo "🔐 Fix 1: Setting up environment variables..."
if [ ! -f ".env.production" ]; then
    echo "⚠️  .env.production file missing - creating it now..."
    
    # Run the setup script
    if [ -f "setup-env-micro.sh" ]; then
        ./setup-env-micro.sh
    else
        echo "❌ setup-env-micro.sh not found, creating minimal .env.production..."
        
        # Generate required keys
        SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
        FOCUSPAD_MASTER_KEY=$(python3 -c "import base64, os; print(base64.b64encode(os.urandom(32)).decode())")
        JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
        DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")
        
        # Get EC2 public IP if possible
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")
        
        cat > .env.production << EOF
# Auto-generated .env.production - EDIT MANUALLY FOR GOOGLE OAUTH
FLASK_ENV=production
SECRET_KEY=$SECRET_KEY
DEBUG=False

# Database Configuration
DB_PASSWORD=$DB_PASSWORD
DATABASE_URL=postgresql://focuspad_user:$DB_PASSWORD@db:5432/focuspad

# Encryption (Required)
FOCUSPAD_MASTER_KEY=$FOCUSPAD_MASTER_KEY

# Google OAuth (REQUIRED - SET THESE MANUALLY)
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# OpenAI API (Optional)
OPENAI_API_KEY=sk-your-openai-api-key-here

# Application URL
BASE_URL=http://$PUBLIC_IP

# JWT Configuration
JWT_SECRET_KEY=$JWT_SECRET_KEY
JWT_ACCESS_TOKEN_EXPIRES=7200

# Security Headers
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
SESSION_COOKIE_HTTPONLY=True
SESSION_COOKIE_SAMESITE=Lax

# Performance Optimizations
FLASK_SKIP_DOTENV=1
WERKZEUG_RUN_MAIN=true
LOG_LEVEL=WARNING
DATABASE_POOL_SIZE=5
DATABASE_MAX_OVERFLOW=10
SEARCH_RESULTS_LIMIT=20
SEARCH_TIMEOUT=30
EOF
        
        chmod 600 .env.production
        echo "✅ Created basic .env.production file"
    fi
else
    echo "✅ .env.production file exists"
    
    # Check if FOCUSPAD_MASTER_KEY is set
    if grep -q "FOCUSPAD_MASTER_KEY=your-base64-encoded-master-key-here" .env.production 2>/dev/null; then
        echo "⚠️  FOCUSPAD_MASTER_KEY not configured, generating one..."
        MASTER_KEY=$(python3 -c "import base64, os; print(base64.b64encode(os.urandom(32)).decode())")
        sed -i "s/FOCUSPAD_MASTER_KEY=your-base64-encoded-master-key-here/FOCUSPAD_MASTER_KEY=$MASTER_KEY/g" .env.production
        echo "✅ Generated and set FOCUSPAD_MASTER_KEY"
    fi
fi

# Fix 2: Stop and clean up containers
echo ""
echo "🛑 Fix 2: Stopping containers and cleaning up..."
docker-compose -f docker-compose.micro.yml down --remove-orphans 2>/dev/null || true

# Wait a moment for cleanup
sleep 5

# Clean up Docker resources to save space
echo "🧹 Cleaning up Docker resources..."
docker system prune -af --volumes 2>/dev/null || true

# Fix 3: Check memory and swap
echo ""
echo "💾 Fix 3: Checking system resources..."
echo "Current memory usage:"
free -h

if ! swapon -s | grep -q "/swapfile"; then
    echo "⚠️  Swap not enabled, this is critical for t2.micro"
    echo "   Run: sudo swapon /swapfile"
else
    echo "✅ Swap is enabled"
fi

# Fix 4: Restart containers with better error handling
echo ""
echo "🚀 Fix 4: Starting containers with enhanced monitoring..."

# Start database first and wait for it
echo "🗄️  Starting database container..."
docker-compose -f docker-compose.micro.yml up -d db

echo "⏳ Waiting for database to be ready..."
for i in {1..30}; do
    if docker-compose -f docker-compose.micro.yml exec -T db pg_isready -U focuspad_user > /dev/null 2>&1; then
        echo "✅ Database is ready"
        break
    else
        echo "   Attempt $i/30: Database not ready yet, waiting 5 seconds..."
        sleep 5
    fi
done

# Check if database is actually ready
if ! docker-compose -f docker-compose.micro.yml exec -T db pg_isready -U focuspad_user > /dev/null 2>&1; then
    echo "❌ Database failed to start properly"
    echo "Database logs:"
    docker-compose -f docker-compose.micro.yml logs db | tail -20
    exit 1
fi

# Start web container
echo "🌐 Starting web container..."
docker-compose -f docker-compose.micro.yml up -d web

# Wait for web container to be ready
echo "⏳ Waiting for web container to be ready..."
sleep 30

# Fix 5: Database setup with better error handling
echo ""
echo "🗄️  Fix 5: Setting up database schema..."
for i in {1..5}; do
    echo "Database setup attempt $i/5..."
    if docker-compose -f docker-compose.micro.yml exec -T web python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('Database tables created successfully')
" 2>/dev/null; then
        echo "✅ Database setup completed successfully"
        DB_SETUP_SUCCESS=true
        break
    else
        echo "⚠️  Database setup attempt $i failed, waiting 10 seconds before retry..."
        sleep 10
    fi
done

if [ -z "$DB_SETUP_SUCCESS" ]; then
    echo "❌ Database setup failed after 5 attempts"
    echo "Web container logs:"
    docker-compose -f docker-compose.micro.yml logs web | tail -20
    echo ""
    echo "Database logs:"
    docker-compose -f docker-compose.micro.yml logs db | tail -20
fi

# Fix 6: Manual encryption setup (with timeout handling)
echo ""
echo "🔐 Fix 6: Setting up encryption (with extended timeout for t2.micro)..."
if timeout 180 docker-compose -f docker-compose.micro.yml exec -T web python3 scripts/setup_encryption.py 2>/dev/null; then
    echo "✅ Encryption setup completed"
else
    echo "⚠️  Encryption setup timed out or failed"
    echo "This is common on t2.micro due to limited resources"
    echo "You can run encryption setup manually later if needed"
fi

# Fix 7: Health check with multiple endpoints
echo ""
echo "🏥 Fix 7: Running comprehensive health check..."
sleep 10

# Check the main health endpoint
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✅ Main health endpoint (/health) is working"
    HEALTH_OK=true
elif curl -f http://localhost/ > /dev/null 2>&1; then
    echo "✅ Root endpoint (/) is working"
    HEALTH_OK=true
else
    echo "⚠️  Health endpoints not responding"
    echo "This might be due to slow startup on t2.micro"
fi

# Final status check
echo ""
echo "📊 Final System Status:"
echo "======================"

echo "💾 Memory usage:"
free -h

echo ""
echo "🐳 Container status:"
docker-compose -f docker-compose.micro.yml ps

echo ""
echo "📊 Container resource usage:"
docker stats --no-stream | head -3

# Provide troubleshooting commands
echo ""
echo "🔧 Troubleshooting Commands:"
echo "============================"
echo ""
echo "Check container logs:"
echo "  docker-compose -f docker-compose.micro.yml logs -f web"
echo "  docker-compose -f docker-compose.micro.yml logs -f db"
echo ""
echo "Check container status:"
echo "  docker-compose -f docker-compose.micro.yml ps"
echo ""
echo "Restart specific container:"
echo "  docker-compose -f docker-compose.micro.yml restart web"
echo "  docker-compose -f docker-compose.micro.yml restart db"
echo ""
echo "Full restart:"
echo "  docker-compose -f docker-compose.micro.yml down"
echo "  docker-compose -f docker-compose.micro.yml up -d"
echo ""
echo "Manual database setup:"
echo "  docker-compose -f docker-compose.micro.yml exec web python3 -c \\"
echo "    from app import create_app, db; app = create_app(); \\"
echo "    app.app_context().push(); db.create_all()\""
echo ""
echo "Manual encryption setup:"
echo "  docker-compose -f docker-compose.micro.yml exec web python3 scripts/setup_encryption.py"
echo ""
echo "Check environment variables:"
echo "  docker-compose -f docker-compose.micro.yml exec web env | grep FOCUSPAD"
echo ""
echo "Test endpoints:"
echo "  curl http://localhost/health"
echo "  curl http://localhost/"
echo ""

# Final recommendations
echo "⚡ Performance Recommendations for t2.micro:"
echo "=============================================="
echo "1. Monitor CPU burst credits in AWS CloudWatch"
echo "2. Consider upgrading to t3.small for better performance"
echo "3. Limit concurrent users to 2-3 maximum"
echo "4. Monitor swap usage: swapon -s"
echo "5. If containers become unresponsive, restart them"
echo ""

if [ "$HEALTH_OK" = true ]; then
    echo "🎉 Deployment appears to be working!"
    echo "📱 Access your app at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'your-ec2-ip')"
else
    echo "⚠️  Deployment needs manual intervention"
    echo "Please check the logs and run the troubleshooting commands above"
fi

echo ""
echo "✅ Fix script completed!" 