#!/usr/bin/env python3
"""
Data statistics script for FocusPad API.
Print user and note statistics.
"""

import os
import sys
from datetime import datetime, timedelta

# Add the app directory to Python path to import modules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from app.models.user import User
from app.models.note import Note

def print_data_statistics():
    """Print data statistics for users and notes."""
    
    print("=" * 50)
    print("📊 FOCUSPAD DATA STATISTICS")
    print("=" * 50)
    
    try:
        # 1. Total number of users
        total_users = User.query.count()
        print(f"👥 Total number of users: {total_users}")
        
        # 2. Total number of users in last 7 days
        seven_days_ago = datetime.utcnow() - timedelta(days=7)
        recent_users = User.query.filter(User.created_at >= seven_days_ago).count()
        print(f"📅 Users created in last 7 days: {recent_users}")
        
        # 3. Total number of notes created
        total_notes = Note.query.count()
        print(f"📝 Total number of notes created: {total_notes}")
        
        # Additional statistics
        print("\n" + "-" * 30)
        print("📈 ADDITIONAL STATISTICS")
        print("-" * 30)
        
        # Active notes (not archived)
        active_notes = Note.query.filter(Note.is_archived == False).count()
        archived_notes = Note.query.filter(Note.is_archived == True).count()
        print(f"📄 Active notes: {active_notes}")
        print(f"🗃️  Archived notes: {archived_notes}")
        
        # Notes created in last 7 days
        recent_notes = Note.query.filter(Note.created_at >= seven_days_ago).count()
        print(f"📝 Notes created in last 7 days: {recent_notes}")
        
        # Average notes per user
        if total_users > 0:
            avg_notes_per_user = round(total_notes / total_users, 2)
            print(f"📊 Average notes per user: {avg_notes_per_user}")
        
        # Most recent user
        latest_user = User.query.order_by(User.created_at.desc()).first()
        if latest_user:
            print(f"👤 Most recent user: {latest_user.name} ({latest_user.email})")
            print(f"   Joined: {latest_user.created_at.strftime('%Y-%m-%d %H:%M:%S')} UTC")
        
        # Most recent note
        latest_note = Note.query.order_by(Note.created_at.desc()).first()
        if latest_note:
            print(f"📋 Most recent note: {latest_note.title}")
            print(f"   Created: {latest_note.created_at.strftime('%Y-%m-%d %H:%M:%S')} UTC")
        
    except Exception as e:
        print(f"❌ Error retrieving statistics: {e}")
        print(f"💡 Make sure PostgreSQL database is running and accessible")
        return False
    
    print("\n" + "=" * 50)
    print(f"⏰ Generated at: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')} UTC")
    print("=" * 50)
    
    return True

def main():
    """Main function to initialize app and print statistics."""
    
    # Determine configuration environment
    config_name = os.environ.get('FLASK_ENV', 'development')
    
    print(f"🔧 Using environment: {config_name}")
    
    # Set database URL for local development if not set
    if not os.environ.get('DATABASE_URL'):
        # Use localhost:5432 if running outside Docker, or db:5432 if inside Docker
        if os.path.exists('/.dockerenv'):
            # Running inside Docker container
            os.environ['DATABASE_URL'] = 'postgresql://focuspad_user:focuspad_dev_password@db:5432/focuspad'
        else:
            # Running on host machine, connecting to Docker PostgreSQL
            os.environ['DATABASE_URL'] = 'postgresql://focuspad_user:focuspad_dev_password@localhost:5432/focuspad'
    
    # Create Flask application instance
    app = create_app(config_name)
    
    # Print database info
    print(f"🔗 Database: {app.config['SQLALCHEMY_DATABASE_URI']}")
    
    # Test database connection
    try:
        with app.app_context():
            # Try a simple query to test connection using SQLAlchemy 2.x syntax
            from sqlalchemy import text
            with db.engine.connect() as connection:
                connection.execute(text('SELECT 1'))
            print("✅ Database connection successful")
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        print("💡 Make sure PostgreSQL is running:")
        print("   - Docker: cd focuspad && docker-compose -f docker-compose.local.yml up db")
        print("   - Or run the full stack: docker-compose -f docker-compose.local.yml up")
        sys.exit(1)
    
    # Run within application context
    with app.app_context():
        success = print_data_statistics()
        
        if not success:
            sys.exit(1)

if __name__ == '__main__':
    main() 