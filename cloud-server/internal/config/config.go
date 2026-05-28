package config

type Config struct {
	ListenAddr string
	DBPath     string
	JWTSecret  string
}

func Load() *Config {
	return &Config{
		ListenAddr: ":8080",
		DBPath:     "./data/nextconnect.db",
		JWTSecret:  "change-me-in-production",
	}
}