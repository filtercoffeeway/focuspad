-- Common SQL Queries for FocusPad Application
-- Connect to database: docker exec -it focuspad_db psql -U focuspad_user -d focuspad

-- ============================================================================
-- USER MANAGEMENT QUERIES
-- ============================================================================

-- View all users with details
SELECT 
    id,
    name,
    email,
    google_id,
    verified_email,
    picture,
    created_at,
    updated_at
FROM users 
ORDER BY created_at DESC;

-- Count total users
SELECT COUNT(*) as total_users FROM users;

-- Find user by email
SELECT * FROM users WHERE email = 'user@example.com';

-- Find user by Google ID
SELECT * FROM users WHERE google_id = 'google_user_id_here';

-- Users registered in the last 24 hours
SELECT * FROM users 
WHERE created_at >= NOW() - INTERVAL '1 day'
ORDER BY created_at DESC;

-- Users registered this week
SELECT * FROM users 
WHERE created_at >= DATE_TRUNC('week', NOW())
ORDER BY created_at DESC;

-- Users by email domain
SELECT 
    SUBSTRING(email FROM '@(.*)$') as domain,
    COUNT(*) as user_count
FROM users 
GROUP BY domain 
ORDER BY user_count DESC;

-- ============================================================================
-- DATA ANALYSIS QUERIES
-- ============================================================================

-- User registration trends by day (last 30 days)
SELECT 
    DATE(created_at) as registration_date,
    COUNT(*) as new_users
FROM users 
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY registration_date DESC;

-- User registration trends by month
SELECT 
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as new_users
FROM users 
GROUP BY month 
ORDER BY month DESC;

-- Verified vs unverified email distribution
SELECT 
    verified_email,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM users 
GROUP BY verified_email;

-- Average time between user updates
SELECT 
    AVG(updated_at - created_at) as avg_update_time
FROM users 
WHERE updated_at != created_at;

-- ============================================================================
-- DATABASE MAINTENANCE QUERIES
-- ============================================================================

-- Check table sizes
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats 
WHERE schemaname = 'public';

-- View table information
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
ORDER BY table_name, ordinal_position;

-- Check database size
SELECT pg_size_pretty(pg_database_size('focuspad')) as database_size;

-- Check table sizes
SELECT 
    table_name,
    pg_size_pretty(pg_total_relation_size(quote_ident(table_name))) as size
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY pg_total_relation_size(quote_ident(table_name)) DESC;

-- View active connections
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    backend_start,
    state
FROM pg_stat_activity 
WHERE datname = 'focuspad';

-- ============================================================================
-- SECURITY AND AUDIT QUERIES
-- ============================================================================

-- Users with duplicate emails (should be none due to unique constraint)
SELECT email, COUNT(*) 
FROM users 
GROUP BY email 
HAVING COUNT(*) > 1;

-- Users with missing required fields
SELECT * FROM users 
WHERE name IS NULL OR email IS NULL OR google_id IS NULL;

-- Recently updated user profiles
SELECT 
    name,
    email,
    created_at,
    updated_at,
    (updated_at - created_at) as time_since_creation
FROM users 
WHERE updated_at > created_at
ORDER BY updated_at DESC;

-- ============================================================================
-- PERFORMANCE QUERIES
-- ============================================================================

-- Index usage statistics
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public';

-- Table scan statistics
SELECT 
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_tup_ins,
    n_tup_upd,
    n_tup_del
FROM pg_stat_user_tables
WHERE schemaname = 'public';

-- ============================================================================
-- SAMPLE DATA INSERTION (FOR TESTING)
-- ============================================================================

-- Insert sample user (replace with actual Google OAuth data)
-- Note: This should normally be done through the application
/*
INSERT INTO users (google_id, email, name, verified_email, picture, created_at, updated_at)
VALUES (
    'sample_google_id_123',
    'test@example.com',
    'Test User',
    true,
    'https://example.com/avatar.jpg',
    NOW(),
    NOW()
);
*/

-- ============================================================================
-- CLEANUP QUERIES (USE WITH CAUTION)
-- ============================================================================

-- Delete user by email (use with caution)
-- DELETE FROM users WHERE email = 'user@example.com';

-- Delete users older than 1 year (use with caution)
-- DELETE FROM users WHERE created_at < NOW() - INTERVAL '1 year';

-- Reset auto-increment counter
-- SELECT setval('users_id_seq', (SELECT MAX(id) FROM users));

-- ============================================================================
-- BACKUP COMMANDS (run from terminal, not in psql)
-- ============================================================================

/*
# Full database backup
docker exec focuspad_db pg_dump -U focuspad_user focuspad > focuspad_backup.sql

# Users table only backup
docker exec focuspad_db pg_dump -U focuspad_user -t users focuspad > users_backup.sql

# Restore from backup
docker exec -i focuspad_db psql -U focuspad_user -d focuspad < focuspad_backup.sql
*/ 