package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/scut-jol/NextConnect/cloud-server/internal/db"
)

func LoginHandler(database *db.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: implement phone number / WeChat login
		c.JSON(http.StatusOK, gin.H{"message": "login endpoint - not yet implemented"})
	}
}

func RegisterHandler(database *db.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: receive machine_key, generate pairing token
		c.JSON(http.StatusOK, gin.H{"message": "pair register endpoint - not yet implemented"})
	}
}

func ConfirmHandler(database *db.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: mobile scans QR code, confirms pairing
		c.JSON(http.StatusOK, gin.H{"message": "pair confirm endpoint - not yet implemented"})
	}
}

func PollHandler(database *db.Database) gin.HandlerFunc {
	return func(c *gin.Context) {
		// TODO: linux client polls for pairing status
		c.JSON(http.StatusOK, gin.H{"message": "pair poll endpoint - not yet implemented"})
	}
}