# 🗄️ Database Migration System

## Overview

FocusPad uses a unified migration system that works consistently across **local development** and **production** environments. This eliminates schema drift and ensures reliable deployments.

## 📁 Structure

```
db/
├── migrations/           # Sequential migration files
│   └── 001_initial_schema.sql
└── run_migrations.py     # Migration runner script
```

## 🔄 How It Works

### **Migration Tracking**
- Each migration has a sequential number (001, 002, 003...)
- The system tracks the last applied migration in `migration_state` table
- Only runs migrations newer than the last applied one
- Safe to run multiple times (idempotent)

### **Migration Files**
- Format: `{number}_{description}.sql`
- Example: `002_add_user_preferences.sql`
- Must be pure SQL (no psql-specific commands like `\c` or `\echo`)

## 🚀 Usage

### **Check Migration Status**
```bash
# In container
python3 /app/db/run_migrations.py --status

# From host
docker exec focuspad_web_local python3 /app/db/run_migrations.py --status
```

### **Run Migrations**
```bash
# In container
python3 /app/db/run_migrations.py

# From host
docker exec focuspad_web_local python3 /app/db/run_migrations.py
```

### **Automatic Migration**
Migrations run automatically when containers start:
- **Local**: `docker-compose up` runs migrations before starting Flask
- **Production**: `deploy.sh` runs migrations during deployment

## ➕ Adding New Fields/Tables

### **Step 1: Create Migration File**
```sql
-- db/migrations/002_add_user_preferences.sql
-- Migration 002: Add User Preferences
-- Created: 2025-05-30
-- Description: Add user preference settings

-- Add preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    theme VARCHAR(20) DEFAULT 'light',
    notifications_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add index
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);

-- Add new field to existing table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'timezone'
    ) THEN
        ALTER TABLE users ADD COLUMN timezone VARCHAR(50) DEFAULT 'UTC';
        CREATE INDEX IF NOT EXISTS idx_users_timezone ON users(timezone);
    END IF;
END $$;
```

### **Step 2: Update Models (if needed)**
```python
# app/models/user.py
class User(db.Model):
    # ... existing fields ...
    timezone = db.Column(db.String(50), default='UTC')
    
    # Relationship to preferences
    preferences = db.relationship('UserPreference', backref='user', lazy=True)

class UserPreference(db.Model):
    __tablename__ = 'user_preferences'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    theme = db.Column(db.String(20), default='light')
    notifications_enabled = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

### **Step 3: Test Migration**
```bash
# Run migration
docker exec focuspad_web_local python3 /app/db/run_migrations.py

# Verify it worked
docker exec focuspad_web_local python3 /app/db/run_migrations.py --status
```

## 🔧 Migration Best Practices

### **✅ DO:**
- Use sequential numbering (001, 002, 003...)
- Include descriptive comments
- Use `IF NOT EXISTS` for safety
- Test migrations on development first
- Use `DO $$ ... END $$` blocks for conditional logic
- Add indexes for new columns when appropriate

### **❌ DON'T:**
- Use psql-specific commands (`\c`, `\echo`, etc.)
- Skip migration numbers
- Modify existing migration files after they're applied
- Drop columns without careful consideration
- Forget to update models when adding new tables

## 🏗️ Migration File Template

```sql
-- Migration {NUMBER}: {DESCRIPTION}
-- Created: {DATE}
-- Description: {DETAILED_DESCRIPTION}

-- Add new table
CREATE TABLE IF NOT EXISTS new_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add new column to existing table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'existing_table' AND column_name = 'new_field'
    ) THEN
        ALTER TABLE existing_table ADD COLUMN new_field VARCHAR(100);
        CREATE INDEX IF NOT EXISTS idx_existing_table_new_field ON existing_table(new_field);
    END IF;
END $$;

-- Update existing data if needed
-- UPDATE existing_table SET new_field = 'default_value' WHERE new_field IS NULL;
```

## 🚨 Troubleshooting

### **Migration Failed**
1. Check logs: `docker logs focuspad_web_local`
2. Verify SQL syntax in migration file
3. Check database connectivity
4. Ensure no psql-specific commands

### **Reset Migration State** (Development Only)
```sql
-- Connect to database
docker exec -it focuspad_db_local psql -U focuspad_user -d focuspad

-- Reset to specific migration
UPDATE migration_state SET last_migration = 1 WHERE id = 1;

-- Or reset completely
UPDATE migration_state SET last_migration = 0 WHERE id = 1;
DELETE FROM schema_migrations;
```

### **Check Current State**
```sql
-- See migration state
SELECT * FROM migration_state;

-- See applied migrations
SELECT * FROM schema_migrations ORDER BY migration_number;
```

## 🌍 Environment Consistency

This system ensures:
- ✅ **Local** and **Production** use identical schema
- ✅ **No schema drift** between environments
- ✅ **Safe deployments** with automatic migrations
- ✅ **Rollback capability** by tracking migration state
- ✅ **Team collaboration** with sequential migration files

## 📋 Quick Commands

```bash
# Status check
docker exec focuspad_web_local python3 /app/db/run_migrations.py --status

# Run migrations
docker exec focuspad_web_local python3 /app/db/run_migrations.py

# Check database tables
docker exec focuspad_db_local psql -U focuspad_user -d focuspad -c "\\dt"

# See migration history
docker exec focuspad_db_local psql -U focuspad_user -d focuspad -c "SELECT * FROM schema_migrations;"
``` 