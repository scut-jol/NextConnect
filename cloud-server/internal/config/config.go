package config

import "os"

type Config struct {
	ListenAddr string
	DBPath     string
	JWTSecret  string
}

func Load() *Config {
	return &Config{
		ListenAddr: getEnv("NC_LISTEN_ADDR", ":8080"),
		DBPath:     getEnv("NC_DB_PATH", "./data/nextconnect.db"),
		JWTSecret:  getEnv("NC_JWT_SECRET", "change-me-in-production"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}