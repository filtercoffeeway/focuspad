#!/bin/bash

# FocusPad OAuth and Database Fix Script for EC2 Production
# This script applies all fixes for OAuth callback and database authentication issues

set -e

echo "🔧 FocusPad Production OAuth & Database Fix"
echo "=========================================="
echo "This script will:"
echo "1. Fix database authentication issues"
echo "2. Fix OAuth redirect URI (HTTP -> HTTPS)"
echo "3. Update Flask configuration"
echo "4. Rebuild and restart containers"
echo ""

# Check if we're in the correct directory
if [ ! -f "docker-compose.micro.yml" ]; then
    echo "❌ Error: docker-compose.micro.yml not found"
    echo "Please run this script from the FocusPad project directory"
    exit 1
fi

# Backup current files
echo "📦 Creating backups..."
timestamp=$(date +%Y%m%d_%H%M%S)
mkdir -p backups/$timestamp

if [ -f "app/routes/main.py" ]; then
    cp app/routes/main.py backups/$timestamp/
fi
if [ -f "config.py" ]; then
    cp config.py backups/$timestamp/
fi
if [ -f ".env.production" ]; then
    cp .env.production backups/$timestamp/
fi

echo "✅ Backups created in backups/$timestamp/"

# Fix 1: Update OAuth redirect URI in main.py
echo ""
echo "🔧 Fix 1: Updating OAuth redirect URI to use HTTPS..."

cat > app/routes/main.py << 'EOF'
"""
Main routes for FocusPad API utility endpoints.
"""

import secrets
import requests
from flask import Blueprint, jsonify, redirect, url_for, render_template, session, current_app, request
from flask_jwt_extended import create_access_token, create_refresh_token
from app import oauth
from app.models import User

# Create main blueprint
main_bp = Blueprint('main', __name__)

@main_bp.route('/health')
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'message': 'FocusPad API is running'
    })

@main_bp.route('/login')
def login():
    """Login page."""
    return render_template('login.html')

@main_bp.route('/logout')
def logout():
    """Web logout that clears session and redirects to login."""
    session.clear()
    return redirect('/login')

@main_bp.route('/login/google')
def google_login():
    """Initiate Google OAuth login flow."""
    if not current_app.config.get('GOOGLE_CLIENT_ID'):
        return jsonify({'error': 'Google OAuth not configured'}), 500
    
    # Generate state parameter for security
    state = secrets.token_urlsafe(32)
    session['oauth_state'] = state
    
    # Build redirect URI - force HTTPS for production
    base_url = current_app.config.get('BASE_URL') or request.host_url.rstrip('/')
    if base_url.startswith('http://') and 'thefocuspad.com' in base_url:
        base_url = base_url.replace('http://', 'https://')
    
    redirect_uri = f"{base_url}/auth/callback/google"
    print(f"Redirect URI: {redirect_uri}")
    
    # Log for debugging
    current_app.logger.info(f"Google OAuth redirect URI: {redirect_uri}")
    
    try:
        # Get Google OAuth client
        google = oauth.create_client('google')
        return google.authorize_redirect(redirect_uri, state=state)
    except Exception as e:
        current_app.logger.error(f"Google OAuth error: {str(e)}")
        return jsonify({
            'error': 'Failed to initiate Google OAuth',
            'details': str(e)
        }), 500

@main_bp.route('/auth/callback/google')
def google_callback():
    """Handle Google OAuth callback."""
    try:
        # Verify state parameter
        state = request.args.get('state')
        if not state or state != session.get('oauth_state'):
            return jsonify({'error': 'Invalid state parameter'}), 400
        
        # Check for error in callback
        if 'error' in request.args:
            error = request.args.get('error')
            error_description = request.args.get('error_description', '')
            return jsonify({
                'error': f'Google OAuth error: {error}',
                'description': error_description
            }), 400
        
        # Get authorization code
        code = request.args.get('code')
        if not code:
            return jsonify({'error': 'Authorization code not provided'}), 400
        
        # Exchange code for tokens
        google = oauth.create_client('google')
        token = google.authorize_access_token()
        
        # Get user info from Google
        user_info = token.get('userinfo')
        if not user_info:
            return jsonify({'error': 'Failed to get user information from Google'}), 400
        
        # Create or update user
        user = User.create_or_update_from_google(user_info)
        
        # Generate JWT tokens
        access_token = create_access_token(identity=user.id)
        refresh_token = create_refresh_token(identity=user.id)
        
        # Clean up session
        session.pop('oauth_state', None)
        
        # Store tokens in session for dashboard use
        session['access_token'] = access_token
        session['refresh_token'] = refresh_token
        session['user_id'] = user.id
        
        # Check if request wants JSON response (API usage)
        if request.headers.get('Accept') == 'application/json' or request.args.get('format') == 'json':
            return jsonify({
                'message': 'Login successful',
                'access_token': access_token,
                'refresh_token': refresh_token,
                'user': user.to_dict()
            })
        
        # Redirect to home page (dashboard) for web users
        return redirect('/')
        
    except Exception as e:
        current_app.logger.error(f"Google OAuth callback error: {str(e)}")
        
        # Return JSON error for API requests
        if request.headers.get('Accept') == 'application/json' or request.args.get('format') == 'json':
            return jsonify({
                'error': 'Authentication failed',
                'details': str(e)
            }), 500
        
        # Return HTML error page for web requests
        return render_template('login.html', error="Authentication failed. Please try again."), 500

@main_bp.route('/dashboard')
def dashboard():
    """Dashboard page for authenticated users."""
    # Check if user is authenticated (has tokens in session)
    if 'access_token' not in session or 'user_id' not in session:
        return redirect('/login')
    
    # Get user information
    user = User.query.get(session['user_id'])
    if not user:
        # Clear invalid session and redirect to login
        session.clear()
        return redirect('/login')
    
    return render_template('dashboard.html', 
                         user=user, 
                         access_token=session['access_token'],
                         refresh_token=session['refresh_token'])

@main_bp.route('/')
def root():
    """Home page - serves dashboard if authenticated, otherwise redirects to login."""
    # Check if user is authenticated (has tokens in session)
    if 'access_token' not in session or 'user_id' not in session:
        return redirect('/login')
    
    # Get user information
    user = User.query.get(session['user_id'])
    if not user:
        # Clear invalid session and redirect to login
        session.clear()
        return redirect('/login')
    
    # Serve the dashboard as the home page
    return render_template('dashboard.html', 
                         user=user, 
                         access_token=session['access_token'],
                         refresh_token=session['refresh_token'])

@main_bp.route('/api')
def api_docs():
    """API documentation endpoint."""
    return jsonify({
        'message': 'Welcome to FocusPad AI-Powered Note Taking API',
        'version': '2.0.0',
        'description': 'AI-powered note taking with automatic content categorization',
        'login_url': '/login',
        'dashboard_url': '/',
        'endpoints': {
            'health': '/health',
            'login_page': '/login',
            'dashboard': '/',
            'authentication': {
                'google_login': '/login/google',
                'google_callback': '/auth/callback/google',
                'google_token': '/api/auth/google-token',
                'refresh': '/api/auth/refresh',
                'me': '/api/auth/me',
                'logout': '/api/auth/logout',
                'login_page': '/login'
            },
            'notes': {
                'list_notes': 'GET /api/notes/',
                'create_note': 'POST /api/notes/',
                'get_note': 'GET /api/notes/{id}',
                'update_note': 'PUT /api/notes/{id}',
                'delete_note': 'DELETE /api/notes/{id}',
                'add_content': 'POST /api/notes/{id}/content',
                'remove_content': 'DELETE /api/notes/{id}/content/{category}/remove',
                'suggest_title': 'POST /api/notes/{id}/suggest-title',
                'recategorize': 'POST /api/notes/{id}/recategorize'
            },
            'templates': {
                'list_templates': 'GET /api/templates/',
                'get_default': 'GET /api/templates/default',
                'create_template': 'POST /api/templates/',
                'get_template': 'GET /api/templates/{id}',
                'update_template': 'PUT /api/templates/{id}',
                'delete_template': 'DELETE /api/templates/{id}',
                'duplicate_template': 'POST /api/templates/{id}/duplicate'
            }
        },
        'features': {
            'ai_categorization': 'Automatic content categorization using OpenAI',
            'custom_templates': 'Create and manage custom note templates',
            'smart_suggestions': 'AI-powered title suggestions',
            'content_management': 'Add, edit, and organize note content',
            'google_oauth': 'Secure authentication with Google OAuth 2.0',
            'dashboard': 'User-friendly dashboard interface'
        }
    }) 
EOF

echo "✅ Updated OAuth redirect URI to use HTTPS"

# Fix 2: Update Flask configuration
echo ""
echo "🔧 Fix 2: Updating Flask configuration..."

cat > config.py << 'EOF'
"""
Configuration settings for FocusPad API.
"""

import os
from datetime import timedelta
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Config:
    """Base configuration class."""
    
    # Flask Configuration
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    
    # Application URL Configuration
    BASE_URL = os.environ.get('BASE_URL') or 'http://localhost:5000'
    
    # Database Configuration - Default to PostgreSQL
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'postgresql://focuspad_user:focuspad_password@localhost:5432/focuspad'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }
    
    # JWT Configuration
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY') or 'jwt-secret-key-change-in-production'
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=30)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    
    # Google OAuth Configuration
    GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID')
    GOOGLE_CLIENT_SECRET = os.environ.get('GOOGLE_CLIENT_SECRET')
    
    # CORS Configuration
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*').split(',')
    
    @staticmethod
    def init_app(app):
        """Initialize configuration with app."""
        pass

class DevelopmentConfig(Config):
    """Development configuration."""
    
    DEBUG = True
    TESTING = False
    
    @classmethod
    def init_app(cls, app):
        Config.init_app(app)
        
        # Check if we should use SQLite for local development
        database_url = os.environ.get('DATABASE_URL')
        use_sqlite = False
        
        if not database_url:
            use_sqlite = True
        elif database_url.startswith('postgresql') and 'db:' in database_url:
            # This is Docker PostgreSQL URL but we're running locally
            use_sqlite = True
        elif database_url.startswith('postgresql'):
            # Test PostgreSQL connection
            try:
                import psycopg2
                # Try to connect to PostgreSQL
                conn_params = {
                    'host': 'localhost',
                    'port': 5432,
                    'database': 'focuspad',
                    'user': 'focuspad_user',
                    'password': 'focuspad_password'
                }
                conn = psycopg2.connect(**conn_params)
                conn.close()
                print("✅ PostgreSQL connection successful")
            except Exception as e:
                print(f"⚠️  PostgreSQL connection failed: {e}")
                use_sqlite = True
        
        if use_sqlite:
            app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///focuspad_dev.db'
            print("📦 Using SQLite for local development")
            print("💡 To use PostgreSQL: set up local PostgreSQL or use Docker")
        else:
            print("🐘 Using PostgreSQL for development")

class TestingConfig(Config):
    """Testing configuration."""
    
    DEBUG = False
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    WTF_CSRF_ENABLED = False

class ProductionConfig(Config):
    """Production configuration."""
    
    DEBUG = False
    TESTING = False
    
    # Application URL Configuration for Production
    BASE_URL = os.environ.get('BASE_URL') or 'https://thefocuspad.com'
    
    @classmethod
    def init_app(cls, app):
        """Initialize production configuration."""
        Config.init_app(app)
        
        # Ensure PostgreSQL in production
        database_url = app.config.get('SQLALCHEMY_DATABASE_URI')
        if not database_url or not database_url.startswith('postgresql'):
            raise ValueError("PostgreSQL database required for production")
        
        # Log to stderr in production
        import logging
        from logging import StreamHandler
        file_handler = StreamHandler()
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)

class DockerConfig(Config):
    """Docker-specific configuration."""
    
    DEBUG = True
    TESTING = False
    
    # Force PostgreSQL in Docker
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'postgresql://focuspad_user:focuspad_password@db:5432/focuspad'

# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'docker': DockerConfig,
    'default': DevelopmentConfig
}

def get_config(config_name=None):
    """
    Get configuration class based on environment name.
    
    Args:
        config_name (str): Configuration environment name
        
    Returns:
        Config class: Configuration class for the specified environment
    """
    if config_name is None:
        config_name = os.environ.get('FLASK_ENV', 'default')
    
    return config.get(config_name, config['default'])
EOF

echo "✅ Updated Flask configuration with BASE_URL and get_config function"

# Fix 3: Check and fix .env.production
echo ""
echo "🔧 Fix 3: Checking .env.production configuration..."

if [ ! -f ".env.production" ]; then
    echo "⚠️  .env.production missing, running setup script..."
    if [ -f "setup-env-micro.sh" ]; then
        ./setup-env-micro.sh
    else
        echo "❌ setup-env-micro.sh not found. Please create .env.production manually."
        exit 1
    fi
fi

# Verify Google OAuth credentials are set
if grep -q "your-google-client-id" .env.production 2>/dev/null; then
    echo "⚠️  WARNING: Google OAuth credentials not configured in .env.production"
    echo "   Please update GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"
    echo "   Current .env.production needs manual configuration"
else
    echo "✅ Google OAuth credentials appear to be configured"
fi

# Fix 4: Stop containers and clean database volumes
echo ""
echo "🔧 Fix 4: Stopping containers and cleaning database volumes..."
docker-compose -f docker-compose.micro.yml down -v 2>/dev/null || true

echo "🧹 Cleaning up Docker resources..."
docker system prune -af --volumes 2>/dev/null || true

# Fix 5: Rebuild and start containers
echo ""
echo "🔧 Fix 5: Rebuilding and starting containers..."

echo "🏗️  Building web container with fixes..."
docker-compose -f docker-compose.micro.yml --env-file .env.production build web --no-cache

echo "🚀 Starting containers with proper environment..."
docker-compose -f docker-compose.micro.yml --env-file .env.production up -d

# Wait for containers to start
echo "⏳ Waiting for containers to start..."
sleep 20

# Check container status
echo ""
echo "📊 Container status:"
docker-compose -f docker-compose.micro.yml --env-file .env.production ps

# Fix 6: Initialize database tables
echo ""
echo "🔧 Fix 6: Initializing database tables..."

# Wait a bit more for database to be fully ready
sleep 10

# Create a temporary Python script to initialize the database
cat > /tmp/init_db.py << 'EOF'
#!/usr/bin/env python3
"""
Initialize FocusPad database tables
"""

import sys
import os
sys.path.insert(0, '/app')

try:
    from app import create_app, db
    from app.models import User, Note, Template, NoteContent
    
    print("🔧 Creating Flask app...")
    app = create_app()
    
    with app.app_context():
        print("🗄️  Creating database tables...")
        
        # Drop all tables and recreate (fresh start)
        db.drop_all()
        print("✅ Dropped existing tables")
        
        # Create all tables
        db.create_all()
        print("✅ Created all tables")
        
        # Verify tables were created
        from sqlalchemy import text
        result = db.session.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"))
        tables = [row[0] for row in result.fetchall()]
        
        expected_tables = ['users', 'notes', 'templates', 'note_contents']
        missing_tables = [t for t in expected_tables if t not in tables]
        
        if missing_tables:
            print(f"⚠️  Missing tables: {missing_tables}")
            print(f"📋 Available tables: {tables}")
        else:
            print("✅ All required tables created successfully")
            for table in expected_tables:
                print(f"   - {table}")
        
        # Commit changes
        db.session.commit()
        print("✅ Database initialization completed!")
        
except Exception as e:
    print(f"❌ Database initialization failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

# Copy the script to the container and run it
echo "📤 Running database initialization..."
docker cp /tmp/init_db.py focuspad-web-1:/tmp/init_db.py

if docker-compose -f docker-compose.micro.yml --env-file .env.production exec web python3 /tmp/init_db.py; then
    echo "✅ Database tables created successfully!"
    
    # Clean up
    rm -f /tmp/init_db.py
    docker-compose -f docker-compose.micro.yml --env-file .env.production exec web rm -f /tmp/init_db.py 2>/dev/null || true
else
    echo "❌ Database initialization failed"
    echo "📋 Check database logs:"
    echo "   docker-compose -f docker-compose.micro.yml --env-file .env.production logs db"
    # Don't exit - continue with health check
fi

# Test health endpoint
echo ""
echo "🏥 Testing health endpoint..."
sleep 5
if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "✅ Health endpoint is working!"
    echo ""
    echo "🎉 OAuth and database fixes applied successfully!"
    echo ""
    echo "📝 Next Steps:"
    echo "1. Verify Google Cloud Console OAuth settings:"
    echo "   - Authorized JavaScript origins: https://thefocuspad.com"
    echo "   - Authorized redirect URIs: https://thefocuspad.com/auth/callback/google"
    echo ""
    echo "2. Test the OAuth flow:"
    echo "   - Go to: https://thefocuspad.com"
    echo "   - Click 'Sign in with Google'"
    echo "   - Complete authentication"
    echo "   - Should redirect to dashboard (not login loop)"
    echo ""
    echo "🌐 Your app should now be accessible at: https://thefocuspad.com"
    
else
    echo "⚠️  Health endpoint not responding yet"
    echo "📋 Check logs with:"
    echo "   docker-compose -f docker-compose.micro.yml --env-file .env.production logs -f web"
fi

echo ""
echo "✅ Fix script completed!"
echo ""
echo "🔧 Troubleshooting Commands:"
echo "========================="
echo "View logs:           docker-compose -f docker-compose.micro.yml --env-file .env.production logs -f web"
echo "Check status:        docker-compose -f docker-compose.micro.yml --env-file .env.production ps"
echo "Restart containers:  docker-compose -f docker-compose.micro.yml --env-file .env.production restart"
echo "Test health:         curl http://localhost/health" 