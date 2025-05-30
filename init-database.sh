#!/bin/bash

# Database Initialization Script for FocusPad
# This script creates the required database tables

set -e

echo "🗄️  Initializing FocusPad Database"
echo "=================================="
echo ""

# Check if containers are running
if ! docker-compose -f docker-compose.micro.yml --env-file .env.production ps | grep -q "Up"; then
    echo "❌ Error: Containers are not running"
    echo "Start containers first: docker-compose -f docker-compose.micro.yml --env-file .env.production up -d"
    exit 1
fi

echo "📋 Creating database tables..."

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
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
    from app.models import User, Note, Template, Content
    
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
        
        expected_tables = ['users', 'notes', 'templates', 'contents']
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
    echo ""
    echo "🎉 Database initialization successful!"
    echo ""
    echo "📋 Verifying database tables..."
    
    # Verify tables exist
    if docker-compose -f docker-compose.micro.yml --env-file .env.production exec web python3 -c "
import sys
sys.path.insert(0, '/app')
from app import create_app, db
from sqlalchemy import text

app = create_app()
with app.app_context():
    result = db.session.execute(text(\"SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'\"))
    tables = [row[0] for row in result.fetchall()]
    print('📋 Database tables:')
    for table in sorted(tables):
        print(f'   ✅ {table}')
"; then
        echo ""
        echo "✅ Database is ready for OAuth authentication!"
    else
        echo "⚠️  Could not verify database tables"
    fi
else
    echo "❌ Database initialization failed"
    echo "📋 Check database logs:"
    echo "   docker-compose -f docker-compose.micro.yml --env-file .env.production logs db"
    exit 1
fi

# Clean up
rm -f /tmp/init_db.py
docker-compose -f docker-compose.micro.yml --env-file .env.production exec web rm -f /tmp/init_db.py 2>/dev/null || true

echo ""
echo "✅ Database initialization completed!"
echo ""
echo "🧪 Test OAuth now:"
echo "1. Go to: https://thefocuspad.com"
echo "2. Click 'Sign in with Google'"
echo "3. Complete authentication"
echo "4. Should redirect to dashboard successfully!" 