#!/bin/bash

# Quick OAuth Fix Test Script
# Run this script to verify OAuth and database fixes are working

set -e

echo "🧪 Testing OAuth & Database Fixes"
echo "=================================="
echo ""

# Test 1: Check if containers are running
echo "📊 Test 1: Container Status"
echo "----------------------------"
if docker-compose -f docker-compose.micro.yml --env-file .env.production ps | grep -q "Up"; then
    echo "✅ Containers are running"
    docker-compose -f docker-compose.micro.yml --env-file .env.production ps
else
    echo "❌ Containers are not running properly"
    echo "Try: docker-compose -f docker-compose.micro.yml --env-file .env.production up -d"
    exit 1
fi

echo ""

# Test 2: Health endpoint
echo "🏥 Test 2: Health Endpoint"
echo "--------------------------"
if curl -f -s http://localhost/health > /dev/null; then
    echo "✅ Health endpoint is responding"
    curl -s http://localhost/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost/health
else
    echo "❌ Health endpoint is not responding"
    echo "Check logs: docker-compose -f docker-compose.micro.yml --env-file .env.production logs web"
    exit 1
fi

echo ""

# Test 3: Database connection
echo "🗄️  Test 3: Database Connection"
echo "-------------------------------"
if docker-compose -f docker-compose.micro.yml --env-file .env.production logs db 2>/dev/null | grep -q "database system is ready to accept connections"; then
    echo "✅ Database is ready and accepting connections"
else
    echo "⚠️  Database might still be starting up"
    echo "Recent database logs:"
    docker-compose -f docker-compose.micro.yml --env-file .env.production logs db --tail=5 2>/dev/null || echo "Could not fetch database logs"
fi

echo ""

# Test 4: OAuth configuration
echo "🔐 Test 4: OAuth Configuration"
echo "------------------------------"
if grep -q "your-google-client-id" .env.production 2>/dev/null; then
    echo "⚠️  Google OAuth credentials still using placeholder values"
    echo "   Update GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env.production"
else
    echo "✅ Google OAuth credentials appear to be configured"
fi

# Check BASE_URL
base_url=$(grep "BASE_URL=" .env.production 2>/dev/null | cut -d'=' -f2)
if [ "$base_url" = "https://thefocuspad.com" ]; then
    echo "✅ BASE_URL is correctly set to HTTPS"
else
    echo "⚠️  BASE_URL: $base_url"
fi

echo ""

# Test 5: Application access
echo "🌐 Test 5: Application Access"
echo "-----------------------------"
if curl -f -s http://localhost/login > /dev/null; then
    echo "✅ Login page is accessible"
else
    echo "❌ Login page is not accessible"
fi

if curl -f -s http://localhost/api > /dev/null; then
    echo "✅ API documentation is accessible"
else
    echo "❌ API documentation is not accessible"
fi

echo ""

# Test 6: Session handling
echo "🍪 Test 6: Session Configuration"
echo "--------------------------------"
if docker-compose -f docker-compose.micro.yml --env-file .env.production exec web python3 -c "
import os, sys
sys.path.insert(0, '/app')
from app import create_app
app = create_app()
with app.app_context():
    secret_key = app.config.get('SECRET_KEY')
    if secret_key and secret_key != 'dev-secret-key-change-in-production':
        print('✅ SECRET_KEY is properly configured')
    else:
        print('⚠️  SECRET_KEY is using default value')
    
    base_url = app.config.get('BASE_URL')
    if base_url:
        print(f'✅ BASE_URL configured: {base_url}')
    else:
        print('❌ BASE_URL not configured in Flask app')
" 2>/dev/null; then
    echo "Session configuration check completed"
else
    echo "⚠️  Could not check session configuration"
fi

echo ""

# Summary
echo "📋 Test Summary"
echo "==============="
echo ""
echo "🔧 Manual Verification Steps:"
echo "1. Go to: https://thefocuspad.com"
echo "2. Click 'Sign in with Google'"
echo "3. Complete Google authentication"
echo "4. Verify you're redirected to dashboard (not back to login)"
echo ""
echo "⚙️  Google Cloud Console Settings:"
echo "- Authorized JavaScript origins: https://thefocuspad.com"
echo "- Authorized redirect URIs: https://thefocuspad.com/auth/callback/google"
echo ""
echo "🔍 If OAuth still loops to login:"
echo "1. Check Google Cloud Console settings above"
echo "2. Verify .env.production has correct GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"
echo "3. Check logs: docker-compose -f docker-compose.micro.yml --env-file .env.production logs -f web"
echo ""
echo "✅ Automated tests completed!" 