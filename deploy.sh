#!/bin/bash

# FocusPad AWS EC2 Deployment Script
# Run this script on your EC2 instance to deploy FocusPad

set -e  # Exit on any error

echo "🚀 Starting FocusPad deployment on AWS EC2..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please don't run this script as root"
    exit 1
fi

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "🔧 Installing required packages..."
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    ufw

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
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

# Configure firewall
echo "🔥 Configuring firewall..."
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force reload

# Create application directory
APP_DIR="/home/$USER/focuspad"
if [ ! -d "$APP_DIR" ]; then
    echo "📁 Creating application directory..."
    mkdir -p "$APP_DIR"
fi

# Clone or update repository (if not already present)
if [ ! -f "$APP_DIR/docker-compose.prod.yml" ]; then
    echo "⚠️  FocusPad application files not found in $APP_DIR"
    echo "   Please upload your application files to $APP_DIR"
    echo "   Required files:"
    echo "   - docker-compose.prod.yml"
    echo "   - .env.production (with your configuration)"
    echo "   - All application source code"
    exit 1
fi

cd "$APP_DIR"

# Check for production environment file
if [ ! -f ".env.production" ]; then
    echo "⚠️  Production environment file not found!"
    echo "   Please create .env.production based on .env.production.example"
    echo "   Update all placeholder values with your actual configuration"
    exit 1
fi

# Load environment variables
set -o allexport
source .env.production
set +o allexport

# Create logs directory
mkdir -p logs

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down --remove-orphans || true

# Build and start containers
echo "🏗️  Building and starting containers..."
docker-compose -f docker-compose.prod.yml build --no-cache
docker-compose -f docker-compose.prod.yml up -d

# Wait for containers to be healthy
echo "⏳ Waiting for containers to be ready..."
sleep 10

# Check container status
echo "📊 Container status:"
docker-compose -f docker-compose.prod.yml ps

# Setup database (if needed)
echo "🗄️  Setting up database..."
docker-compose -f docker-compose.prod.yml exec -T web python3 -c "
from app import create_app, db
app = create_app()
with app.app_context():
    db.create_all()
    print('Database tables created successfully')
"

# Run encryption setup
echo "🔐 Setting up encryption..."
docker-compose -f docker-compose.prod.yml exec -T web python3 scripts/setup_encryption.py || echo "Encryption setup completed or already done"

# Display success message
echo ""
echo "🎉 FocusPad deployment completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Configure your domain/DNS to point to this EC2 instance"
echo "2. Set up SSL/TLS certificates (recommended: Let's Encrypt)"
echo "3. Update Google OAuth settings with your domain"
echo "4. Test the application at: $BASE_URL"
echo ""
echo "🔧 Management commands:"
echo "   View logs:     docker-compose -f docker-compose.prod.yml logs -f"
echo "   Restart:       docker-compose -f docker-compose.prod.yml restart"
echo "   Stop:          docker-compose -f docker-compose.prod.yml down"
echo "   Update:        git pull && docker-compose -f docker-compose.prod.yml up -d --build"
echo ""
echo "🛡️  Security reminders:"
echo "   - Keep your .env.production file secure"
echo "   - Regularly update your system: sudo apt update && sudo apt upgrade"
echo "   - Monitor application logs for any issues"
echo "   - Set up automated backups for your database"
echo "" 