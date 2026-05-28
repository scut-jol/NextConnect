package main

import (
	"log"

	"github.com/scut-jol/NextConnect/cloud-server/internal/api"
	"github.com/scut-jol/NextConnect/cloud-server/internal/config"
	"github.com/scut-jol/NextConnect/cloud-server/internal/db"
)

func main() {
	cfg := config.Load()
	database, err := db.Init(cfg.DBPath)
	if err != nil {
		log.Fatalf("failed to init database: %v", err)
	}
	defer database.Close()

	router := api.SetupRouter(database, cfg.JWTSecret)
	log.Printf("NextConnect cloud-server starting on %s", cfg.ListenAddr)
	if err := router.Run(cfg.ListenAddr); err != nil {
		log.Fatalf("server failed: %v", err)
	}
}