package api

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// Claims holds the JWT payload for authenticated users.
type Claims struct {
	UserID    int64  `json:"user_id"`
	Phone     string `json:"phone"`
	Namespace string `json:"namespace"`
	jwt.RegisteredClaims
}

// AuthMiddleware validates JWT tokens and injects user claims into the context.
func AuthMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "missing authorization header"})
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenStr == authHeader {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "invalid authorization format, use Bearer <token>"})
			return
		}

		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
			return []byte(secret), nil
		})
		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, ErrorResponse{Error: "invalid or expired token"})
			return
		}

		c.Set("user_id", claims.UserID)
		c.Set("phone", claims.Phone)
		c.Set("namespace", claims.Namespace)
		c.Next()
	}
}