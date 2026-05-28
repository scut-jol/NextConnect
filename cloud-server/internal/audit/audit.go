package audit

import "database/sql"

type Logger struct {
	db *sql.DB
}

func NewLogger(db *sql.DB) *Logger {
	return &Logger{db: db}
}

func (l *Logger) Log(userID int, phone, action, targetNode, virtualIP string) error {
	_, err := l.db.Exec(
		`INSERT INTO nc_audit_logs (user_id, phone_number, action, target_node, virtual_ip) VALUES (?, ?, ?, ?, ?)`,
		userID, phone, action, targetNode, virtualIP,
	)
	return err
}