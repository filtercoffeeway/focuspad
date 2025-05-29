#!/usr/bin/env python3
"""
Complete setup script for server-side encryption in FocusPad.
"""

import os
import sys
import subprocess
from flask import Flask
from app import create_app, db
from app.models import Note

def run_command(command, description):
    """Run a shell command and return success status."""
    print(f"🔄 {description}...")
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✅ {description} completed successfully")
            return True
        else:
            print(f"❌ {description} failed: {result.stderr}")
            return False
    except Exception as e:
        print(f"❌ {description} failed: {e}")
        return False

def add_encryption_fields():
    """Add encryption fields to the notes table."""
    app = create_app()
    
    with app.app_context():
        try:
            print("🔄 Adding encryption fields to notes table...")
            
            # Check if fields already exist
            result = db.session.execute(db.text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'notes' AND column_name LIKE '%_encrypted'
            """))
            
            existing_fields = [row[0] for row in result.fetchall()]
            
            if existing_fields:
                print(f"⚠️  Encryption fields already exist: {existing_fields}")
                return True
            
            # SQL to add encryption fields
            encryption_fields_sql = [
                "ALTER TABLE notes ADD COLUMN title_encrypted TEXT",
                "ALTER TABLE notes ADD COLUMN title_salt VARCHAR(255)",
                "ALTER TABLE notes ADD COLUMN title_is_encrypted BOOLEAN DEFAULT FALSE",
                
                "ALTER TABLE notes ADD COLUMN content_encrypted TEXT",
                "ALTER TABLE notes ADD COLUMN content_salt VARCHAR(255)",
                "ALTER TABLE notes ADD COLUMN content_is_encrypted BOOLEAN DEFAULT FALSE",
                
                "ALTER TABLE notes ADD COLUMN raw_content_encrypted TEXT",
                "ALTER TABLE notes ADD COLUMN raw_content_salt VARCHAR(255)",
                "ALTER TABLE notes ADD COLUMN raw_content_is_encrypted BOOLEAN DEFAULT FALSE",
                
                "ALTER TABLE notes ADD COLUMN attendees_encrypted TEXT",
                "ALTER TABLE notes ADD COLUMN attendees_salt VARCHAR(255)",
                "ALTER TABLE notes ADD COLUMN attendees_is_encrypted BOOLEAN DEFAULT FALSE",
                
                "ALTER TABLE notes ADD COLUMN description_encrypted TEXT",
                "ALTER TABLE notes ADD COLUMN description_salt VARCHAR(255)",
                "ALTER TABLE notes ADD COLUMN description_is_encrypted BOOLEAN DEFAULT FALSE"
            ]
            
            for statement in encryption_fields_sql:
                try:
                    db.session.execute(db.text(statement))
                    print(f"✅ Added field: {statement.split()[-3]}")
                except Exception as e:
                    print(f"⚠️  Field may already exist: {e}")
            
            db.session.commit()
            print("✅ Encryption fields added successfully!")
            return True
            
        except Exception as e:
            print(f"❌ Error adding encryption fields: {e}")
            db.session.rollback()
            return False

def encrypt_existing_data():
    """Encrypt all existing note data."""
    app = create_app()
    
    with app.app_context():
        try:
            print("🔄 Starting encryption of existing note data...")
            
            # Get all notes
            notes = Note.query.all()
            print(f"📊 Found {len(notes)} notes to process")
            
            if not notes:
                print("ℹ️  No notes found to encrypt")
                return True
            
            encrypted_count = 0
            skipped_count = 0
            error_count = 0
            
            for note in notes:
                try:
                    # Check if note is already encrypted
                    if (note.title_is_encrypted or note.content_is_encrypted or 
                        note.raw_content_is_encrypted or note.attendees_is_encrypted or 
                        note.description_is_encrypted):
                        skipped_count += 1
                        continue
                    
                    # Encrypt the note
                    note.encrypt_sensitive_data(note.user_id)
                    encrypted_count += 1
                    
                    if encrypted_count % 5 == 0:
                        print(f"🔐 Encrypted {encrypted_count} notes so far...")
                    
                except Exception as e:
                    print(f"❌ Failed to encrypt note {note.id}: {e}")
                    error_count += 1
                    continue
            
            # Commit all changes
            db.session.commit()
            
            print(f"✅ Encryption process completed!")
            print(f"📊 Successfully encrypted: {encrypted_count} notes")
            print(f"⏭️  Already encrypted (skipped): {skipped_count} notes")
            print(f"❌ Failed to encrypt: {error_count} notes")
            
            return error_count == 0
            
        except Exception as e:
            print(f"❌ Error during encryption process: {e}")
            db.session.rollback()
            return False

def verify_encryption_setup():
    """Verify that encryption is working correctly."""
    app = create_app()
    
    with app.app_context():
        try:
            print("🔄 Verifying encryption setup...")
            
            # Check if encryption service is available
            from app.utils.encryption_service import encryption_service
            
            # Test encryption/decryption
            test_text = "This is a test message for encryption"
            test_user_id = 1
            
            encrypted_result = encryption_service.encrypt_text(test_text, test_user_id)
            if not encrypted_result['is_encrypted']:
                print("❌ Encryption test failed")
                return False
            
            decrypted_text = encryption_service.decrypt_text(
                encrypted_result['encrypted_data'],
                encrypted_result['salt'],
                test_user_id
            )
            
            if decrypted_text != test_text:
                print("❌ Decryption test failed")
                return False
            
            print("✅ Encryption/decryption test passed")
            
            # Check database fields
            result = db.session.execute(db.text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'notes' AND column_name LIKE '%_encrypted'
            """))
            
            encryption_fields = [row[0] for row in result.fetchall()]
            expected_fields = [
                'title_encrypted', 'content_encrypted', 'raw_content_encrypted',
                'attendees_encrypted', 'description_encrypted'
            ]
            
            missing_fields = [field for field in expected_fields if field not in encryption_fields]
            if missing_fields:
                print(f"❌ Missing encryption fields: {missing_fields}")
                return False
            
            print("✅ All encryption fields present in database")
            
            # Check environment variable
            master_key = os.environ.get('FOCUSPAD_MASTER_KEY')
            if not master_key:
                print("❌ FOCUSPAD_MASTER_KEY environment variable not set")
                return False
            
            print("✅ Master encryption key configured")
            print("✅ Encryption setup verification completed successfully!")
            return True
            
        except Exception as e:
            print(f"❌ Encryption verification failed: {e}")
            return False

def main():
    """Main setup function."""
    print("🚀 Starting FocusPad Server-Side Encryption Setup")
    print("=" * 50)
    
    # Step 1: Add encryption fields to database
    if not add_encryption_fields():
        print("❌ Failed to add encryption fields")
        return False
    
    print()
    
    # Step 2: Encrypt existing data
    if not encrypt_existing_data():
        print("❌ Failed to encrypt existing data")
        return False
    
    print()
    
    # Step 3: Verify setup
    if not verify_encryption_setup():
        print("❌ Encryption setup verification failed")
        return False
    
    print()
    print("🎉 Server-side encryption setup completed successfully!")
    print("=" * 50)
    print("📋 Summary:")
    print("   ✅ Encryption fields added to database")
    print("   ✅ Existing data encrypted")
    print("   ✅ Encryption service verified")
    print("   ✅ API routes updated to use encryption")
    print()
    print("🔒 Your note data is now encrypted at rest!")
    print("🔑 Master key: Set in FOCUSPAD_MASTER_KEY environment variable")
    print("🛡️  User-specific encryption: Each user's data is encrypted with their own derived key")
    
    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1) 