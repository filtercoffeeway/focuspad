#!/bin/bash

# Fix nginx "Request Header Or Cookie Too Large" error
# Run this script on your EC2 instance

set -e

echo "🔧 Fixing nginx header size limits..."
echo "===================================="
echo ""

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo "❌ nginx not found. Please install nginx first."
    exit 1
fi

# Backup current configuration
echo "📦 Backing up current nginx configuration..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)

# Check if header buffer settings already exist
if grep -q "client_header_buffer_size" /etc/nginx/nginx.conf; then
    echo "⚠️  Header buffer settings already exist in nginx.conf"
    echo "Please check and adjust manually if needed."
else
    echo "✏️  Adding header buffer settings to nginx.conf..."
    
    # Add header buffer settings to http block
    sudo sed -i '/http {/a\\n\t# Increase header buffer sizes for large JWT tokens\n\tclient_header_buffer_size 4k;\n\tlarge_client_header_buffers 4 32k;\n\tclient_max_body_size 10M;\n' /etc/nginx/nginx.conf
    
    echo "✅ Added header buffer settings to nginx.conf"
fi

# Test nginx configuration
echo ""
echo "🧪 Testing nginx configuration..."
if sudo nginx -t; then
    echo "✅ nginx configuration test passed"
    
    # Reload nginx
    echo "🔄 Reloading nginx..."
    sudo systemctl reload nginx
    
    echo "✅ nginx reloaded successfully"
    echo ""
    echo "🎉 Fix applied successfully!"
    echo "Try accessing https://thefocuspad.com again"
else
    echo "❌ nginx configuration test failed"
    echo "Restoring backup..."
    sudo cp /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S) /etc/nginx/nginx.conf
    echo "Please check the configuration manually"
    exit 1
fi

echo ""
echo "📋 Current nginx status:"
sudo systemctl status nginx --no-pager -l 