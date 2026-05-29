package api

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/scut-jol/NextConnect/cloud-server/internal/audit"
	"github.com/scut-jol/NextConnect/cloud-server/internal/db"
)

type auditLogger struct {
	*audit.Logger
}

func (a *auditLogger) log(c *gin.Context, action, target, vip string) error {
	userID, _ := c.Get("user_id")
	phone, _ := c.Get("phone")
	namespace, _ := c.Get("namespace")
	uid, _ := userID.(int64)
	p, _ := phone.(string)
	ns, _ := namespace.(string)
	return a.Logger.Log(int(uid), p, action, target, vip, ns)
}

func SetupRouter(database *db.Database, jwtSecret string) *gin.Engine {
	r := gin.Default()

	// Global middleware
	r.Use(SecurityHeadersMiddleware())
	r.Use(MaxBodySizeMiddleware(10240))

	alog := &auditLogger{audit.NewLogger(database.DB)}

	apiGroup := r.Group("/api/v1")
	{
		// Public endpoints
		apiGroup.GET("/health", HealthHandler())
		apiGroup.GET("/acl/policy", ACLHandler())

		// Rate-limited public endpoints
		rl := RateLimitMiddleware(5, 1*time.Minute)

		apiGroup.POST("/auth/login", rl, LoginHandler(database, jwtSecret, alog))
		apiGroup.POST("/pair/register", rl, RegisterHandler(database, alog))

		// Poll: lightweight, higher limit
		apiGroup.GET("/pair/poll", RateLimitMiddleware(30, 1*time.Minute), PollHandler(database, alog))

		// JWT-protected endpoints
		protected := apiGroup.Group("")
		protected.Use(AuthMiddleware(jwtSecret))
		{
			protected.POST("/pair/confirm", ConfirmHandler(database, alog))
			protected.GET("/devices", DevicesHandler(database))
		}
	}

	return r
}