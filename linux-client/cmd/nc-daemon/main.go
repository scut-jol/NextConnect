package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/scut-jol/NextConnect/linux-client/internal/daemon"
)

const (
	cloudServerURL = "https://api.nextconnect.com"
	pollInterval   = 2 * time.Second
)

func main() {
	fmt.Println(`
╔══════════════════════════════════════════╗
║        NextConnect Linux Daemon         ║
║     Secure P2P SSH Tunnel v0.1.0        ║
╚══════════════════════════════════════════╝
`)

	d, err := daemon.New(cloudServerURL)
	if err != nil {
		log.Fatalf("FATAL: %v", err)
	}

	// Step 1: ensure machine keys exist
	if err := d.EnsureKeys(); err != nil {
		log.Fatalf("FATAL: failed to setup keys: %v", err)
	}
	fmt.Println(" ✓ Machine keys ready")

	// Step 2: register with cloud control plane
	token, err := d.Register()
	if err != nil {
		log.Fatalf("FATAL: failed to register with cloud: %v", err)
	}
	fmt.Printf(" ✓ Pairing token: %s\n", token)

	// Step 3: render QR code
	pairURL := fmt.Sprintf("https://nextconnect.com/bind?token=%s", token)
	fmt.Println("\n ┌─ Scan this QR code with NextConnect App ─────────────┐")
	if err := d.PrintQRCode(pairURL); err != nil {
		log.Fatalf("FATAL: failed to render QR code: %v", err)
	}
	fmt.Println(" └──────────────────────────────────────────────────────┘")
	fmt.Printf("\n Or enter token manually: %s\n", token)
	fmt.Println("\n Waiting for mobile approval... (press Ctrl+C to cancel)")

	// Step 4: poll with graceful shutdown
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pollTicker := time.NewTicker(pollInterval)
	defer pollTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			fmt.Println("\nCancelled by user.")
			return
		case <-pollTicker.C:
			status, err := d.Poll(token)
			if err != nil {
				log.Printf("poll error: %v, retrying...", err)
				continue
			}
			switch status {
			case "approved":
				fmt.Println("\n ✓ Device approved by mobile! Starting tunnel...")
				goto APPROVED
			case "expired":
				log.Fatalf("FATAL: pairing token expired. Re-run nc-daemon to get a new one.")
			default:
				fmt.Print(".")
			}
		}
	}

APPROVED:
	// Step 5: start tailscale tunnel
	if err := d.StartTunnel(); err != nil {
		log.Fatalf("FATAL: failed to start tunnel: %v", err)
	}
	fmt.Println("\n ✓ Secure tunnel established. P2P network ready!")
	fmt.Println(" ✓ Your device is now accessible via the NextConnect App.")
	fmt.Println("\n Press Ctrl+C to stop the daemon.")

	// Block until shutdown signal
	<-ctx.Done()
	fmt.Println("\nShutting down NextConnect daemon...")
	// StopTunnel kills tailscaled. The subprocess might already be stopped
	// if the signal propagated through exec.CommandContext, but Kill() on
	// an exited process is safe and returns an error we can discard.
	d.StopTunnel()
	fmt.Println("Goodbye.")
}