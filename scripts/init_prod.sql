-- Production Database Initialization Script
-- This script runs when the PostgreSQL container starts for the first time
-- It sets up basic database configurations and permissions

-- Ensure database exists (should already be created by POSTGRES_DB env var)
-- CREATE DATABASE IF NOT EXISTS focuspad;

-- Set up basic configurations for production
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET track_activity_query_size = 2048;
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_duration = on;
ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';

-- Optimize for production workload
ALTER SYSTEM SET effective_cache_size = '512MB';
ALTER SYSTEM SET maintenance_work_mem = '32MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '4MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- Connection and security settings
ALTER SYSTEM SET max_connections = 100;
ALTER SYSTEM SET password_encryption = 'scram-sha-256';

-- Reload configuration
SELECT pg_reload_conf();

-- Create extensions if they don't exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Grant necessary permissions to focuspad_user
-- (User should already be created by POSTGRES_USER env var)
GRANT ALL PRIVILEGES ON DATABASE focuspad TO focuspad_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO focuspad_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO focuspad_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO focuspad_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO focuspad_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO focuspad_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO focuspad_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO focuspad_user;

-- Create a simple health check function
CREATE OR REPLACE FUNCTION public.health_check()
RETURNS TEXT AS $$
BEGIN
    RETURN 'Database is healthy - ' || NOW()::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Log successful initialization
DO $$
BEGIN
    RAISE NOTICE 'FocusPad production database initialization completed successfully';
END $$; 