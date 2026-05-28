package install

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Installer handles the one-click setup of nc-daemon on the target Linux machine.
type Installer struct {
	BinaryPath string
	ConfigDir  string
}

const (
	ncBinaryName = "nc-daemon"
	ncServiceName = "nextconnect-daemon"
	systemdServiceUnit = `[Unit]
Description=NextConnect P2P Tunnel Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/nc-daemon
Restart=on-failure
RestartSec=5
User=%s

[Install]
WantedBy=multi-user.target
`
)

func New() *Installer {
	home, _ := os.UserHomeDir()
	return &Installer{
		BinaryPath: "/usr/local/bin/" + ncBinaryName,
		ConfigDir:  filepath.Join(home, ".config", "nextconnect"),
	}
}

// DetectWSL returns true if running inside WSL (Windows Subsystem for Linux).
func DetectWSL() bool {
	data, err := os.ReadFile("/proc/version")
	if err != nil {
		return false
	}
	return bytes.Contains(bytes.ToLower(data), []byte("microsoft")) ||
		bytes.Contains(bytes.ToLower(data), []byte("wsl"))
}

// HasSystemd returns true if systemd is available on this system.
func HasSystemd() bool {
	err := exec.Command("systemctl", "--version").Run()
	return err == nil
}

// InstallBinary copies the nc-daemon binary to its target location.
func (inst *Installer) InstallBinary(sourcePath string) error {
	if err := os.MkdirAll(filepath.Dir(inst.BinaryPath), 0755); err != nil {
		return fmt.Errorf("create install dir: %w", err)
	}

	data, err := os.ReadFile(sourcePath)
	if err != nil {
		return fmt.Errorf("read source binary: %w", err)
	}

	if err := os.WriteFile(inst.BinaryPath, data, 0755); err != nil {
		return fmt.Errorf("write binary: %w", err)
	}
	return nil
}

// RegisterSystemdService installs and enables the systemd service unit.
func (inst *Installer) RegisterSystemdService() error {
	unitPath := "/etc/systemd/system/" + ncServiceName + ".service"
	user := os.Getenv("USER")
	if user == "" {
		user = "root"
	}
	unit := fmt.Sprintf(systemdServiceUnit, user)

	if err := os.WriteFile(unitPath, []byte(unit), 0644); err != nil {
		return fmt.Errorf("write systemd unit: %w", err)
	}

	cmds := [][]string{
		{"systemctl", "daemon-reload"},
		{"systemctl", "enable", ncServiceName},
		{"systemctl", "start", ncServiceName},
	}
	for _, args := range cmds {
		if err := exec.Command(args[0], args[1:]...).Run(); err != nil {
			return fmt.Errorf("%s: %w", strings.Join(args, " "), err)
		}
	}
	return nil
}

// RegisterNohupService falls back to nohup + crontab for systems without systemd.
func (inst *Installer) RegisterNohupService() error {
	// Create a wrapper script
	wrapperPath := "/usr/local/bin/nc-daemon-wrapper.sh"
	wrapper := fmt.Sprintf(`#!/bin/bash
nohup %s > %s/nc-daemon.log 2>&1 &
`, inst.BinaryPath, inst.ConfigDir)

	if err := os.WriteFile(wrapperPath, []byte(wrapper), 0755); err != nil {
		return fmt.Errorf("write wrapper script: %w", err)
	}

	// Add to crontab for auto-start on boot
	cronLine := "@reboot " + wrapperPath + "\n"

	// Read existing crontab
	var existing bytes.Buffer
	existing.WriteString(cronLine)
	cmd := exec.Command("crontab", "-l")
	if out, err := cmd.Output(); err == nil {
		existing.Write(out)
	}

	// Write merged crontab
	tmpFile := filepath.Join(os.TempDir(), "nc-crontab")
	if err := os.WriteFile(tmpFile, existing.Bytes(), 0644); err != nil {
		return fmt.Errorf("write temp crontab: %w", err)
	}
	defer os.Remove(tmpFile)

	if err := exec.Command("crontab", tmpFile).Run(); err != nil {
		return fmt.Errorf("install crontab: %w", err)
	}

	// Start daemon now
	return exec.Command("bash", wrapperPath).Run()
}

// PromptUser interactively confirms installation steps.
// Returns the user's response (first word).
func PromptUser(prompt string) string {
	fmt.Print(prompt + " [Y/n]: ")
	reader := bufio.NewReader(os.Stdin)
	text, _ := reader.ReadString('\n')
	text = strings.TrimSpace(strings.ToLower(text))
	if text == "" || text == "y" || text == "yes" {
		return "yes"
	}
	return text
}

// PrintSummary shows the install result and next steps.
func PrintSummary(systemd bool, wsl bool) {
	fmt.Println("\n╔══════════════════════════════════════════╗")
	fmt.Println("║     NextConnect Installation Complete    ║")
	fmt.Println("╚══════════════════════════════════════════╝")
	if wsl {
		fmt.Println(" • WSL2 detected: using userspace networking")
	}
	if systemd {
		fmt.Println(" • Service: systemd (enabled + started)")
	} else {
		fmt.Println(" • Service: nohup + crontab (auto-start on boot)")
	}
	fmt.Println(" • Status: nc-daemon is running in the background")
	fmt.Println("\n To check logs:")
	if systemd {
		fmt.Println("   journalctl -u nextconnect-daemon -f")
	} else {
		fmt.Println("   tail -f ~/.config/nextconnect/nc-daemon.log")
	}
	fmt.Println("\n To re-run pairing manually:")
	fmt.Println("   sudo /usr/local/bin/nc-daemon")
}