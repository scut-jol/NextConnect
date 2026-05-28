package api

import (
	"github.com/gin-gonic/gin"
	"github.com/scut-jol/NextConnect/cloud-server/internal/db"
)

func SetupRouter(database *db.Database) *gin.Engine {
	r := gin.Default()

	apiGroup := r.Group("/api/v1")
	{
		apiGroup.POST("/auth/login", LoginHandler(database))
		apiGroup.POST("/pair/register", RegisterHandler(database))
		apiGroup.POST("/pair/confirm", ConfirmHandler(database))
		apiGroup.GET("/pair/poll", PollHandler(database))
	}

	return r
}