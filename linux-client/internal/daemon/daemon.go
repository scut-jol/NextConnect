package daemon

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	qrcode "github.com/skip2/go-qrcode"
)

const (
	keyFile   = "machine.key"
	stateFile = "tailscale.state"
)

// Daemon manages the lifecycle of the NextConnect Linux client.
type Daemon struct {
	CloudURL   string
	ConfigDir  string
	MachineKey string
	NodeKey    string
	httpClient *http.Client
	tailscaled *exec.Cmd
}

func New(cloudURL string) (*Daemon, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("get home dir: %w", err)
	}
	return &Daemon{
		CloudURL:  strings.TrimRight(cloudURL, "/"),
		ConfigDir: filepath.Join(home, ".config", "nextconnect"),
		httpClient: &http.Client{Timeout: 15 * time.Second},
	}, nil
}

// ---- Key Management ----

// EnsureKeys loads existing keys from disk or generates new ones.
func (d *Daemon) EnsureKeys() error {
	if err := os.MkdirAll(d.ConfigDir, 0700); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}
	keyPath := filepath.Join(d.ConfigDir, keyFile)

	data, err := os.ReadFile(keyPath)
	if err == nil {
		parts := strings.SplitN(strings.TrimSpace(string(data)), ":", 2)
		if len(parts) == 2 {
			d.MachineKey = "mkey:" + parts[0]
			d.NodeKey = "nodekey:" + parts[1]
			return nil
		}
	}

	// Generate new keys
	mkey := make([]byte, 32)
	nkey := make([]byte, 32)
	if _, err := rand.Read(mkey); err != nil {
		return fmt.Errorf("generate machine key: %w", err)
	}
	if _, err := rand.Read(nkey); err != nil {
		return fmt.Errorf("generate node key: %w", err)
	}

	mkeyHex := hex.EncodeToString(mkey)
	nkeyHex := hex.EncodeToString(nkey)

	if err := os.WriteFile(keyPath, []byte(mkeyHex+":"+nkeyHex+"\n"), 0600); err != nil {
		return fmt.Errorf("write key file: %w", err)
	}

	d.MachineKey = "mkey:" + mkeyHex
	d.NodeKey = "nodekey:" + nkeyHex
	return nil
}

// ---- Cloud API ----

type registerRequest struct {
	MachineKey string `json:"machine_key"`
	NodeKey    string `json:"node_key"`
}

type registerResponse struct {
	PairingToken string `json:"pairing_token"`
	PollURL      string `json:"poll_url"`
}

type pollResponse struct {
	Status    string `json:"status"`
	Namespace string `json:"namespace,omitempty"`
}

// Register sends the machine keys to the cloud and returns a pairing token.
func (d *Daemon) Register() (string, error) {
	body := registerRequest{MachineKey: d.MachineKey, NodeKey: d.NodeKey}
	data, err := json.Marshal(body)
	if err != nil {
		return "", fmt.Errorf("marshal register request: %w", err)
	}

	resp, err := d.httpClient.Post(
		d.CloudURL+"/api/v1/pair/register",
		"application/json",
		bytes.NewReader(data),
	)
	if err != nil {
		return "", fmt.Errorf("register request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		raw, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("register failed (HTTP %d): %s", resp.StatusCode, strings.TrimSpace(string(raw)))
	}

	var rr registerResponse
	if err := json.NewDecoder(resp.Body).Decode(&rr); err != nil {
		return "", fmt.Errorf("parse register response: %w", err)
	}
	if rr.PairingToken == "" {
		return "", fmt.Errorf("empty pairing token in response")
	}
	return rr.PairingToken, nil
}

// Poll checks whether the pairing token has been confirmed by the mobile app.
func (d *Daemon) Poll(token string) (string, error) {
	req, err := http.NewRequest("GET", d.CloudURL+"/api/v1/pair/poll?token="+token, nil)
	if err != nil {
		return "", fmt.Errorf("create poll request: %w", err)
	}
	req.Header.Set("User-Agent", "NextConnect-Daemon/0.1.0")

	resp, err := d.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("poll request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("poll failed (HTTP %d)", resp.StatusCode)
	}

	var pr pollResponse
	if err := json.NewDecoder(resp.Body).Decode(&pr); err != nil {
		return "", fmt.Errorf("parse poll response: %w", err)
	}
	return pr.Status, nil
}

// ---- QR Code ----

// PrintQRCode renders a URL as an ASCII QR code to stdout.
func (d *Daemon) PrintQRCode(url string) error {
	qr, err := qrcode.New(url, qrcode.Medium)
	if err != nil {
		return fmt.Errorf("generate QR: %w", err)
	}
	art := qr.ToString(false)
	fmt.Println(art)
	return nil
}

// ---- Tunnel Management ----

// StartTunnel launches tailscaled + tailscale up in userspace-networking mode.
func (d *Daemon) StartTunnel() error {
	statePath := filepath.Join(d.ConfigDir, stateFile)
	ctx := context.Background()

	// First, start tailscaled in userspace networking mode
	d.tailscaled = exec.CommandContext(ctx, "tailscaled",
		"--tun=userspace-networking",
		"--listen-addr=localhost:1055",
		"--state="+statePath,
	)
	if err := d.tailscaled.Start(); err != nil {
		return fmt.Errorf("start tailscaled: %w", err)
	}

	// Give it a moment to start
	time.Sleep(2 * time.Second)

	// Then bring up the tailscale interface pointing to our control server
	var upOut bytes.Buffer
	upCmd := exec.CommandContext(ctx, "tailscale",
		"up",
		"--login-server="+d.CloudURL,
		"--accept-routes=false",
		"--accept-dns=false",
		"--hostname=nextconnect-device",
	)
	upCmd.Stdout = &upOut
	upCmd.Stderr = &upOut

	if err := upCmd.Run(); err != nil {
		// Attempt to clean up tailscaled
		d.tailscaled.Process.Kill()
		return fmt.Errorf("tailscale up: %s: %w", strings.TrimSpace(upOut.String()), err)
	}

	return nil
}

// StopTunnel gracefully shuts down the tailscale tunnel.
func (d *Daemon) StopTunnel() {
	if d.tailscaled != nil && d.tailscaled.Process != nil {
		d.tailscaled.Process.Kill()
		d.tailscaled.Wait()
	}
}