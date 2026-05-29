package db

import (
	"database/sql"
	"errors"
	"fmt"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

type Database struct {
	*sql.DB
}

type User struct {
	ID          int64     `json:"id"`
	PhoneNumber string    `json:"phone_number"`
	WechatOpen  string    `json:"wechat_open_id,omitempty"`
	Namespace   string    `json:"nc_namespace"`
	CreatedAt   time.Time `json:"created_at"`
}

func (d *Database) CreateUser(phone, namespace string) (*User, error) {
	res, err := d.Exec(
		`INSERT INTO nc_users (phone_number, nc_namespace) VALUES (?, ?)`,
		phone, namespace,
	)
	if err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}
	id, err := res.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("get last insert id: %w", err)
	}
	return d.GetUserByID(id)
}

func (d *Database) GetUserByID(id int64) (*User, error) {
	row := d.QueryRow(`SELECT id, phone_number, COALESCE(wechat_open_id,''), nc_namespace, created_at FROM nc_users WHERE id = ?`, id)
	u := &User{}
	if err := row.Scan(&u.ID, &u.PhoneNumber, &u.WechatOpen, &u.Namespace, &u.CreatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("user not found: %w", err)
		}
		return nil, fmt.Errorf("get user by id: %w", err)
	}
	return u, nil
}

func (d *Database) GetUserByPhone(phone string) (*User, error) {
	row := d.QueryRow(`SELECT id, phone_number, COALESCE(wechat_open_id,''), nc_namespace, created_at FROM nc_users WHERE phone_number = ?`, phone)
	u := &User{}
	if err := row.Scan(&u.ID, &u.PhoneNumber, &u.WechatOpen, &u.Namespace, &u.CreatedAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("user not found: %w", err)
		}
		return nil, fmt.Errorf("get user by phone: %w", err)
	}
	return u, nil
}

type PairingToken struct {
	Token     string    `json:"token"`
	MachineKey string   `json:"machine_key"`
	NodeKey   string    `json:"node_key"`
	Namespace string    `json:"namespace"`
	Status    string    `json:"status"`
	ExpiresAt time.Time `json:"expires_at"`
}

func (d *Database) CreatePairingToken(token, machineKey, nodeKey, namespace string, expiresAt time.Time) error {
	_, err := d.Exec(
		`INSERT INTO nc_pairing_tokens (token, machine_key, node_key, namespace, status, expires_at) VALUES (?, ?, ?, ?, 'pending', ?)`,
		token, machineKey, nodeKey, namespace, expiresAt,
	)
	if err != nil {
		return fmt.Errorf("create pairing token: %w", err)
	}
	return nil
}

func (d *Database) GetPairingToken(token string) (*PairingToken, error) {
	row := d.QueryRow(`SELECT token, machine_key, node_key, namespace, status, expires_at FROM nc_pairing_tokens WHERE token = ?`, token)
	pt := &PairingToken{}
	if err := row.Scan(&pt.Token, &pt.MachineKey, &pt.NodeKey, &pt.Namespace, &pt.Status, &pt.ExpiresAt); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("token not found: %w", err)
		}
		return nil, fmt.Errorf("get pairing token: %w", err)
	}
	return pt, nil
}

func (d *Database) ApprovePairingToken(token string) error {
	res, err := d.Exec(`UPDATE nc_pairing_tokens SET status = 'approved' WHERE token = ? AND status = 'pending'`, token)
	if err != nil {
		return fmt.Errorf("approve pairing token: %w", err)
	}
	n, err := res.RowsAffected()
	if err != nil {
		return fmt.Errorf("get rows affected: %w", err)
	}
	if n == 0 {
		return fmt.Errorf("no pending token found: %s", token)
	}
	return nil
}

func Init(dbPath string) (*Database, error) {
	database, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_foreign_keys=on")
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	if err := database.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	d := &Database{database}
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