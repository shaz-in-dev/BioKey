-- BioKey Production Database Optimization
-- Run after initial schema creation

-- ==================== INDEXES ====================
-- Performance-critical queries need indexes

-- Auth queries
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Biometric profile lookups (most common operation)
CREATE INDEX IF NOT EXISTS idx_biometric_profiles_user_id ON biometric_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_biometric_profiles_user_key ON biometric_profiles(user_id, key_pair);

-- Access logs for reporting
CREATE INDEX IF NOT EXISTS idx_access_logs_user_id ON access_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_access_logs_attempted_at ON access_logs(attempted_at);
CREATE INDEX IF NOT EXISTS idx_access_logs_verdict ON access_logs(verdict);
CREATE INDEX IF NOT EXISTS idx_access_logs_user_time ON access_logs(user_id, attempted_at DESC);

-- Score history for analytics
CREATE INDEX IF NOT EXISTS idx_user_score_history_user_id ON user_score_history(user_id);
CREATE INDEX IF NOT EXISTS idx_user_score_history_created_at ON user_score_history(created_at);
CREATE INDEX IF NOT EXISTS idx_user_score_history_outcome ON user_score_history(outcome);

-- Threshold lookups
CREATE INDEX IF NOT EXISTS idx_user_score_thresholds_user_id ON user_score_thresholds(user_id);

-- ==================== PARTITIONING ====================
-- For large tables at scale, consider range partitioning

-- Example: Partition access_logs by month
-- ALTER TABLE access_logs
--   PARTITION BY RANGE (EXTRACT(YEAR FROM attempted_at), EXTRACT(MONTH FROM attempted_at));

-- ==================== MATERIALIZED VIEWS ====================
-- Pre-computed aggregates for dashboard queries

CREATE MATERIALIZED VIEW IF NOT EXISTS v_user_stats AS
  SELECT
    u.id,
    u.username,
    COUNT(al.id) as total_attempts,
    SUM(CASE WHEN al.verdict = 'SUCCESS' THEN 1 ELSE 0 END) as successful_attempts,
    SUM(CASE WHEN al.verdict = 'FAILURE' THEN 1 ELSE 0 END) as failed_attempts,
    CASE 
      WHEN COUNT(al.id) > 0 
      THEN ROUND(100.0 * SUM(CASE WHEN al.verdict = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(al.id), 2)
      ELSE 0
    END as success_rate_percent,
    MAX(al.attempted_at) as last_attempt_at,
    COUNT(bp.key_pair) as trained_key_pairs
  FROM users u
  LEFT JOIN access_logs al ON u.id = al.user_id
  LEFT JOIN biometric_profiles bp ON u.id = bp.user_id
  GROUP BY u.id, u.username;

CREATE INDEX idx_v_user_stats_id ON v_user_stats(id);

-- Refresh stats periodically
-- REFRESH MATERIALIZED VIEW CONCURRENTLY v_user_stats;

-- ==================== QUERY OPTIMIZATION ====================
-- Common query patterns to verify use indexes

-- EXPLAIN ANALYZE should show Index Scans (not Seq Scans)

-- 1. User lookup by username
-- SELECT * FROM users WHERE username = 'john_doe';  -- Uses idx_users_username

-- 2. Get user's biometric profile
-- SELECT * FROM biometric_profiles WHERE user_id = 1;  -- Uses idx_biometric_profiles_user_id

-- 3. Recent activity for user
-- SELECT * FROM access_logs 
-- WHERE user_id = 1 
-- ORDER BY attempted_at DESC 
-- LIMIT 20;  -- Uses idx_access_logs_user_time

-- ==================== STATISTICS & AUTOVACUUM ====================
-- Ensure PostgreSQL has up-to-date statistics

-- Manual analyze (run after large data loads)
ANALYZE users;
ANALYZE biometric_profiles;
ANALYZE access_logs;
ANALYZE user_score_history;

-- Configure autovacuum for optimal performance
-- ALTER TABLE access_logs SET (
--   autovacuum_vacuum_scale_factor = 0.01,
--   autovacuum_analyze_scale_factor = 0.005
-- );

-- ==================== CONNECTION POOLING ====================
-- PgBouncer configuration recommendations

-- /etc/pgbouncer/pgbouncer.ini
-- [databases]
-- biokey_db = host=localhost port=5432 dbname=biokey_db user=biokey password=***

-- [pgbouncer]
-- pool_mode = transaction
-- max_client_conn = 100
-- default_pool_size = 10
-- reserve_pool_size = 5
-- reserve_pool_timeout = 3
-- max_db_connections = 50
-- max_user_connections = 50

-- ==================== MONITORING QUERIES ====================

-- 1. Check index usage
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan as index_scans,
  idx_tup_read as tuples_read,
  idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- 2. Find missing indexes
SELECT
  schemaname,
  tablename,
  attname,
  n_distinct,
  correlation
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY abs(correlation) DESC;

-- 3. Slow query log configuration (add to postgresql.conf)
-- log_min_duration_statement = 1000  # Log queries > 1 second
-- log_line_prefix = '[%t] [%p] [%u@%d] '

-- 4. Cache hit ratio (should be > 99%)
SELECT
  sum(heap_blks_read) as heap_read,
  sum(heap_blks_hit) as heap_hit,
  sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) as ratio
FROM pg_statio_user_tables;

-- 5. Active connections
SELECT
  pid,
  usename,
  application_name,
  state,
  query,
  query_start
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- 6. Table size analysis
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- ==================== BACKUP STRATEGY ====================

-- Base backup (full)
-- pg_basebackup -D /path/to/backup -Ft -z -P

-- Incremental backups using WAL archiving
-- wal_level = replica
-- max_wal_senders = 3
-- wal_keep_size = 1GB
-- archive_mode = on
-- archive_command = 'cp %p /path/to/wal_archive/%f'

-- ==================== AVAILABILITY & REPLICATION ====================

-- For HA setup, configure replication:
-- Primary writes to primary_conninfo
-- Standby connects to primary_conninfo
-- Automatic failover via 3rd party tools (Patroni, pg_auto_failover)

