#!/bin/bash

# FocusPad SSL/HTTPS Setup Script for t2.micro
# Optimized for low-resource deployment

set -e

echo "🔒 Setting up SSL/HTTPS for FocusPad on t2.micro..."
echo "⚠️  This process is optimized for t2.micro resources"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please don't run this script as root"
    exit 1
fi

# Get domain name from user
read -p "Enter your domain name (e.g., focuspad.yourdomain.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo "❌ Domain name is required"
    exit 1
fi

echo "🌐 Setting up SSL for domain: $DOMAIN_NAME"

# Check memory before starting
echo "📊 Memory before SSL setup:"
free -h

# Install Certbot and Nginx (minimal installation)
echo "📦 Installing Certbot and Nginx..."
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Stop FocusPad temporarily
echo "🛑 Stopping FocusPad temporarily..."
cd /home/$USER/focuspad
docker-compose -f docker-compose.micro.yml down

# Create optimized Nginx configuration for t2.micro
echo "🔧 Creating optimized Nginx configuration for t2.micro..."
sudo tee /etc/nginx/sites-available/focuspad > /dev/null <<EOF
# Nginx configuration optimized for t2.micro
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Basic security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    
    # Optimize for t2.micro
    client_max_body_size 10M;
    client_body_timeout 30s;
    client_header_timeout 30s;
    keepalive_timeout 15s;
    send_timeout 30s;
    
    # Gzip compression to save bandwidth
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Optimized timeouts for t2.micro
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings for t2.micro
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:5000/health;
        access_log off;
    }
}
EOF

# Create optimized nginx.conf for t2.micro
echo "⚙️  Optimizing main Nginx configuration for t2.micro..."
sudo tee /etc/nginx/nginx.conf > /dev/null <<EOF
user www-data;
worker_processes 1;  # Single worker for t2.micro
pid /run/nginx.pid;

events {
    worker_connections 512;  # Reduced for t2.micro
    use epoll;
    multi_accept on;
}

http {
    # Basic settings optimized for t2.micro
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 15;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Reduced buffer sizes for t2.micro
    client_body_buffer_size 16K;
    client_header_buffer_size 1k;
    large_client_header_buffers 2 1k;
    client_max_body_size 10M;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Include sites
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/focuspad /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
echo "🧪 Testing Nginx configuration..."
sudo nginx -t

# Start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Show memory after Nginx setup
echo "📊 Memory after Nginx setup:"
free -h

# Get SSL certificate with minimal resource usage
echo "🔐 Obtaining SSL certificate (this may take time on t2.micro)..."
sudo certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME --no-eff-email

# Update Docker Compose for internal port
echo "🐳 Updating Docker Compose configuration..."
sed -i 's/- "80:5000"/- "5000:5000"/' docker-compose.micro.yml

# Update environment variables for HTTPS
if [ -f ".env.production" ]; then
    echo "🔧 Updating environment variables for HTTPS..."
    sed -i "s|BASE_URL=.*|BASE_URL=https://$DOMAIN_NAME|" .env.production
    sed -i "s|SECURE_SSL_REDIRECT=False|SECURE_SSL_REDIRECT=True|" .env.production
    sed -i "s|SESSION_COOKIE_SECURE=False|SESSION_COOKIE_SECURE=True|" .env.production
fi

# Start FocusPad
echo "🚀 Starting FocusPad with SSL..."
docker-compose -f docker-compose.micro.yml up -d

# Wait for startup
echo "⏳ Waiting for application to start..."
sleep 15

# Set up automatic renewal (lightweight cron job)
echo "🔄 Setting up automatic SSL renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Test SSL renewal
echo "🧪 Testing SSL renewal process..."
sudo certbot renew --dry-run

# Final memory check
echo "📊 Final memory status:"
free -h

# Test HTTPS
echo "🏥 Testing HTTPS connection..."
sleep 5
if curl -f https://$DOMAIN_NAME/health > /dev/null 2>&1; then
    echo "✅ HTTPS health check passed!"
else
    echo "⚠️  HTTPS health check failed - may need a few more minutes"
fi

echo ""
echo "🎉 SSL setup for t2.micro completed successfully!"
echo ""
echo "✅ Your FocusPad application is now available at: https://$DOMAIN_NAME"
echo ""
echo "🔧 t2.micro SSL Management:"
echo "   Check SSL status:    sudo certbot certificates"
echo "   Renew SSL manually:  sudo certbot renew"
echo "   Nginx status:        sudo systemctl status nginx"
echo "   Nginx reload:        sudo nginx -s reload"
echo "   Monitor memory:      free -h"
echo ""
echo "⚠️  t2.micro HTTPS Performance Notes:"
echo "   - HTTPS adds ~10-20% CPU overhead"
echo "   - Monitor CPU burst credits more closely"
echo "   - SSL handshake may be slower (2-3 seconds)"
echo "   - Consider HTTP for development, HTTPS for production"
echo ""
echo "🔄 Important Updates Required:"
echo "   1. Update Google OAuth settings to use https://$DOMAIN_NAME"
echo "   2. Update any API integrations with the new HTTPS URL"
echo "   3. Monitor AWS CloudWatch for resource usage"
echo ""
echo "📱 Test your app: https://$DOMAIN_NAME"
echo "🏥 Health check: https://$DOMAIN_NAME/health"
echo "" 