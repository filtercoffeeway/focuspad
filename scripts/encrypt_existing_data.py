#!/usr/bin/env python3
"""
Encrypt existing note data in the database.
"""

import os
import sys
from flask import Flask
from app import create_app, db
from app.models import Note

def encrypt_existing_data():
    """Encrypt all existing note data."""
    app = create_app()
    
    with app.app_context():
        try:
            print("🔄 Starting encryption of existing note data...")
            
            # Get all notes
            notes = Note.query.all()
            print(f"📊 Found {len(notes)} notes to encrypt")
            
            encrypted_count = 0
            error_count = 0
            
            for note in notes:
                try:
                    # Check if note is already encrypted
                    if (note.title_is_encrypted or note.content_is_encrypted or 
                        note.raw_content_is_encrypted or note.attendees_is_encrypted or 
                        note.description_is_encrypted):
                        print(f"⏭️  Note {note.id} already encrypted, skipping...")
                        continue
                    
                    # Encrypt the note
                    note.encrypt_sensitive_data(note.user_id)
                    encrypted_count += 1
                    
                    if encrypted_count % 10 == 0:
                        print(f"🔐 Encrypted {encrypted_count} notes so far...")
                    
                except Exception as e:
                    print(f"❌ Failed to encrypt note {note.id}: {e}")
                    error_count += 1
                    continue
            
            # Commit all changes
            db.session.commit()
            
            print(f"✅ Encryption completed!")
            print(f"📊 Successfully encrypted: {encrypted_count} notes")
            print(f"❌ Failed to encrypt: {error_count} notes")
            
            return error_count == 0
            
        except Exception as e:
            print(f"❌ Error during encryption process: {e}")
            db.session.rollback()
            return False

if __name__ == '__main__':
    success = encrypt_existing_data()
    sys.exit(0 if success else 1) 