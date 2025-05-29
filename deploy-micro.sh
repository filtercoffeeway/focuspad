#!/bin/bash

# FocusPad t2.micro Optimized Deployment Script
# Specifically designed for AWS t2.micro instances (1GB RAM, 1 vCPU)

set -e  # Exit on any error

echo "🚀 Starting FocusPad deployment on t2.micro..."
echo "⚠️  This deployment is optimized for AWS t2.micro (1GB RAM)"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please don't run this script as root"
    exit 1
fi

# Enable swap for t2.micro (CRITICAL for 1GB RAM)
echo "💾 Setting up swap file for t2.micro..."
if [ ! -f /swapfile ]; then
    echo "   Creating 1GB swap file..."
    sudo fallocate -l 1G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "✅ 1GB swap file created and enabled"
else
    echo "✅ Swap file already exists"
    sudo swapon /swapfile 2>/dev/null || echo "   Swap already enabled"
fi

# Set swappiness to be more aggressive (good for t2.micro)
echo "⚙️  Optimizing swap settings for t2.micro..."
echo 'vm.swappiness=80' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
sudo sysctl vm.swappiness=80
sudo sysctl vm.vfs_cache_pressure=50

# Show initial memory status
echo "📊 Initial memory status:"
free -h

# Update system packages (minimal to save time/resources)
echo "📦 Updating essential packages..."
sudo apt update
sudo apt install -y \
    curl \
    gnupg \
    lsb-release \
    git \
    ufw \
    htop \
    unzip

# Install Docker (using get.docker.com for efficiency)
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker (lightweight method)..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "🐳 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose already installed"
fi

# Configure firewall (essential ports only)
echo "🔥 Configuring firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force reload

# Application directory setup
APP_DIR="/home/$USER/focuspad"
if [ ! -d "$APP_DIR" ]; then
    echo "❌ FocusPad application files not found in $APP_DIR"
    echo "   Please upload your application files first"
    exit 1
fi

cd "$APP_DIR"

# Check for production environment file
if [ ! -f ".env.production" ]; then
    echo "⚠️  Production environment file not found!"
    echo "   Please create .env.production based on .env.production.example"
    echo "   Example setup:"
    echo "   cp .env.production.example .env.production"
    echo "   nano .env.production"
    exit 1
fi

# Load environment variables
set -o allexport
source .env.production
set +o allexport

# Create logs directory
mkdir -p logs

# Show memory before deployment
echo "📊 Memory before deployment:"
free -h

# Stop existing containers and clean up
echo "🛑 Stopping existing containers and cleaning up..."
docker-compose -f docker-compose.micro.yml down --remove-orphans 2>/dev/null || true
docker-compose -f docker-compose.yml down --remove-orphans 2>/dev/null || true

# Clean up Docker to save space (important for t2.micro)
echo "🧹 Cleaning up Docker to save space..."
docker system prune -af --volumes
docker builder prune -af

# Check available disk space
echo "💾 Available disk space:"
df -h /

# Build containers with minimal cache to save space
echo "🏗️  Building containers (optimized for t2.micro)..."
echo "   This may take several minutes on t2.micro..."
docker-compose -f docker-compose.micro.yml build --no-cache --parallel

# Show memory after build
echo "📊 Memory after build:"
free -h

# Start containers
echo "🚀 Starting containers..."
docker-compose -f docker-compose.micro.yml up -d

# Wait longer for t2.micro to start up
echo "⏳ Waiting for containers to be ready (t2.micro needs more time)..."
sleep 30

# Check container status
echo "📊 Container status:"
docker-compose -f docker-compose.micro.yml ps

# Monitor memory usage
echo "📊 Memory usage after startup:"
free -h
echo "📊 Docker container resource usage:"
docker stats --no-stream

# Setup database with retries (t2.micro can be slow)
echo "🗄️  Setting up database (with retries for t2.micro)..."
for i in {1..3}; do
    if docker-compose -f docker-compose.micro.yml exec -T web python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('Database tables created successfully')
"; then
        echo "✅ Database setup completed"
        break
    else
        echo "⏳ Database setup attempt $i failed, retrying in 10 seconds..."
        sleep 10
    fi
done

# Run encryption setup with timeout
echo "🔐 Setting up encryption..."
timeout 120 docker-compose -f docker-compose.micro.yml exec -T web python3 scripts/setup_encryption.py || echo "⚠️  Encryption setup timed out (common on t2.micro) - may need manual setup"

# Final health check
echo "🏥 Running health check..."
sleep 5
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✅ Health check passed!"
else
    echo "⚠️  Health check failed - check logs"
fi

# Final memory and resource status
echo ""
echo "📊 Final system status:"
free -h
echo ""
echo "📊 Docker resource usage:"
docker stats --no-stream
echo ""

echo "🎉 FocusPad t2.micro deployment completed!"
echo ""
echo "⚠️  t2.micro Performance Notes:"
echo "   - Your app is running with 1 Gunicorn worker"
echo "   - PostgreSQL is optimized for low memory usage"
echo "   - Swap file is enabled to handle memory spikes"
echo "   - Monitor CPU burst credits in AWS console"
echo ""
echo "🔧 t2.micro Management Commands:"
echo "   Monitor resources:     htop"
echo "   Check memory:         free -h"
echo "   Check swap usage:     swapon -s"
echo "   Docker stats:         docker stats"
echo "   Application logs:     docker-compose -f docker-compose.micro.yml logs -f web"
echo "   Restart if slow:      docker-compose -f docker-compose.micro.yml restart"
echo "   Full restart:         docker-compose -f docker-compose.micro.yml down && docker-compose -f docker-compose.micro.yml up -d"
echo ""
echo "🚨 Performance Warnings:"
echo "   - Expect slower response times (2-5 seconds)"
echo "   - Search may timeout on large datasets"
echo "   - Limit concurrent users to 2-3"
echo "   - Monitor AWS CloudWatch for CPU burst credits"
echo "   - Consider upgrading to t3.small for production"
echo ""
echo "📱 Access your app at: $BASE_URL"
echo "🏥 Health check: $BASE_URL/health"
echo "" 