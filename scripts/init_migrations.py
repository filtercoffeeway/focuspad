#!/usr/bin/env python3
"""
Initialize Flask-Migrate for FocusPad API.
"""

import os
import sys
from flask import Flask
from flask_migrate import Migrate, init, migrate, upgrade
from app import create_app, db

def init_migrations():
    """Initialize Flask-Migrate migrations folder."""
    app = create_app()
    
    with app.app_context():
        try:
            # Initialize migrations if not already done
            if not os.path.exists('migrations'):
                print("🔄 Initializing Flask-Migrate...")
                init()
                print("✅ Migrations initialized!")
            else:
                print("⚠️  Migrations folder already exists")
            
            # Create initial migration
            print("📝 Creating initial migration...")
            migrate(message='Initial migration with User model')
            print("✅ Initial migration created!")
            
            # Apply migration
            print("🚀 Applying migration to database...")
            upgrade()
            print("✅ Migration applied successfully!")
            
        except Exception as e:
            print(f"❌ Error during migration setup: {e}")
            return False
    
    return True

if __name__ == '__main__':
    success = init_migrations()
    sys.exit(0 if success else 1) 