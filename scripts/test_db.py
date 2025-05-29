#!/usr/bin/env python3
"""
Test script to connect to PostgreSQL and run sample queries.
"""

import psycopg2
import os
from datetime import datetime

def connect_to_db():
    """Connect to PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            host='localhost',  # or 'db' if running inside Docker
            database='focuspad',
            user='focuspad_user',
            password='focuspad_password',
            port=5432
        )
        return conn
    except Exception as e:
        print(f"Error connecting to database: {e}")
        return None

def run_sample_queries():
    """Run sample SQL queries."""
    conn = connect_to_db()
    if not conn:
        return
    
    try:
        cursor = conn.cursor()
        
        print("🔗 Connected to PostgreSQL database!")
        print("=" * 50)
        
        # Check if users table exists
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_name = 'users'
            );
        """)
        table_exists = cursor.fetchone()[0]
        
        if table_exists:
            print("✅ Users table exists")
            
            # Count users
            cursor.execute("SELECT COUNT(*) FROM users;")
            user_count = cursor.fetchone()[0]
            print(f"👥 Total users: {user_count}")
            
            if user_count > 0:
                # Show recent users
                cursor.execute("""
                    SELECT id, name, email, created_at 
                    FROM users 
                    ORDER BY created_at DESC 
                    LIMIT 5;
                """)
                users = cursor.fetchall()
                
                print("\n📋 Recent users:")
                print("-" * 50)
                for user in users:
                    print(f"ID: {user[0]}, Name: {user[1]}, Email: {user[2]}, Created: {user[3]}")
            else:
                print("📝 No users found. Try logging in via the web interface first.")
        else:
            print("⚠️  Users table doesn't exist yet. Start the Flask app to create tables.")
        
        # Show database info
        cursor.execute("SELECT version();")
        db_version = cursor.fetchone()[0]
        print(f"\n🗄️  Database version: {db_version}")
        
        cursor.execute("SELECT current_database();")
        db_name = cursor.fetchone()[0]
        print(f"📊 Current database: {db_name}")
        
        cursor.execute("SELECT current_user;")
        db_user = cursor.fetchone()[0]
        print(f"👤 Current user: {db_user}")
        
    except Exception as e:
        print(f"❌ Error running queries: {e}")
    
    finally:
        cursor.close()
        conn.close()
        print("\n🔌 Database connection closed.")

if __name__ == "__main__":
    print("🎯 FocusPad Database Test")
    print("=" * 30)
    run_sample_queries() 