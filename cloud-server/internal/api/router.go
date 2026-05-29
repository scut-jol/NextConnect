package api

import (
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
	uid, _ := userID.(int64)
	p, _ := phone.(string)
	return a.Logger.Log(int(uid), p, action, target, vip)
}

func SetupRouter(database *db.Database, jwtSecret string) *gin.Engine {
	r := gin.Default()

	alog := &auditLogger{audit.NewLogger(database.DB)}

	apiGroup := r.Group("/api/v1")
	{
		apiGroup.POST("/auth/login", LoginHandler(database, jwtSecret))
		apiGroup.POST("/pair/register", RegisterHandler(database))
		apiGroup.GET("/pair/poll", PollHandler(database))

		protected := apiGroup.Group("/pair/confirm")
		protected.Use(AuthMiddleware(jwtSecret))
		protected.POST("", ConfirmHandler(database, alog))
	}

	return r
}