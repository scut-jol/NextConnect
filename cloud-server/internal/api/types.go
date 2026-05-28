package api

// --- Request Types ---

type LoginRequest struct {
	PhoneNumber string `json:"phone_number" binding:"required"`
	// In production, also send verification_code or wechat_open_id
}

type RegisterRequest struct {
	MachineKey string `json:"machine_key" binding:"required"`
	NodeKey    string `json:"node_key" binding:"required"`
}

type ConfirmRequest struct {
	PairingToken string `json:"pairing_token" binding:"required"`
}

// --- Response Types ---

type LoginResponse struct {
	Token     string `json:"token"`
	Namespace string `json:"namespace"`
	UserID    int64  `json:"user_id"`
}

type RegisterResponse struct {
	PairingToken string `json:"pairing_token"`
	PollURL      string `json:"poll_url"`
}

type PollResponse struct {
	Status    string `json:"status"`
	Namespace string `json:"namespace,omitempty"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}