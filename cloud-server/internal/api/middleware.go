package api

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// RateLimiter provides simple in-memory rate limiting per client IP.
type RateLimiter struct {
	mu       sync.Mutex
	requests map[string]int
	limit    int
	window   time.Duration
	last     time.Time
}

// NewRateLimiter creates a rate limiter allowing [limit] requests per [window].
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	rl := &RateLimiter{
		requests: make(map[string]int),
		limit:    limit,
		window:   window,
		last:     time.Now(),
	}
	// Background cleanup every 10 windows
	go func() {
		for {
			time.Sleep(window * 10)
			rl.mu.Lock()
			rl.requests = make(map[string]int)
			rl.last = time.Now()
			rl.mu.Unlock()
		}
	}()
	return rl
}

func (rl *RateLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	// Reset if window expired
	if time.Since(rl.last) > rl.window {
		rl.requests = make(map[string]int)
		rl.last = time.Now()
	}

	rl.requests[ip]++
	return rl.requests[ip] <= rl.limit
}

// RateLimitMiddleware returns a Gin middleware that rate-limits per client IP.
func RateLimitMiddleware(limit int, window time.Duration) gin.HandlerFunc {
	rl := NewRateLimiter(limit, window)
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if !rl.Allow(ip) {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, ErrorResponse{
				Error: "rate limit exceeded. Try again later.",
			})
			return
		}
		c.Next()
	}
}

// SecurityHeadersMiddleware adds standard security HTTP headers.
func SecurityHeadersMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		c.Header("Cache-Control", "no-store")
		c.Next()
	}
}

// MaxBodySizeMiddleware limits request body size to prevent abuse.
func MaxBodySizeMiddleware(maxBytes int64) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)
		c.Next()
	}
}