package daemon

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	qrcode "github.com/skip2/go-qrcode"
)

type Daemon struct {
	CloudURL   string
	ConfigDir  string
	MachineKey string
	NodeKey    string
}

func New(cloudURL string) *Daemon {
	home, _ := os.UserHomeDir()
	return &Daemon{
		CloudURL:  cloudURL,
		ConfigDir: filepath.Join(home, ".config", "nextconnect"),
	}
}

func (d *Daemon) EnsureKeys() error {
	if err := os.MkdirAll(d.ConfigDir, 0700); err != nil {
		return fmt.Errorf("create config dir: %w", err)
	}
	// TODO: generate or load Tailscale MachineKey / NodeKey
	d.MachineKey = "mkey:generated-in-dev"
	d.NodeKey = "nodekey:generated-in-dev"
	return nil
}

func (d *Daemon) Register() (string, error) {
	// TODO: POST to d.CloudURL /api/v1/pair/register with machine_key
	return "NC-DEV-TOKEN", nil
}

func (d *Daemon) PrintQRCode(url string) error {
	qr, err := qrcode.New(url, qrcode.Medium)
	if err != nil {
		return fmt.Errorf("generate QR: %w", err)
	}
	art := qr.ToString(false)
	fmt.Println(art)
	return nil
}

func (d *Daemon) Poll(token string) (string, error) {
	// TODO: GET d.CloudURL /api/v1/pair/poll?token=...
	return "pending", nil
}

func (d *Daemon) StartTunnel() error {
	// TODO: exec tailscaled + tailscale up --login-server=d.CloudURL
	var stderr bytes.Buffer
	cmd := exec.Command("tailscale", "up", "--login-server="+d.CloudURL, "--accept-routes=false")
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("start tunnel: %s: %w", stderr.String(), err)
	}
	return nil
}