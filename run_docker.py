#!/usr/bin/env python3
"""
Docker-specific entry point for FocusPad API.
"""

import os
import time
import psycopg2
from psycopg2 import OperationalError
from app import create_app, db
from flask_cli import register_commands

def wait_for_db():
    """Wait for PostgreSQL database to be ready."""
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            # Try to connect to PostgreSQL
            conn = psycopg2.connect(
                host='db',
                database='focuspad',
                user='focuspad_user',
                password='focuspad_password',
                port=5432
            )
            conn.close()
            print("✅ PostgreSQL is ready!")
            return True
        except OperationalError:
            retry_count += 1
            print(f"⏳ Waiting for PostgreSQL... (attempt {retry_count}/{max_retries})")
            time.sleep(2)
    
    print("❌ Could not connect to PostgreSQL after 30 attempts")
    return False

def init_database(app):
    """Initialize database tables."""
    try:
        with app.app_context():
            db.create_all()
            print("✅ Database tables created successfully!")
            return True
    except Exception as e:
        print(f"❌ Error creating database tables: {e}")
        return False

if __name__ == '__main__':
    print("🚀 Starting FocusPad API in Docker...")
    
    # Wait for database to be ready
    if not wait_for_db():
        exit(1)
    
    # Create app using Docker configuration
    app = create_app('docker')
    
    # Register CLI commands
    register_commands(app)
    
    # Initialize database
    if not init_database(app):
        exit(1)
    
    # Get configuration from environment
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5000))
    debug = app.config.get('DEBUG', False)
    
    print(f"🌐 Starting server on {host}:{port}")
    print(f"🔧 Debug mode: {debug}")
    print(f"📊 Database: {app.config['SQLALCHEMY_DATABASE_URI']}")
    print(f"🔑 Google OAuth configured: {bool(app.config.get('GOOGLE_CLIENT_ID'))}")
    print(f"🛠️  Flask CLI available in container")
    
    # Run the application
    app.run(host=host, port=port, debug=debug) 