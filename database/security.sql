-- Database schema for audit logging and security
-- Add security audit trail to BioKey database

-- ==================== AUDIT LOG TABLE ====================
-- Track all sensitive operations for compliance

CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    actor_type VARCHAR(20) NOT NULL,  -- 'user' or 'admin'
    actor_id INT,
    target_type VARCHAR(50),          -- 'user', 'profile', 'evaluation'
    target_id INT,
    action VARCHAR(100) NOT NULL,     -- 'LOGIN', 'DELETE_USER', 'EXPORT_DATA'
    status VARCHAR(20) NOT NULL,      -- 'SUCCESS', 'FAILURE'
    details JSONB,                     -- Additional context
    ip_address INET,
    user_agent TEXT,
    request_id UUID,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_event_type ON audit_logs(event_type);
CREATE INDEX idx_audit_logs_status ON audit_logs(status);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);

-- ==================== FAILED LOGIN ATTEMPTS ====================
-- Track failed authentication attempts for security monitoring

CREATE TABLE IF NOT EXISTS failed_login_attempts (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50),
    ip_address INET NOT NULL,
    reason VARCHAR(100),              -- 'INVALID_PASSWORD', 'USER_NOT_FOUND', 'BIOMETRIC_MISMATCH'
    attempt_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_failed_logins_username ON failed_login_attempts(username);
CREATE INDEX idx_failed_logins_ip_address ON failed_login_attempts(ip_address);
CREATE INDEX idx_failed_logins_attempt_at ON failed_login_attempts(attempt_at DESC);

-- ==================== ADMIN ACTIONS ====================
-- Track privileged admin operations

CREATE TABLE IF NOT EXISTS admin_actions (
    id SERIAL PRIMARY KEY,
    admin_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id INT,
    changes JSONB,                     -- OLD -> NEW values for modifications
    reason TEXT,                       -- Why this action was taken
    status VARCHAR(20) DEFAULT 'COMPLETED',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX idx_admin_actions_created_at ON admin_actions(created_at DESC);
CREATE INDEX idx_admin_actions_resource ON admin_actions(resource_type, resource_id);

-- ==================== DATA ACCESS LOG ====================
-- Track when sensitive data is accessed/exported

CREATE TABLE IF NOT EXISTS data_access_logs (
    id SERIAL PRIMARY KEY,
    accessor_id INT REFERENCES users(id),
    data_type VARCHAR(50),            -- 'USER_PROFILE', 'TYPING_EVENTS', 'EVALUATION_DATA'
    record_count INT,
    export_format VARCHAR(20),        -- 'json', 'csv'
    export_reason TEXT,
    ip_address INET,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_data_access_logs_accessor ON data_access_logs(accessor_id);
CREATE INDEX idx_data_access_logs_created_at ON data_access_logs(created_at DESC);

-- ==================== ACTIVE SESSIONS ====================
-- Track authenticated sessions for token management

CREATE TABLE IF NOT EXISTS active_sessions (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    last_activity_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON active_sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON active_sessions(expires_at);
CREATE INDEX idx_sessions_token ON active_sessions(session_token);

-- ==================== CONSTRAINT: USER ROLES ====================
-- Add role-based access control

CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'user',  -- 'user', 'evaluator', 'admin'
    permissions JSONB DEFAULT '{}',
    granted_at TIMESTAMP DEFAULT NOW(),
    granted_by INT REFERENCES users(id)
);

CREATE INDEX idx_user_roles_role ON user_roles(role);

-- ==================== SECURITY CONSTRAINTS ====================

-- Enforce HTTPS in production (via app configuration, but documented here)
-- ALTER SYSTEM SET ssl = on;
-- ALTER SYSTEM SET ssl_cert_file = '/path/to/cert.pem';
-- ALTER SYSTEM SET ssl_key_file = '/path/to/key.pem';

-- Enable password encryption with pgcrypto if not already loaded
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==================== TRIGGERS FOR AUDIT LOGGING ====================

-- Trigger function to log deletions
CREATE OR REPLACE FUNCTION log_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (
        event_type, actor_type, target_type, target_id, action, status, details
    ) VALUES (
        'user_deletion', 'system', 'user', OLD.id, 'DELETE_USER', 'SUCCESS',
        jsonb_build_object('deleted_user', OLD.username, 'timestamp', NOW())
    );
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to log biometric profile updates
CREATE OR REPLACE FUNCTION log_profile_update()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (
        event_type, actor_type, target_type, target_id, action, status, details
    ) VALUES (
        'profile_update', 'system', 'profile', NEW.user_id, 'UPDATE_PROFILE', 'SUCCESS',
        jsonb_build_object(
            'user_id', NEW.user_id,
            'key_pair', NEW.key_pair,
            'sample_count', NEW.sample_count
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach triggers
CREATE TRIGGER trg_log_user_deletion
BEFORE DELETE ON users
FOR EACH ROW
EXECUTE FUNCTION log_user_deletion();

CREATE TRIGGER trg_log_profile_update
AFTER UPDATE ON biometric_profiles
FOR EACH ROW
EXECUTE FUNCTION log_profile_update();

-- ==================== VIEWS FOR SECURITY MONITORING ====================

-- Dashboard: Recent suspicious activity
CREATE OR REPLACE VIEW v_security_alerts AS
SELECT
    'Failed Logins' as alert_type,
    username as subject,
    COUNT(*) as count,
    MAX(attempt_at) as last_occurrence
FROM failed_login_attempts
WHERE attempt_at > NOW() - INTERVAL '24 hours'
GROUP BY username
HAVING COUNT(*) > 3  -- More than 3 failed attempts in 24h

UNION ALL

SELECT
    'Privilege Changes',
    u.username,
    COUNT(*) as count,
    MAX(aa.created_at) as last_occurrence
FROM admin_actions aa
JOIN users u ON aa.admin_id = u.id
WHERE aa.created_at > NOW() - INTERVAL '24 hours'
  AND aa.action IN ('GRANT_ROLE', 'REVOKE_ROLE', 'MODIFY_PERMISSIONS')
GROUP BY u.username;

-- ==================== COMPLIANCE VIEWS ====================

-- GDPR: Data access log for subject access requests
CREATE OR REPLACE VIEW v_user_data_access AS
SELECT
    u.id,
    u.username,
    dal.data_type,
    dal.export_format,
    dal.record_count,
    dal.created_at,
    u2.username as exported_by
FROM data_access_logs dal
JOIN users u ON dal.accessor_id = u.id OR u.id = dal.accessor_id
LEFT JOIN users u2 ON dal.accessor_id = u2.id;

-- ==================== PRIVILEGE CONSTRAINTS ====================
-- Ensure only admins can access sensitive tables directly

-- Would require GRANT/REVOKE at application level
-- GRANT SELECT ON audit_logs TO admin_role;
-- GRANT SELECT ON admin_actions TO admin_role;
-- REVOKE ALL ON audit_logs FROM public;

-- ==================== ENCRYPTION AT REST ====================
-- For sensitive fields, use pgcrypto

-- Example: Encrypt password hashes (additional security layer)
-- UPDATE users SET password_hash = crypt(password_hash, gen_salt('bf'));

-- ==================== DATA RETENTION POLICIES ====================
-- Automatic cleanup of old audit logs (example: remove after 1 year)

-- SELECT pg_catalog.set_config('session_replication_role', 'replica', false);
-- DELETE FROM audit_logs WHERE created_at < NOW() - INTERVAL '1 year';
-- DELETE FROM failed_login_attempts WHERE attempt_at < NOW() - INTERVAL '90 days';
-- DELETE FROM data_access_logs WHERE created_at < NOW() - INTERVAL '1 year';
-- SELECT pg_catalog.set_config('session_replication_role', 'default', false);

