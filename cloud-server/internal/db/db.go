package db

import (
	"database/sql"
	"fmt"

	_ "github.com/mattn/go-sqlite3"
)

type Database struct {
	*sql.DB
}

func Init(dbPath string) (*Database, error) {
	db, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_foreign_keys=on")
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	d := &Database{db}
	if err := d.migrate(); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return d, nil
}

func (d *Database) migrate() error {
	schema := `
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
		status VARCHAR(20) DEFAULT 'pending',
		expires_at TIMESTAMP NOT NULL
	);

	CREATE TABLE IF NOT EXISTS nc_audit_logs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL,
		phone_number VARCHAR(11),
		action VARCHAR(64) NOT NULL,
		target_node VARCHAR(255),
		virtual_ip VARCHAR(45),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	`
	_, err := d.Exec(schema)
	return err
}