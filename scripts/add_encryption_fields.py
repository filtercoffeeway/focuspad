#!/usr/bin/env python3
"""
Add encryption fields to the notes table.
"""

import os
import sys
from flask import Flask
from app import create_app, db

def add_encryption_fields():
    """Add encryption fields to the notes table."""
    app = create_app()
    
    with app.app_context():
        try:
            # SQL to add encryption fields
            encryption_fields_sql = """
            -- Add encryption fields for title
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS title_encrypted TEXT;
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS title_salt VARCHAR(255);
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS title_is_encrypted BOOLEAN DEFAULT FALSE;
            
            -- Add encryption fields for content
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS content_encrypted TEXT;
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS content_salt VARCHAR(255);
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS content_is_encrypted BOOLEAN DEFAULT FALSE;
            
            -- Add encryption fields for raw_content
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS raw_content_encrypted TEXT;
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS raw_content_salt VARCHAR(255);
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS raw_content_is_encrypted BOOLEAN DEFAULT FALSE;
            
            -- Add encryption fields for attendees
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS attendees_encrypted TEXT;
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS attendees_salt VARCHAR(255);
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS attendees_is_encrypted BOOLEAN DEFAULT FALSE;
            
            -- Add encryption fields for description
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS description_encrypted TEXT;
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS description_salt VARCHAR(255);
            ALTER TABLE notes ADD COLUMN IF NOT EXISTS description_is_encrypted BOOLEAN DEFAULT FALSE;
            """
            
            print("🔄 Adding encryption fields to notes table...")
            
            # Execute each statement separately
            statements = [stmt.strip() for stmt in encryption_fields_sql.split(';') if stmt.strip()]
            
            for statement in statements:
                if statement:
                    try:
                        db.session.execute(db.text(statement))
                        print(f"✅ Executed: {statement[:50]}...")
                    except Exception as e:
                        print(f"⚠️  Statement may already exist or failed: {e}")
            
            db.session.commit()
            print("✅ Encryption fields added successfully!")
            
        except Exception as e:
            print(f"❌ Error adding encryption fields: {e}")
            db.session.rollback()
            return False
    
    return True

if __name__ == '__main__':
    success = add_encryption_fields()
    sys.exit(0 if success else 1) 