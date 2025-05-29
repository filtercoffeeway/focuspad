#!/usr/bin/env python3
"""
Initialize Flask-Migrate for FocusPad AI Features.
"""

import os
import sys
from flask import Flask
from flask_migrate import Migrate, init, migrate, upgrade
from app import create_app, db
from app.models import Template

def init_ai_migrations():
    """Initialize migrations and create default template."""
    app = create_app()
    
    with app.app_context():
        try:
            # Create all tables
            print("🗄️  Creating database tables...")
            db.create_all()
            print("✅ Database tables created!")
            
            # Create default template
            print("📝 Creating default template...")
            default_template = Template.create_default_template()
            print(f"✅ Default template created: {default_template.name}")
            
            # Initialize migrations if not already done
            if not os.path.exists('migrations'):
                print("🔄 Initializing Flask-Migrate...")
                init()
                print("✅ Migrations initialized!")
            
                # Create initial migration
                print("📝 Creating initial migration...")
                migrate(message='Add AI note-taking models: Template, Note, Content')
                print("✅ Initial migration created!")
            else:
                print("⚠️  Migrations folder already exists")
                # Create migration for new models
                print("📝 Creating migration for AI features...")
                migrate(message='Add AI note-taking models: Template, Note, Content')
                print("✅ Migration created!")
            
            # Apply migration
            print("🚀 Applying migration to database...")
            upgrade()
            print("✅ Migration applied successfully!")
            
            print("\n🎉 AI Note-Taking Features Ready!")
            print("📋 Default Template Categories:")
            for category in default_template.get_categories():
                print(f"  {category.get('icon', '•')} {category['name']}: {category['description']}")
            
        except Exception as e:
            print(f"❌ Error during AI migration setup: {e}")
            return False
    
    return True

if __name__ == '__main__':
    success = init_ai_migrations()
    sys.exit(0 if success else 1) 