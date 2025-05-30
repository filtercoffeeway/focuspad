#!/usr/bin/env python3
"""
Enhanced Database Migration Runner for FocusPad.
Runs migrations sequentially and tracks the last migration number.
"""

import os
import sys
import glob
import re
from pathlib import Path

# Add app directory to Python path
sys.path.insert(0, '/app')

from app import create_app, db
from sqlalchemy import text

def run_migrations():
    """Run all pending migrations sequentially."""
    app = create_app()
    
    with app.app_context():
        try:
            print("🔄 Running database migrations...")
            
            # Get migrations directory
            migrations_dir = Path(__file__).parent / 'migrations'
            if not migrations_dir.exists():
                print("❌ Migrations directory not found!")
                return False
            
            # Get all migration files sorted by number
            migration_files = get_sorted_migration_files(str(migrations_dir))
            
            if not migration_files:
                print("ℹ️  No migration files found")
                return True
            
            print(f"📁 Found {len(migration_files)} migration files")
            
            # Create migrations tracking table
            create_migrations_table()
            
            # Get last applied migration number
            last_migration = get_last_migration_number()
            print(f"📊 Last applied migration: {last_migration or 'None'}")
            
            applied_count = 0
            skipped_count = 0
            
            for migration_file, migration_number in migration_files:
                filename = os.path.basename(migration_file)
                
                # Skip if already applied
                if last_migration and migration_number <= last_migration:
                    print(f"⏭️  Skipping {filename} (migration {migration_number} already applied)")
                    skipped_count += 1
                    continue
                
                print(f"🔧 Applying {filename} (migration {migration_number})...")
                
                try:
                    # Read and execute migration
                    with open(migration_file, 'r') as f:
                        migration_sql = f.read()
                    
                    # Execute the migration
                    db.session.execute(text(migration_sql))
                    
                    # Update last migration number
                    update_last_migration_number(migration_number)
                    
                    # Commit the transaction
                    db.session.commit()
                    
                    print(f"✅ Applied {filename}")
                    applied_count += 1
                    
                except Exception as e:
                    print(f"❌ Failed to apply {filename}: {e}")
                    db.session.rollback()
                    return False
            
            print(f"🎉 Migration complete!")
            print(f"   Applied: {applied_count}")
            print(f"   Skipped: {skipped_count}")
            
            if applied_count > 0:
                current_migration = get_last_migration_number()
                print(f"📈 Current migration level: {current_migration}")
            
            return True
            
        except Exception as e:
            print(f"❌ Migration failed: {e}")
            db.session.rollback()
            return False

def get_sorted_migration_files(migrations_dir):
    """Get migration files sorted by migration number."""
    migration_files = []
    
    for file_path in glob.glob(os.path.join(migrations_dir, "*.sql")):
        filename = os.path.basename(file_path)
        
        # Extract migration number from filename (format: 001_description.sql)
        match = re.match(r'^(\d+)_.*\.sql$', filename)
        if match:
            migration_number = int(match.group(1))
            migration_files.append((file_path, migration_number))
        else:
            print(f"⚠️  Skipping invalid migration filename: {filename}")
    
    # Sort by migration number
    migration_files.sort(key=lambda x: x[1])
    return migration_files

def create_migrations_table():
    """Create table to track migration state."""
    try:
        db.session.execute(text("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                id SERIAL PRIMARY KEY,
                migration_number INTEGER UNIQUE NOT NULL,
                filename VARCHAR(255) NOT NULL,
                applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        
        # Also create a simple tracking table for last migration
        db.session.execute(text("""
            CREATE TABLE IF NOT EXISTS migration_state (
                id INTEGER PRIMARY KEY DEFAULT 1,
                last_migration INTEGER NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT single_row CHECK (id = 1)
            )
        """))
        
        # Initialize migration state if empty
        db.session.execute(text("""
            INSERT INTO migration_state (id, last_migration) 
            SELECT 1, 0 
            WHERE NOT EXISTS (SELECT 1 FROM migration_state WHERE id = 1)
        """))
        
        db.session.commit()
    except Exception as e:
        print(f"⚠️  Could not create migrations tables: {e}")
        db.session.rollback()

def get_last_migration_number():
    """Get the last applied migration number."""
    try:
        result = db.session.execute(
            text("SELECT last_migration FROM migration_state WHERE id = 1")
        )
        row = result.fetchone()
        return row[0] if row else 0
    except Exception:
        return 0

def update_last_migration_number(migration_number):
    """Update the last applied migration number."""
    # Update the simple state table
    db.session.execute(
        text("""
            UPDATE migration_state 
            SET last_migration = :migration_number, updated_at = CURRENT_TIMESTAMP 
            WHERE id = 1
        """),
        {'migration_number': migration_number}
    )
    
    # Also record in detailed migrations table
    db.session.execute(
        text("""
            INSERT INTO schema_migrations (migration_number, filename) 
            VALUES (:migration_number, :filename)
            ON CONFLICT (migration_number) DO NOTHING
        """),
        {
            'migration_number': migration_number,
            'filename': f"{migration_number:03d}_*.sql"
        }
    )

def get_migration_status():
    """Get current migration status information."""
    app = create_app()
    
    with app.app_context():
        try:
            create_migrations_table()
            
            last_migration = get_last_migration_number()
            
            # Get available migrations
            migrations_dir = Path(__file__).parent / 'migrations'
            migration_files = get_sorted_migration_files(str(migrations_dir))
            
            print(f"📊 Migration Status:")
            print(f"   Last applied: {last_migration}")
            print(f"   Available migrations: {len(migration_files)}")
            
            if migration_files:
                latest_available = migration_files[-1][1]
                print(f"   Latest available: {latest_available}")
                
                if last_migration < latest_available:
                    pending = latest_available - last_migration
                    print(f"   Pending migrations: {pending}")
                else:
                    print(f"   Status: ✅ Up to date")
            
            return True
            
        except Exception as e:
            print(f"❌ Failed to get migration status: {e}")
            return False

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='FocusPad Database Migration Runner')
    parser.add_argument('--status', action='store_true', help='Show migration status')
    
    args = parser.parse_args()
    
    if args.status:
        success = get_migration_status()
    else:
        success = run_migrations()
    
    sys.exit(0 if success else 1) 