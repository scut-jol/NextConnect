package api

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/scut-jol/NextConnect/cloud-server/internal/db"
)

const tokenExpiry = 10 * time.Minute

// ---- Helpers ----

func generateNamespace() string {
	short := uuid.New().String()[:8]
	return "nc_" + short
}

// human-friendly pairing token like "NC-A3X9K2" (no 0/O/1/I)
func generatePairingToken() (string, error) {
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	code := make([]byte, 6)
	for i := range code {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", fmt.Errorf("rand: %w", err)
		}
		code[i] = charset[n.Int64()]
	}
	return "NC-" + string(code), nil
}

// ---- Handlers ----

func LoginHandler(database *db.Database, jwtSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "phone_number is required"})
			return
		}

		user, err := database.GetUserByPhone(req.PhoneNumber)
		if err != nil {
			// New user — auto-create
			namespace := generateNamespace()
			user, err = database.CreateUser(req.PhoneNumber, namespace)
			if err != nil {
				c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "failed to create user"})
				return
			}
		}

		now := time.Now()
		claims := &Claims{
			UserID:    user.ID,
			Phone:     user.PhoneNumber,
			Namespace: user.Namespace,
			RegisteredClaims: jwt.RegisteredClaims{
				ExpiresAt: jwt.NewNumericDate(now.Add(24 * time.Hour)),
				IssuedAt:  jwt.NewNumericDate(now),
				Issuer:    "nextconnect",
			},
		}
		token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
		signed, err := token.SignedString([]byte(jwtSecret))
		if err != nil {
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "failed to sign token"})
			return
		}

		c.JSON(http.StatusOK, LoginResponse{
			Token:     signed,
			Namespace: user.Namespace,
			UserID:    user.ID,
		})
	}
}

func RegisterHandler(database *db.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req RegisterRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "machine_key and node_key are required"})
			return
		}

		pairToken, err := generatePairingToken()
		if err != nil {
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "failed to generate token"})
			return
		}

		err = database.CreatePairingToken(
			pairToken,
			req.MachineKey,
			req.NodeKey,
			"unassigned",
			time.Now().Add(tokenExpiry),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "failed to store pairing token"})
			return
		}

		c.JSON(http.StatusOK, RegisterResponse{
			PairingToken: pairToken,
			PollURL:      fmt.Sprintf("/api/v1/pair/poll?token=%s", pairToken),
		})
	}
}

func ConfirmHandler(database *db.Database, alog *auditLogger) gin.HandlerFunc {
	return func(c *gin.Context) {
		namespace, _ := c.Get("namespace")

		var req ConfirmRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "pairing_token is required"})
			return
		}

		pt, err := database.GetPairingToken(req.PairingToken)
		if err != nil {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "pairing token not found"})
			return
		}

		if pt.Status != "pending" {
			c.JSON(http.StatusConflict, ErrorResponse{Error: fmt.Sprintf("token already %s", pt.Status)})
			return
		}

		if time.Now().After(pt.ExpiresAt) {
			c.JSON(http.StatusGone, ErrorResponse{Error: "token expired"})
			return
		}

		if err := database.ApprovePairingToken(req.PairingToken); err != nil {
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "failed to approve token"})
			return
		}

		alog.log(c, "pair/confirm", pt.MachineKey, "")

		c.JSON(http.StatusOK, gin.H{
			"status":    "approved",
			"namespace": namespace,
		})
	}
}

func PollHandler(database *db.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.Query("token")
		if token == "" {
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "token query param is required"})
			return
		}

		pt, err := database.GetPairingToken(token)
		if err != nil {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "pairing token not found"})
			return
		}

		if time.Now().After(pt.ExpiresAt) && pt.Status == "pending" {
			c.JSON(http.StatusOK, PollResponse{Status: "expired"})
			return
		}

		c.JSON(http.StatusOK, PollResponse{
			Status:    pt.Status,
			Namespace: pt.Namespace,
		})
	}
}