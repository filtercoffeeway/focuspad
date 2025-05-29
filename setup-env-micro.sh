#!/bin/bash

# FocusPad Environment Setup Script for t2.micro
# This script helps you create a secure .env.production file

set -e

echo "🔐 FocusPad Environment Setup for t2.micro"
echo "=========================================="
echo ""

# Check if .env.production already exists
if [ -f ".env.production" ]; then
    echo "⚠️  .env.production already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted. Please manually edit .env.production if needed."
        exit 1
    fi
    echo "📝 Backing up existing .env.production to .env.production.backup"
    cp .env.production .env.production.backup
fi

# Start with the example file
cp .env.micro.example .env.production

echo "🔑 Generating secure keys..."

# Generate SECRET_KEY
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
echo "✅ Generated SECRET_KEY"

# Generate FOCUSPAD_MASTER_KEY
FOCUSPAD_MASTER_KEY=$(python3 -c "import base64, os; print(base64.b64encode(os.urandom(32)).decode())")
echo "✅ Generated FOCUSPAD_MASTER_KEY"

# Generate JWT_SECRET_KEY
JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
echo "✅ Generated JWT_SECRET_KEY"

# Generate DB_PASSWORD
DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")
echo "✅ Generated DB_PASSWORD"

# Replace the generated values in .env.production
sed -i "s/SECRET_KEY=your-super-secret-key-here-make-it-very-long-and-random/SECRET_KEY=$SECRET_KEY/g" .env.production
sed -i "s/DB_PASSWORD=your-strong-database-password-here/DB_PASSWORD=$DB_PASSWORD/g" .env.production
sed -i "s|postgresql://focuspad_user:your-strong-database-password-here@db:5432/focuspad|postgresql://focuspad_user:$DB_PASSWORD@db:5432/focuspad|g" .env.production
sed -i "s/FOCUSPAD_MASTER_KEY=your-base64-encoded-master-key-here/FOCUSPAD_MASTER_KEY=$FOCUSPAD_MASTER_KEY/g" .env.production
sed -i "s/JWT_SECRET_KEY=your-jwt-secret-key-here/JWT_SECRET_KEY=$JWT_SECRET_KEY/g" .env.production

echo ""
echo "🔧 Manual Configuration Required:"
echo "=================================="
echo ""
echo "You still need to configure these values manually in .env.production:"
echo ""
echo "1. 🌐 GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com"
echo "2. 🔑 GOOGLE_CLIENT_SECRET=your-google-client-secret"
echo "3. 🤖 OPENAI_API_KEY=sk-your-openai-api-key-here (optional)"
echo "4. 🌍 BASE_URL=http://your-ec2-ip-or-domain"
echo ""
echo "📝 To edit the file manually:"
echo "nano .env.production"
echo ""

# Get EC2 public IP if possible
if command -v curl &> /dev/null; then
    echo "🔍 Trying to detect your EC2 public IP..."
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
    if [ ! -z "$PUBLIC_IP" ]; then
        echo "🌐 Detected EC2 Public IP: $PUBLIC_IP"
        sed -i "s|BASE_URL=http://your-ec2-ip-or-domain|BASE_URL=http://$PUBLIC_IP|g" .env.production
        echo "✅ Updated BASE_URL to http://$PUBLIC_IP"
    else
        echo "⚠️  Could not detect EC2 public IP. Please set BASE_URL manually."
    fi
fi

echo ""
echo "🎯 Next Steps:"
echo "=============="
echo ""
echo "1. Edit .env.production to add your Google OAuth credentials:"
echo "   nano .env.production"
echo ""
echo "2. To get Google OAuth credentials:"
echo "   - Go to https://console.cloud.google.com/"
echo "   - Create a new project or select existing"
echo "   - Enable Google+ API"
echo "   - Create OAuth 2.0 credentials"
echo "   - Add your domain/IP to authorized origins"
echo ""
echo "3. Run the deployment:"
echo "   ./deploy-micro.sh"
echo ""
echo "🔐 Security Notes:"
echo "=================="
echo "- All keys have been randomly generated"
echo "- Keep .env.production secure and never commit to Git"
echo "- The FOCUSPAD_MASTER_KEY is used for data encryption"
echo "- If you lose the master key, encrypted data cannot be recovered"
echo ""

# Show the file permissions
chmod 600 .env.production
echo "🔒 Set .env.production permissions to 600 (owner read/write only)"
echo ""
echo "✅ Environment setup completed!"
echo "📁 Your .env.production file is ready for manual configuration." 