#!/usr/bin/env bash
set -euo pipefail

# NextConnect Linux Client - One-Click Installer
# Usage: curl -fsSL https://api.nextconnect.com/install.sh | sh

NC_VERSION="0.1.0"
NC_BINARY="nc-daemon"
NC_INSTALL_DIR="/usr/local/bin"
NC_CONFIG_DIR="${HOME}/.config/nextconnect"

echo "============================================"
echo " NextConnect Linux Client v${NC_VERSION}"
echo "============================================"

# Detect OS & Arch
OS=$(uname -s)
ARCH=$(uname -m)
echo "[*] Detected: ${OS} / ${ARCH}"

# TODO: download the correct binary from release server
# curl -fsSL "https://api.nextconnect.com/releases/${NC_VERSION}/${OS}/${ARCH}/${NC_BINARY}" -o "${NC_INSTALL_DIR}/${NC_BINARY}"

echo "[*] Creating config directory..."
mkdir -p "${NC_CONFIG_DIR}"

# TODO: register as systemd service or fallback to nohup
echo ""
echo "NextConnect daemon installed successfully!"
echo "Run 'nc-daemon' to start the pairing process."