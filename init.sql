-- Initialize FocusPad Database
-- This file is automatically run when the PostgreSQL container starts

-- Create database (already created by environment variables)
-- CREATE DATABASE focuspad;

-- Create user (already created by environment variables)
-- CREATE USER focuspad_user WITH PASSWORD 'focuspad_password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE focuspad TO focuspad_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO focuspad_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO focuspad_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO focuspad_user;

-- Set timezone
SET timezone = 'UTC';

-- Log initialization
SELECT 'FocusPad database initialized successfully!' as status; 