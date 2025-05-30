#!/bin/bash

# Quick fix for missing database tables
# Run this if you get "relation 'users' does not exist" error

echo "🔧 Quick Fix: Creating Missing Database Tables"
echo "=============================================="

# Check if containers are running
if ! docker-compose -f docker-compose.micro.yml --env-file .env.production ps | grep -q "Up"; then
    echo "❌ Containers not running. Start them first:"
    echo "   docker-compose -f docker-compose.micro.yml --env-file .env.production up -d"
    exit 1
fi

echo "🗄️  Creating database tables..."

# Create and run database initialization
docker-compose -f docker-compose.micro.yml --env-file .env.production exec web python3 -c "
import sys
sys.path.insert(0, '/app')

try:
    from app import create_app, db
    from app.models import User, Note, Template, Content
    
    print('🔧 Initializing database...')
    app = create_app()
    
    with app.app_context():
        # Create all tables
        db.create_all()
        db.session.commit()
        
        # Verify tables
        from sqlalchemy import text
        result = db.session.execute(text('SELECT table_name FROM information_schema.tables WHERE table_schema = \'public\''))
        tables = [row[0] for row in result.fetchall()]
        
        print('✅ Created tables:')
        for table in sorted(tables):
            print(f'   - {table}')
        
        if 'users' in tables:
            print('✅ Users table created successfully!')
        else:
            print('❌ Users table missing!')
            
except Exception as e:
    print(f'❌ Error: {e}')
    import traceback
    traceback.print_exc()
"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Database tables created!"
    echo "🧪 Test OAuth again: https://thefocuspad.com"
else
    echo "❌ Failed to create tables"
    echo "📋 Check logs: docker-compose -f docker-compose.micro.yml --env-file .env.production logs web"
fi 