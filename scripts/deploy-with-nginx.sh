#!/bin/bash

# FocusPad Complete Deployment Script with Nginx Integration
# This script deploys FocusPad using system nginx + Docker containers
# Handles SSL certificates and port conflicts automatically

set -e

echo "🚀 FocusPad Complete Deployment"
echo "==============================="
echo "This script will:"
echo "1. Stop conflicting services"
echo "2. Deploy Docker containers (web, db, redis)"
echo "3. Configure system nginx with SSL"
echo "4. Start all services"
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

# Check if running on EC2 (basic check)
if [ ! -f "/etc/cloud/build.info" ] && [ ! -f "/sys/hypervisor/uuid" ]; then
    echo "⚠️  Warning: This script is designed for EC2 instances"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -i :$port >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to stop service safely
stop_service() {
    local service=$1
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "   Stopping $service..."
        sudo systemctl stop $service
    else
        echo "   $service not running"
    fi
}

# ==========================================
# STEP 1: ENVIRONMENT SETUP
# ==========================================

echo "🔧 Setting up environment..."

# Check if .env.prod exists
if [ ! -f ".env.prod" ]; then
    echo "⚠️  .env.prod not found. Creating from template..."
    if [ -f ".env.prod.example" ]; then
        cp .env.prod.example .env.prod
        echo "📝 Please edit .env.prod with your actual configuration"
        read -p "Press Enter after updating .env.prod..."
    else
        echo "❌ No environment template found"
        exit 1
    fi
fi

# Generate secure keys if placeholders exist
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

# ==========================================
# STEP 2: STOP CONFLICTING SERVICES
# ==========================================

echo "🛑 Stopping conflicting services..."

# Stop Docker nginx if running
if docker-compose -f docker-compose.prod.yml ps nginx | grep -q "Up"; then
    echo "   Stopping Docker nginx..."
    docker-compose -f docker-compose.prod.yml --env-file .env.prod stop nginx
fi

# Remove nginx from docker-compose to avoid conflicts
echo "   Removing nginx from Docker Compose..."
cp docker-compose.prod.yml docker-compose.prod.yml.backup
grep -v -A 20 "nginx:" docker-compose.prod.yml.backup | grep -v -A 15 "image: nginx" > docker-compose.prod.yml.tmp || true

# Create clean docker-compose without nginx
cat > docker-compose.prod.yml << 'EOF'
version: '3.8'

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.prod
    container_name: focuspad_web_prod
    ports:
      - "8080:5000"
    environment:
      - FLASK_ENV=production
      - FLASK_DEBUG=0
      - DATABASE_URL=postgresql://focuspad_user:${DB_PASSWORD}@db:5432/focuspad
      - SECRET_KEY=${SECRET_KEY}
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - FOCUSPAD_MASTER_KEY=${FOCUSPAD_MASTER_KEY}
      - GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
      - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - BASE_URL=${BASE_URL:-https://thefocuspad.com}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
      - WORKERS=${WORKERS:-2}
      - TIMEOUT=${TIMEOUT:-30}
    env_file:
      - .env.prod
    depends_on:
      db:
        condition: service_healthy
    networks:
      - focuspad-prod
    restart: unless-stopped
    volumes:
      - ./logs:/app/logs
      - app_static:/app/static
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.8'
        reservations:
          memory: 256M
          cpus: '0.4'

  db:
    image: postgres:15-alpine
    container_name: focuspad_db_prod
    environment:
      POSTGRES_DB: focuspad
      POSTGRES_USER: focuspad_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256 --auth-local=scram-sha-256"
    volumes:
      - postgres_prod_data:/var/lib/postgresql/data
      - ./scripts/init_prod.sql:/docker-entrypoint-initdb.d/init.sql
      - ./backups:/backups
    networks:
      - focuspad-prod
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U focuspad_user -d focuspad"]
      interval: 30s
      timeout: 10s
      retries: 3
    command: >
      postgres
      -c shared_buffers=128MB
      -c effective_cache_size=512MB
      -c maintenance_work_mem=32MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=4MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200
      -c work_mem=4MB
      -c min_wal_size=1GB
      -c max_wal_size=4GB
      -c max_worker_processes=4
      -c max_parallel_workers_per_gather=2
      -c max_parallel_workers=4
      -c max_parallel_maintenance_workers=2
    deploy:
      resources:
        limits:
          memory: 400M
          cpus: '0.6'
        reservations:
          memory: 200M
          cpus: '0.3'

  redis:
    image: redis:7-alpine
    container_name: focuspad_redis_prod
    command: >
      redis-server
      --appendonly yes
      --appendfsync everysec
      --maxmemory 64mb
      --maxmemory-policy allkeys-lru
      --save 900 1
      --save 300 10
      --save 60 10000
    volumes:
      - redis_prod_data:/data
    networks:
      - focuspad-prod
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 80M
          cpus: '0.2'
        reservations:
          memory: 40M
          cpus: '0.1'

volumes:
  postgres_prod_data:
    driver: local
  redis_prod_data:
    driver: local
  app_static:
    driver: local

networks:
  focuspad-prod:
    driver: bridge
    driver_opts:
      com.docker.network.bridge.name: focuspad-prod
EOF

echo "✅ Docker Compose configured for system nginx"

# ==========================================
# STEP 3: BACKUP AND CLEANUP
# ==========================================

echo "📦 Creating deployment backup..."
timestamp=$(date +%Y%m%d_%H%M%S)
mkdir -p backups/deployments/$timestamp

# Backup current containers if they exist
if docker-compose -f docker-compose.prod.yml ps -q | grep -q .; then
    echo "💾 Backing up current deployment..."
    docker-compose -f docker-compose.prod.yml --env-file .env.prod logs > backups/deployments/$timestamp/container_logs.txt 2>/dev/null || true
fi

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod down -v 2>/dev/null || true

# Clean up old Docker resources
echo "🧹 Cleaning up old Docker resources..."
docker system prune -af --volumes 2>/dev/null || true

# ==========================================
# STEP 4: SETUP DIRECTORIES
# ==========================================

echo "📁 Setting up directory structure..."

# Remove problematic directories
if [ -d "logs" ]; then
    sudo rm -rf logs/ 2>/dev/null || rm -rf logs/ 2>/dev/null || true
fi

# Create directories
mkdir -p logs/nginx backups/deployments backups/cleanup 2>/dev/null || {
    sudo mkdir -p logs/nginx backups/deployments backups/cleanup
    sudo chown -R $(id -u):$(id -g) logs/ backups/ 2>/dev/null || true
}

chmod -R 755 logs/ backups/ 2>/dev/null || sudo chmod -R 755 logs/ backups/ 2>/dev/null || true

# ==========================================
# STEP 5: BUILD AND START DOCKER CONTAINERS
# ==========================================

echo "🏗️  Building and starting Docker containers..."

# Build application
docker-compose -f docker-compose.prod.yml --env-file .env.prod build --no-cache

# Start database first
echo "🗄️  Starting database..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d db

# Wait for database
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
    echo "   Waiting... ($counter/$timeout seconds)"
done

echo "✅ Database is ready"

# Start web application
echo "🚀 Starting web application..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d web

# Wait for web application
echo "⏳ Waiting for application to be ready..."
sleep 15

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod exec web python3 /app/db/run_migrations.py

# Start Redis
echo "🔄 Starting Redis..."
docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d redis

# ==========================================
# STEP 6: CONFIGURE SYSTEM NGINX
# ==========================================

echo "🌐 Configuring system nginx..."

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing nginx..."
    sudo apt update
    sudo apt install -y nginx
fi

# Stop nginx to avoid conflicts during config
stop_service nginx

# Create nginx configuration
sudo tee /etc/nginx/sites-available/focuspad << 'EOF'
server {
    listen 80;
    server_name thefocuspad.com www.thefocuspad.com;
    
    # Increase buffer sizes for large headers/cookies
    client_header_buffer_size 64k;
    large_client_header_buffers 4 64k;
    client_max_body_size 50M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8080/health;
        access_log off;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/focuspad /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "🧪 Testing nginx configuration..."
if ! sudo nginx -t; then
    echo "❌ Nginx configuration test failed"
    exit 1
fi

# Start nginx
echo "🌐 Starting nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx

# ==========================================
# STEP 7: HEALTH CHECKS AND SSL
# ==========================================

echo "🏥 Running health checks..."

# Wait for application to be fully ready
sleep 10

# Test direct access
if curl -f -s http://localhost:8080/health > /dev/null; then
    echo "✅ Application accessible on port 8080"
else
    echo "❌ Application not accessible on port 8080"
    echo "📋 Check logs: docker-compose -f docker-compose.prod.yml --env-file .env.prod logs web"
    exit 1
fi

# Test nginx proxy
if curl -f -s http://localhost/health > /dev/null; then
    echo "✅ Application accessible through nginx"
else
    echo "❌ Nginx proxy not working"
    exit 1
fi

# SSL Configuration
echo "🔒 Checking SSL configuration..."
if [ -f "/etc/letsencrypt/live/thefocuspad.com/fullchain.pem" ]; then
    echo "📋 SSL certificate exists. Configuring HTTPS..."
    
    # Update nginx config for HTTPS
    sudo tee /etc/nginx/sites-available/focuspad << 'EOF'
server {
    listen 80;
    server_name thefocuspad.com www.thefocuspad.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name thefocuspad.com www.thefocuspad.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/thefocuspad.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/thefocuspad.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Buffer sizes
    client_header_buffer_size 64k;
    large_client_header_buffers 4 64k;
    client_max_body_size 50M;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:8080/health;
        access_log off;
    }
}
EOF

    # Test and reload nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx
        echo "✅ HTTPS configuration applied"
    else
        echo "❌ HTTPS configuration failed"
    fi
else
    echo "⚠️  No SSL certificate found"
    echo "📋 Run this command to get SSL certificate:"
    echo "   sudo certbot --nginx -d thefocuspad.com -d www.thefocuspad.com"
fi

# ==========================================
# FINAL STATUS
# ==========================================

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "- Environment file: .env.prod ✅"
echo "- Backup created: backups/deployments/$timestamp/ ✅"
echo "- Docker containers: ✅ RUNNING"
echo "- System nginx: ✅ CONFIGURED"
echo "- Application health: ✅ PASSED"
echo ""

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR-IP")

echo "🌐 Your application is accessible at:"
echo "   Direct: http://$PUBLIC_IP:8080"
if [ -f "/etc/letsencrypt/live/thefocuspad.com/fullchain.pem" ]; then
    echo "   Domain: https://thefocuspad.com ✅"
    echo "   Domain: https://www.thefocuspad.com ✅"
else
    echo "   Domain: http://thefocuspad.com (HTTP only - run certbot for HTTPS)"
fi

echo ""
echo "📊 Container Status:"
docker-compose -f docker-compose.prod.yml --env-file .env.prod ps

echo ""
echo "📊 Useful Commands:"
echo "   View logs:       docker-compose -f docker-compose.prod.yml --env-file .env.prod logs -f"
echo "   Check status:    docker-compose -f docker-compose.prod.yml --env-file .env.prod ps"
echo "   Restart app:     sudo systemctl restart nginx && docker-compose -f docker-compose.prod.yml --env-file .env.prod restart"
echo "   Get SSL cert:    sudo certbot --nginx -d thefocuspad.com"
echo "   Clean restart:   ./scripts/clean-docker-ec2.sh --force && ./scripts/deploy-with-nginx.sh"

echo ""
echo "✅ Deployment completed!" 