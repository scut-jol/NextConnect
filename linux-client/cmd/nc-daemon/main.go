package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/scut-jol/NextConnect/linux-client/internal/daemon"
)

const (
	cloudServerURL = "https://api.nextconnect.com"
	pollInterval   = 2 * time.Second
)

func main() {
	fmt.Println("NextConnect Linux Daemon v0.1.0")
	fmt.Println("=================================")

	d := daemon.New(cloudServerURL)

	// Step 1: Ensure local config directory and keys exist
	if err := d.EnsureKeys(); err != nil {
		log.Fatalf("failed to setup keys: %v", err)
	}
	fmt.Println("[OK] Machine keys ready")

	// Step 2: Register with cloud control plane
	token, err := d.Register()
	if err != nil {
		log.Fatalf("failed to register with cloud: %v", err)
	}
	fmt.Printf("[OK] Pairing token: %s\n", token)

	// Step 3: Render QR code in terminal
	pairURL := fmt.Sprintf("https://nextconnect.com/bind?token=%s", token)
	if err := d.PrintQRCode(pairURL); err != nil {
		log.Fatalf("failed to render QR code: %v", err)
	}
	fmt.Println("\nPlease scan the QR code above with the NextConnect mobile app.")
	fmt.Println("Pairing token (manual):", token)

	// Step 4: Poll until approved
	fmt.Println("\nWaiting for approval...")
	for {
		status, err := d.Poll(token)
		if err != nil {
			log.Printf("poll error: %v, retrying...", err)
			time.Sleep(pollInterval)
			continue
		}
		if status == "approved" {
			fmt.Println("\n[OK] Device approved! Starting tunnel...")
			break
		}
		time.Sleep(pollInterval)
	}

	// Step 5: Start tunnel
	if err := d.StartTunnel(); err != nil {
		log.Fatalf("failed to start tunnel: %v", err)
	}
	fmt.Println("[OK] Secure tunnel established. Your device is now connected.")

	select {}
}