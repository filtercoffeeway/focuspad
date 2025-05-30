#!/bin/bash

# Super quick fix - just create the users table
echo "🔧 Quick Fix: Creating Users Table"
echo "=================================="

# One-liner to create just the users table
docker-compose -f docker-compose.micro.yml --env-file .env.production exec web python3 -c "
import sys; sys.path.insert(0, '/app')
from app import create_app, db
from app.models import User

app = create_app()
with app.app_context():
    try:
        # Just create the users table (minimum needed for OAuth)
        User.__table__.create(db.engine, checkfirst=True)
        db.session.commit()
        print('✅ Users table created!')
        
        # Verify
        from sqlalchemy import text
        result = db.session.execute(text(\"SELECT table_name FROM information_schema.tables WHERE table_name = 'users'\"))
        if result.fetchone():
            print('✅ Users table verified!')
        else:
            print('❌ Users table not found')
    except Exception as e:
        print(f'Error: {e}')
        # Try creating all tables as fallback
        try:
            db.create_all()
            db.session.commit()
            print('✅ Created all tables as fallback')
        except Exception as e2:
            print(f'Fallback failed: {e2}')
"

echo "✅ Done! Test OAuth now: https://thefocuspad.com" 