package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/scut-jol/NextConnect/cloud-server/internal/acl"
)

// ACLHandler serves the strict ACL configuration that Headscale will enforce.
// Headscale fetches ACL policies from a JSON endpoint; this provides
// the "SSH-only" policy document that blocks all non-22 traffic.
//
// Endpoint: GET /api/v1/acl/policy
// Response: JSON ACL document consumable by Headscale
func ACLHandler() gin.HandlerFunc {
	policyJSON := acl.MustGenerateJSON()
	return func(c *gin.Context) {
		c.Data(http.StatusOK, "application/json", []byte(policyJSON))
	}
}

// HealthHandler provides a simple health-check endpoint.
func HealthHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "nextconnect-cloud",
		})
	}
}