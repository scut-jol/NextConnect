#!/usr/bin/env bash
set -euo pipefail

# NextConnect Linux Client - One-Click Installer
# Usage:
#   curl -fsSL https://api.nextconnect.com/install.sh | sh
#   curl -fsSL https://api.nextconnect.com/install.sh | bash -s -- --beta

NC_VERSION="0.1.0"
NC_BINARY="nc-daemon"
NC_INSTALL_DIR="/usr/local/bin"
NC_CONFIG_DIR="${HOME}/.config/nextconnect"
NC_RELEASE_BASE="https://api.nextconnect.com/releases"

# --------------- Color helpers ---------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; exit 1; }
header(){ printf "\n${CYAN}%s${NC}\n" "$*"; }

# --------------- Pre-flight checks ---------------
header "NextConnect Linux Client v${NC_VERSION} - Installer"

# Must be root for system-wide install
if [ "$(id -u)" -ne 0 ]; then
    warn "This installer should usually be run as root for systemd registration."
    warn "You may be prompted for sudo password."
    USE_SUDO=1
else
    USE_SUDO=0
fi
SUDO=""
[ "$USE_SUDO" = "1" ] && SUDO="sudo"

# Detect OS & Architecture
OS=$(uname -s)
ARCH=$(uname -m)
info "Detected: ${OS} / ${ARCH}"

# Detect WSL2
WSL=false
if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/version 2>/dev/null; then
    WSL=true
    info "WSL2 environment detected — will use userspace networking mode"
fi

# Detect systemd
SYSTEMD=false
if command -v systemctl &>/dev/null; then
    SYSTEMD=true
    info "systemd detected — will register as system service"
else
    info "systemd not found — will use nohup + crontab fallback"
fi

# --------------- Download binary ---------------
header "Downloading nc-daemon binary..."

DOWNLOAD_URL="${NC_RELEASE_BASE}/${NC_VERSION}/${OS}/${ARCH}/${NC_BINARY}"
info "Downloading from ${DOWNLOAD_URL}"

TMP_BIN=$(mktemp)
# TODO: replace with real release URL when CI/CD is set up
if curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_BIN}" 2>/dev/null; then
    chmod +x "${TMP_BIN}"
    info "Binary downloaded successfully"
else
    warn "Release server not available — using built binary from current directory"
    if [ -f "./${NC_BINARY}" ]; then
        cp "./${NC_BINARY}" "${TMP_BIN}"
    else
        error "No binary found. Build nc-daemon first with: go build -o nc-daemon ./cmd/nc-daemon"
    fi
fi

# --------------- Install binary ---------------
header "Installing binary..."

${SUDO} mkdir -p "${NC_INSTALL_DIR}"
${SUDO} cp "${TMP_BIN}" "${NC_INSTALL_DIR}/${NC_BINARY}"
${SUDO} chmod 755 "${NC_INSTALL_DIR}/${NC_BINARY}"
rm -f "${TMP_BIN}"

info "Installed to ${NC_INSTALL_DIR}/${NC_BINARY}"

# --------------- Create config directory ---------------
mkdir -p "${NC_CONFIG_DIR}"
info "Config directory: ${NC_CONFIG_DIR}"

# --------------- Register service ---------------
header "Registering service..."

if [ "$SYSTEMD" = true ]; then
    # Write systemd unit
    SYSTEMD_UNIT="/etc/systemd/system/nextconnect-daemon.service"
    ${SUDO} tee "${SYSTEMD_UNIT}" > /dev/null <<SERVICE
[Unit]
Description=NextConnect P2P Tunnel Daemon
After=network.target

[Service]
Type=simple
ExecStart=${NC_INSTALL_DIR}/${NC_BINARY}
Restart=on-failure
RestartSec=5
User=$(whoami)

[Install]
WantedBy=multi-user.target
SERVICE

    ${SUDO} systemctl daemon-reload
    ${SUDO} systemctl enable nextconnect-daemon
    ${SUDO} systemctl start nextconnect-daemon

    info "systemd service 'nextconnect-daemon' enabled and started"
else
    # nohup + crontab fallback
    WRAPPER="/usr/local/bin/nc-daemon-wrapper.sh"
    ${SUDO} tee "${WRAPPER}" > /dev/null <<SCRIPT
#!/bin/bash
nohup ${NC_INSTALL_DIR}/${NC_BINARY} > ${NC_CONFIG_DIR}/nc-daemon.log 2>&1 &
SCRIPT
    ${SUDO} chmod +x "${WRAPPER}"

    # Add to crontab
    (crontab -l 2>/dev/null || true; echo "@reboot ${WRAPPER}") | crontab -

    # Start now
    ${SUDO} bash "${WRAPPER}"
    info "nohup service registered via crontab and started"
fi

# --------------- Summary ---------------
header "Installation Complete"

echo ""
printf "  ${GREEN}✓${NC} nc-daemon installed at ${NC_INSTALL_DIR}/${NC_BINARY}\n"
printf "  ${GREEN}✓${NC} Config stored at ${NC_CONFIG_DIR}\n"
if [ "$SYSTEMD" = true ]; then
    printf "  ${GREEN}✓${NC} Service: nextconnect-daemon (systemd)\n"
    printf "  ${GREEN}✓${NC} Logs: journalctl -u nextconnect-daemon -f\n"
else
    printf "  ${GREEN}✓${NC} Service: nohup + crontab\n"
    printf "  ${GREEN}✓${NC} Logs: tail -f ${NC_CONFIG_DIR}/nc-daemon.log\n"
fi
echo ""
echo "  The daemon is now running and waiting for device pairing."
echo "  Open the NextConnect mobile app to scan the QR code."
echo ""