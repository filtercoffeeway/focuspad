#!/bin/bash

# FocusPad EC2 Instance Setup Script
# This script sets up a fresh EC2 instance with all required dependencies
# Run this once on a new Ubuntu 22.04 LTS instance

set -e

echo "🚀 FocusPad EC2 Instance Setup"
echo "=============================="
echo "This script will install:"
echo "1. Docker and Docker Compose"
echo "2. Nginx with SSL (Let's Encrypt)"
echo "3. System dependencies"
echo "4. Security configurations"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root"
   echo "Please run as ubuntu user: sudo will be used when needed"
   exit 1
fi

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
echo "📦 Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    htop \
    tree

# Install Docker
echo "🐳 Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    sudo mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    echo "✅ Docker installed successfully"
else
    echo "✅ Docker already installed"
fi

# Install Docker Compose (standalone)
echo "🐳 Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
else
    echo "✅ Docker Compose already installed"
fi

# Install Nginx
echo "🌐 Installing Nginx..."
sudo apt install -y nginx

# Install Certbot for SSL
echo "🔒 Installing Certbot for SSL..."
sudo apt install -y certbot python3-certbot-nginx

# Configure UFW Firewall
echo "🔥 Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

# Configure fail2ban
echo "🛡️  Configuring fail2ban..."
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Create nginx configuration for FocusPad
echo "🌐 Creating Nginx configuration..."
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
sudo nginx -t

# Create application directory
echo "📁 Creating application directory..."
sudo mkdir -p /opt/focuspad
sudo chown $USER:$USER /opt/focuspad

# Create systemd service for auto-start
echo "⚙️  Creating systemd service..."
sudo tee /etc/systemd/system/focuspad.service << 'EOF'
[Unit]
Description=FocusPad Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/focuspad
ExecStart=/opt/focuspad/scripts/start.sh
ExecStop=/opt/focuspad/scripts/stop.sh
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
EOF

# Enable services
sudo systemctl enable nginx
sudo systemctl enable docker
sudo systemctl enable focuspad

# Start services
sudo systemctl start nginx
sudo systemctl start docker

echo ""
echo "🎉 Instance setup completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Clone your FocusPad repository to /opt/focuspad"
echo "2. Run ./scripts/deploy.sh to deploy the application"
echo "3. Run sudo certbot --nginx -d thefocuspad.com -d www.thefocuspad.com for SSL"
echo ""
echo "📊 System Information:"
echo "- Docker version: $(docker --version 2>/dev/null || echo 'Not available yet - logout/login required')"
echo "- Docker Compose version: $(docker-compose --version 2>/dev/null || echo 'Not available yet')"
echo "- Nginx status: $(sudo systemctl is-active nginx)"
echo "- UFW status: $(sudo ufw status | grep Status | awk '{print $2}')"
echo ""
echo "⚠️  IMPORTANT: Logout and login again to use Docker without sudo"
echo "💡 Or run: newgrp docker" 