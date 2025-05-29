#!/usr/bin/env python3
"""
Entry point for FocusPad API application.
"""

import os
from app import create_app, db

# Determine configuration environment
config_name = os.environ.get('FLASK_ENV', 'development')

# Create Flask application instance for Gunicorn
app = create_app(config_name)

def main():
    """Main application entry point for direct execution."""
    
    # Create database tables if they don't exist
    with app.app_context():
        try:
            db.create_all()
            print("✅ Database tables created/verified")
        except Exception as e:
            print(f"⚠️  Database initialization warning: {e}")
    
    # Get host and port from environment or use defaults
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5000))
    debug = app.config.get('DEBUG', False)
    
    print(f"🚀 Starting FocusPad API...")
    print(f"🌐 Server: http://{host}:{port}")
    print(f"🔧 Environment: {config_name}")
    print(f"🔧 Debug mode: {debug}")
    print(f"📊 Database: {app.config['SQLALCHEMY_DATABASE_URI']}")
    print(f"🔑 Google OAuth configured: {bool(app.config.get('GOOGLE_CLIENT_ID'))}")
    print(f"🌍 Login page: http://{host}:{port}/login")
    print(f"🏥 Health check: http://{host}:{port}/health")
    
    # Run the application
    app.run(host=host, port=port, debug=debug)

if __name__ == '__main__':
    main() 