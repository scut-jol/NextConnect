package api

import (
	"crypto/rand"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/scut-jol/NextConnect/cloud-server/internal/db"
)

const tokenExpiry = 10 * time.Minute

func generateNamespace() string {
	short := uuid.New().String()[:8]
	return "nc_" + short
}

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

func LoginHandler(database *db.Database, jwtSecret string, alog *auditLogger) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req LoginRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, ErrorResponse{Error: "phone_number is required"})
			return
		}

		user, err := database.GetUserByPhone(req.PhoneNumber)
		if err != nil {
			namespace := generateNamespace()
			user, err = database.CreateUser(req.PhoneNumber, namespace)
			if err != nil {
				c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "failed to create user"})
				return
			}
		}

		if err := alog.Log(0, user.PhoneNumber, "login", "", "", user.Namespace); err != nil {
			log.Printf("audit log write failed: %v", err)
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

func RegisterHandler(database *db.Database, alog *auditLogger) gin.HandlerFunc {
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

		if err := alog.Log(0, "", "pair/register", req.MachineKey, "", "unassigned"); err != nil {
			log.Printf("audit log write failed: %v", err)
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

		if err := alog.log(c, "pair/confirm", pt.MachineKey, ""); err != nil {
			log.Printf("audit log write failed: %v", err)
		}

		c.JSON(http.StatusOK, gin.H{
			"status":    "approved",
			"namespace": namespace,
		})
	}
}

func PollHandler(database *db.Database, alog *auditLogger) gin.HandlerFunc {
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
			alog.Log(0, "", "pair/poll:expired", pt.MachineKey, "", pt.Namespace)
			c.JSON(http.StatusOK, PollResponse{Status: "expired"})
			return
		}

		alog.Log(0, "", "pair/poll", pt.MachineKey, "", pt.Namespace)

		c.JSON(http.StatusOK, PollResponse{
			Status:    pt.Status,
			Namespace: pt.Namespace,
		})
	}
}

func DevicesHandler(database *db.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		raw, exists := c.Get("namespace")
		if !exists {
			c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "not authenticated"})
			return
		}
		namespace, ok := raw.(string)
		if !ok {
			c.JSON(http.StatusInternalServerError, ErrorResponse{Error: "invalid namespace"})
			return
		}

		devices, err := database.GetDevicesByNamespace(namespace)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch devices"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"devices": devices})
	}
}