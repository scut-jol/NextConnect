package audit

import (
	"database/sql"
	"fmt"
	"time"
)

// Logger writes structured audit events to SQLite for compliance tracing.
//
// Under Chinese cyber-security law (网络安全法), the platform must be able to
// produce a chronological record of all user actions. This log enables
// the platform to demonstrate "pipe is clean, user is accountable" in the
// event of an investigation.
//
// The log records metadata only (who, what, when, target) — NEVER user
// keystroke content or session data.
type Logger struct {
	db *sql.DB
}

func NewLogger(db *sql.DB) *Logger {
	return &Logger{db: db}
}

// Log writes an audit event. Fields:
//
//   - userID: internal user ID
//   - phone: masked phone number for identification
//   - action: e.g. "login", "pair/register", "pair/confirm", "pair/poll"
//   - target: machine_key or node UUID the action relates to
//   - virtualIP: Tailscale-assigned IP (100.x.x.x) if known
//   - namespace: user's Headscale namespace
func (l *Logger) Log(userID int, phone, action, target, virtualIP, namespace string) error {
	_, err := l.db.Exec(
		`INSERT INTO nc_audit_logs (user_id, phone_number, action, target_node, virtual_ip, namespace) VALUES (?, ?, ?, ?, ?, ?)`,
		userID, phone, action, target, virtualIP, namespace,
	)
	if err != nil {
		return fmt.Errorf("audit log: %w", err)
	}
	return nil
}

// AuditEvent represents a single row from nc_audit_logs.
type AuditEvent struct {
	ID        int       `json:"id"`
	UserID    int       `json:"user_id"`
	Phone     string    `json:"phone_number,omitempty"`
	Action    string    `json:"action"`
	Target    string    `json:"target_node,omitempty"`
	VirtualIP string    `json:"virtual_ip,omitempty"`
	Namespace string    `json:"namespace,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// QueryByUser returns all audit events for a given user, ordered by time descending.
func (l *Logger) QueryByUser(userID int, limit int) ([]AuditEvent, error) {
	if limit <= 0 || limit > 100 {
		limit = 100
	}
	rows, err := l.db.Query(
		`SELECT id, user_id, COALESCE(phone_number,''), action, COALESCE(target_node,''), COALESCE(virtual_ip,''), COALESCE(namespace,''), created_at
		 FROM nc_audit_logs WHERE user_id = ? ORDER BY created_at DESC LIMIT ?`,
		userID, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("query audit by user: %w", err)
	}
	defer rows.Close()

	var events []AuditEvent
	for rows.Next() {
		var e AuditEvent
		if err := rows.Scan(&e.ID, &e.UserID, &e.Phone, &e.Action, &e.Target, &e.VirtualIP, &e.Namespace, &e.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan audit row: %w", err)
		}
		events = append(events, e)
	}
	return events, rows.Err()
}