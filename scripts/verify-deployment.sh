#!/bin/bash

# FocusPad Deployment Verification Script
# This script verifies that all required files and configurations are present
# Run this before deploying to catch common issues early

set -e

echo "🔍 FocusPad Deployment Verification"
echo "=================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

ERRORS=0
WARNINGS=0

# Function to report errors
report_error() {
    echo "❌ ERROR: $1"
    ((ERRORS++))
}

# Function to report warnings
report_warning() {
    echo "⚠️  WARNING: $1"
    ((WARNINGS++))
}

# Function to report success
report_success() {
    echo "✅ $1"
}

echo "📋 Checking required files..."

# Check required files
if [ -f "docker-compose.prod.yml" ]; then
    report_success "docker-compose.prod.yml exists"
else
    report_error "docker-compose.prod.yml not found"
fi

if [ -f "Dockerfile.prod" ]; then
    report_success "Dockerfile.prod exists"
else
    report_error "Dockerfile.prod not found"
fi

if [ -f "scripts/init_prod.sql" ]; then
    report_success "scripts/init_prod.sql exists"
else
    report_error "scripts/init_prod.sql not found (this will cause database initialization to fail)"
fi

if [ -f ".env.prod.example" ]; then
    report_success ".env.prod.example exists"
else
    report_warning ".env.prod.example not found"
fi

# Check environment file
if [ -f ".env.prod" ]; then
    report_success ".env.prod exists"
    
    # Check for required environment variables
    echo ""
    echo "🔐 Checking environment configuration..."
    
    if grep -q "GOOGLE_CLIENT_ID=" .env.prod && ! grep -q "your-google-client-id" .env.prod; then
        report_success "GOOGLE_CLIENT_ID configured"
    else
        report_warning "GOOGLE_CLIENT_ID not configured"
    fi
    
    if grep -q "GOOGLE_CLIENT_SECRET=" .env.prod && ! grep -q "your-google-client-secret" .env.prod; then
        report_success "GOOGLE_CLIENT_SECRET configured"
    else
        report_warning "GOOGLE_CLIENT_SECRET not configured"
    fi
    
    if grep -q "BASE_URL=" .env.prod && ! grep -q "yourdomain.com" .env.prod; then
        report_success "BASE_URL configured"
    else
        report_warning "BASE_URL not configured"
    fi
    
    if grep -q "SECRET_KEY=" .env.prod && ! grep -q "your-super-secret-key" .env.prod; then
        report_success "SECRET_KEY configured"
    else
        report_warning "SECRET_KEY not configured (will be auto-generated)"
    fi
    
else
    report_warning ".env.prod not found (will be created from template)"
fi

# Check Docker availability
echo ""
echo "🐳 Checking Docker..."
if command -v docker &> /dev/null; then
    report_success "Docker is installed"
    
    if docker info &> /dev/null; then
        report_success "Docker daemon is running"
    else
        report_error "Docker daemon is not running"
    fi
    
    if command -v docker-compose &> /dev/null; then
        report_success "Docker Compose is available"
    else
        report_error "Docker Compose not found"
    fi
else
    report_error "Docker not found"
fi

# Check database migration files
echo ""
echo "🗄️  Checking database migrations..."
if [ -d "db/migrations" ]; then
    report_success "db/migrations directory exists"
    
    if [ -f "db/migrations/001_initial_schema.sql" ]; then
        report_success "Initial schema migration exists"
    else
        report_error "Initial schema migration not found"
    fi
    
    if [ -f "db/run_migrations.py" ]; then
        report_success "Migration runner exists"
    else
        report_error "Migration runner not found"
    fi
else
    report_error "db/migrations directory not found"
fi

# Check script permissions
echo ""
echo "🔧 Checking script permissions..."
for script in deploy.sh start.sh stop.sh clean-docker-ec2.sh; do
    if [ -x "scripts/$script" ]; then
        report_success "scripts/$script is executable"
    else
        report_warning "scripts/$script is not executable (run: chmod +x scripts/$script)"
    fi
done

# Check available disk space (for local testing)
echo ""
echo "💾 Checking system resources..."
available_space=$(df -h . | tail -1 | awk '{print $4}')
report_success "Available disk space: $available_space"

# Memory check (if on Linux)
if command -v free &> /dev/null; then
    available_memory=$(free -h | grep '^Mem:' | awk '{print $7}')
    report_success "Available memory: $available_memory"
fi

# Final report
echo ""
echo "📊 Verification Summary"
echo "======================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "🎉 All checks passed! Ready for deployment."
    echo ""
    echo "🚀 Next steps:"
    echo "   1. ./scripts/deploy.sh"
    echo "   2. ./scripts/start.sh"
elif [ $ERRORS -eq 0 ]; then
    echo "✅ No critical errors found."
    echo "⚠️  Found $WARNINGS warnings - review and fix if needed."
    echo ""
    echo "🚀 You can proceed with deployment:"
    echo "   ./scripts/deploy.sh"
else
    echo "❌ Found $ERRORS critical errors and $WARNINGS warnings."
    echo "🛠️  Please fix the errors before deploying."
    exit 1
fi

echo ""
echo "💡 Helpful commands:"
echo "   Check deployment: ./scripts/verify-deployment.sh"
echo "   Clean start:      ./scripts/clean-docker-ec2.sh && ./scripts/deploy.sh"
echo "   View logs:        docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f" 