#!/bin/bash

# FocusPad SSL/HTTPS Setup Script using Let's Encrypt
# Run this script after your domain is pointing to your EC2 instance

set -e

echo "🔒 Setting up SSL/HTTPS for FocusPad..."

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

# Install Certbot
echo "📦 Installing Certbot..."
sudo apt update
sudo apt install -y certbot python3-certbot-nginx nginx

# Stop FocusPad temporarily
echo "🛑 Stopping FocusPad temporarily..."
cd /home/$USER/focuspad
docker-compose -f docker-compose.prod.yml down

# Create Nginx configuration
echo "🔧 Creating Nginx configuration..."
sudo tee /etc/nginx/sites-available/focuspad > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/focuspad /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Start Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# Get SSL certificate
echo "🔐 Obtaining SSL certificate..."
sudo certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME

# Update Docker Compose for internal port
echo "🐳 Updating Docker Compose configuration..."
sed -i 's/- "80:5000"/- "5000:5000"/' docker-compose.prod.yml

# Update environment variables
if [ -f ".env.production" ]; then
    sed -i "s|BASE_URL=.*|BASE_URL=https://$DOMAIN_NAME|" .env.production
    sed -i "s|SECURE_SSL_REDIRECT=False|SECURE_SSL_REDIRECT=True|" .env.production
    sed -i "s|SESSION_COOKIE_SECURE=False|SESSION_COOKIE_SECURE=True|" .env.production
fi

# Start FocusPad
echo "🚀 Starting FocusPad with SSL..."
docker-compose -f docker-compose.prod.yml up -d

# Set up automatic renewal
echo "🔄 Setting up automatic SSL renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Test SSL renewal
sudo certbot renew --dry-run

echo ""
echo "🎉 SSL setup completed successfully!"
echo ""
echo "✅ Your FocusPad application is now available at: https://$DOMAIN_NAME"
echo ""
echo "🔧 SSL Management:"
echo "   Check SSL status:    sudo certbot certificates"
echo "   Renew SSL manually:  sudo certbot renew"
echo "   Nginx status:        sudo systemctl status nginx"
echo "   Nginx reload:        sudo systemctl reload nginx"
echo ""
echo "⚠️  Important reminders:"
echo "   - Update your Google OAuth settings to use https://$DOMAIN_NAME"
echo "   - Update any other API integrations with the new HTTPS URL"
echo "   - Monitor SSL certificate expiry (auto-renewal is set up)"
echo "" 