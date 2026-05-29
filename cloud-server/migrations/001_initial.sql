-- NextConnect Cloud Server: Initial Schema
-- Database: SQLite3

CREATE TABLE IF NOT EXISTS nc_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone_number VARCHAR(11) UNIQUE NOT NULL,
    wechat_open_id VARCHAR(64) UNIQUE,
    nc_namespace VARCHAR(64) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS nc_pairing_tokens (
    token VARCHAR(64) PRIMARY KEY,
    machine_key VARCHAR(255) NOT NULL,
    node_key VARCHAR(255) NOT NULL DEFAULT '',
    namespace VARCHAR(64) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK(status IN ('pending','approved','expired')),
    expires_at TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS nc_audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    phone_number VARCHAR(11),
    action VARCHAR(64) NOT NULL,
    target_node VARCHAR(255),
    virtual_ip VARCHAR(45),
    namespace VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pairing_tokens_status ON nc_pairing_tokens(status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON nc_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON nc_audit_logs(created_at);

-- Phase 4 compliance: audit events for full traceability
-- Actions recorded: login, pair/register, pair/confirm, pair/poll, pair/poll:expired
-- All times in UTC, indexed by user_id for fast compliance queries