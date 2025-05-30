-- Migration 001: Initial Schema
-- Created: 2025-05-30
-- Description: Creates the complete initial database schema for FocusPad

-- Create users table if it doesn't exist
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    google_id VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    picture TEXT,
    verified_email BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create templates table if it doesn't exist
CREATE TABLE IF NOT EXISTS templates (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    structure JSONB NOT NULL,
    categories TEXT NOT NULL DEFAULT '[]',
    is_default BOOLEAN DEFAULT FALSE,
    is_system BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create notes table if it doesn't exist
CREATE TABLE IF NOT EXISTS notes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    title VARCHAR(255),
    description TEXT,
    content TEXT,
    raw_content TEXT,
    attendees TEXT,
    template_id INTEGER REFERENCES templates(id),
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Encryption fields for title
    title_encrypted TEXT,
    title_salt VARCHAR(255),
    title_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encryption fields for content
    content_encrypted TEXT,
    content_salt VARCHAR(255),
    content_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encryption fields for raw_content
    raw_content_encrypted TEXT,
    raw_content_salt VARCHAR(255),
    raw_content_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encryption fields for attendees
    attendees_encrypted TEXT,
    attendees_salt VARCHAR(255),
    attendees_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encryption fields for description
    description_encrypted TEXT,
    description_salt VARCHAR(255),
    description_is_encrypted BOOLEAN DEFAULT FALSE
);

-- Create contents table if it doesn't exist
CREATE TABLE IF NOT EXISTS contents (
    id SERIAL PRIMARY KEY,
    note_id INTEGER REFERENCES notes(id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    text TEXT,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes(created_at);
CREATE INDEX IF NOT EXISTS idx_notes_template_id ON notes(template_id);
CREATE INDEX IF NOT EXISTS idx_notes_is_archived ON notes(is_archived);
CREATE INDEX IF NOT EXISTS idx_contents_note_id ON contents(note_id);
CREATE INDEX IF NOT EXISTS idx_contents_category ON contents(category);
CREATE INDEX IF NOT EXISTS idx_contents_order_index ON contents(order_index);
CREATE INDEX IF NOT EXISTS idx_templates_user_id ON templates(user_id);
CREATE INDEX IF NOT EXISTS idx_templates_is_default ON templates(is_default);
CREATE INDEX IF NOT EXISTS idx_templates_is_system ON templates(is_system);

-- Create default template
INSERT INTO templates (name, description, structure, categories, is_default, is_system, user_id, created_at, updated_at)
SELECT 
    'Default Template',
    'Basic note structure with common categories',
    '[
        {"name": "Key Points", "description": "Main points and takeaways"},
        {"name": "Action Items", "description": "Tasks and follow-ups"},
        {"name": "Decisions", "description": "Important decisions made"},
        {"name": "Notes", "description": "General notes and observations"}
    ]'::jsonb,
    '[
        {"name": "Key Points", "description": "Main points and takeaways"},
        {"name": "Action Items", "description": "Tasks and follow-ups"},
        {"name": "Decisions", "description": "Important decisions made"},
        {"name": "Notes", "description": "General notes and observations"}
    ]',
    true,
    true,
    null,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
WHERE NOT EXISTS (SELECT 1 FROM templates WHERE is_default = true); 