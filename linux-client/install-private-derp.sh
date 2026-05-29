#!/usr/bin/env bash
set -euo pipefail

# NextConnect Private DERP Relay Server Installer
#
# Deploys a Tailscale DERP relay server on your own machine.
# This is for advanced users who want zero dependency on public DERP servers.
#
# Usage:
#   curl -fsSL https://api.nextconnect.com/scripts/install-derp.sh | sh -s -- --secret=YOUR_SECRET
#   curl -fsSL https://api.nextconnect.com/scripts/install-derp.sh | sh -s -- --port=443 --domain=derp.example.com

NC_VERSION="0.1.0"

# --------------- Defaults ---------------
DERP_PORT="${NC_DERP_PORT:-443}"
DERP_DOMAIN="${NC_DERP_DOMAIN:-}"
DERP_SECRET="${NC_DERP_SECRET:-}"
DERP_DIR="/etc/nextconnect/derp"

# --------------- Parse arguments ---------------
while [ $# -gt 0 ]; do
    case "$1" in
        --port=*)    DERP_PORT="${1#*=}" ;;
        --domain=*)  DERP_DOMAIN="${1#*=}" ;;
        --secret=*)  DERP_SECRET="${1#*=}" ;;
        --help|-h)
            echo "NextConnect Private DERP Relay Server Installer v${NC_VERSION}"
            echo ""
            echo "Options:"
            echo "  --port=PORT     DERP UDP/TCP port (default: 443)"
            echo "  --domain=HOST   Public domain for SSL certificate"
            echo "  --secret=KEY    Authentication secret from your NextConnect dashboard"
            echo ""
            echo "Example:"
            echo "  curl -fsSL https://api.nextconnect.com/scripts/install-derp.sh \\"
            echo "    | sh -s -- --secret=sk_abc123 --domain=derp.example.com"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# --------------- Color helpers ---------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; exit 1; }
header(){ printf "\n${CYAN}%s${NC}\n" "$*"; }

# --------------- Validation ---------------
header "NextConnect Private DERP Installer v${NC_VERSION}"

if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root (DERP needs privileged ports)"
fi

if [ -z "$DERP_SECRET" ]; then
    warn "No --secret provided. The DERP node will not authenticate to the control plane."
    warn "Get your secret from: https://nextconnect.com/account/derp-settings"
fi

if [ -z "$DERP_DOMAIN" ]; then
    DERP_DOMAIN=$(curl -s http://checkip.amazonaws.com 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null || echo "unknown")
    warn "No --domain provided. Using IP-based DERP (no SSL). Set --domain for production."
fi

# --------------- Install DERP binary ---------------
header "Installing Tailscale DERP server (derper)..."

mkdir -p "${DERP_DIR}"

# Try official Go install, else pull prebuilt
if command -v go &>/dev/null; then
    info "Building derper from source via 'go install'..."
    go install tailscale.com/cmd/derper@latest
    cp "$(go env GOPATH)/bin/derper" "${DERP_DIR}/derper"
elif command -v docker &>/dev/null; then
    info "Using Docker to run derper..."
    # We'll use docker run directly later
    :
else
    error "Neither Go nor Docker found. Install Go or Docker first."
fi

# --------------- Generate self-signed cert (if no real domain) ---------------
header "Configuring SSL..."

CERT_DIR="${DERP_DIR}/certs"
mkdir -p "${CERT_DIR}"

# Check if cert already exists
if [ -f "${CERT_DIR}/${DERP_DOMAIN}.crt" ]; then
    info "Certificate for ${DERP_DOMAIN} already exists, skipping."
elif [[ "$DERP_DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # IP address — generate self-signed cert via openssl
    info "Generating self-signed certificate for IP: ${DERP_DOMAIN}..."
    if ! openssl req -x509 -newkey rsa:4096 -keyout "${CERT_DIR}/${DERP_DOMAIN}.key" \
        -out "${CERT_DIR}/${DERP_DOMAIN}.crt" -days 3650 -nodes \
        -subj "/CN=${DERP_DOMAIN}" 2>/dev/null; then
        error "OpenSSL certificate generation failed. Install openssl: apt install openssl"
    fi
    info "Self-signed certificate generated"
else
    # Domain — try Let's Encrypt via acme.sh or certbot
    if command -v certbot &>/dev/null; then
        info "Obtaining Let's Encrypt certificate for ${DERP_DOMAIN}..."
        certbot certonly --standalone -d "${DERP_DOMAIN}" --non-interactive --agree-tos \
            --email "admin@${DERP_DOMAIN}" 2>/dev/null || true
    elif command -v acme.sh &>/dev/null; then
        info "Obtaining Let's Encrypt certificate via acme.sh..."
        acme.sh --issue --standalone -d "${DERP_DOMAIN}" 2>/dev/null || true
    else
        warn "No certbot or acme.sh found. Generate a certificate manually."
    fi
fi

# --------------- Configure and start DERP ---------------
header "Starting DERP relay..."

DERP_ARGS=(
    "-a" ":${DERP_PORT}"
    "-c" "${DERP_DIR}/derper.key"  # auto-generated
    "-certdir" "${CERT_DIR}"
    "-certmode" "manual"
    "-stun"
)

if [ -n "$DERP_SECRET" ]; then
    DERP_ARGS+=("-verify-clients")
    echo "${DERP_SECRET}" > "${DERP_DIR}/auth.key"
    chmod 600 "${DERP_DIR}/auth.key"
fi

# Stop existing derper if running
pkill derper 2>/dev/null || true
sleep 1

if command -v docker &>/dev/null && ! command -v derper &>/dev/null; then
    # Docker mode
    docker pull tailscale/derper:latest 2>/dev/null
    docker rm -f nc-derper 2>/dev/null || true
    docker run -d --name nc-derper --restart unless-stopped \
        -p "${DERP_PORT}:${DERP_PORT}" \
        -p "${DERP_PORT}:${DERP_PORT}/udp" \
        -v "${CERT_DIR}:/certs" \
        -v "${DERP_DIR}:/data" \
        tailscale/derper:latest \
        -a ":${DERP_PORT}" -c /data/derper.key -certdir /certs -certmode manual -stun
    info "DERP running in Docker container 'nc-derper'"
else
    # Native mode
    nohup "${DERP_DIR}/derper" "${DERP_ARGS[@]}" > "${DERP_DIR}/derper.log" 2>&1 &
    DERP_PID=$!
    echo "${DERP_PID}" > "${DERP_DIR}/derper.pid"
    info "DERP started (PID: ${DERP_PID})"
fi

# --------------- Register systemd service ---------------
header "Registering DERP systemd service..."

cat > /etc/systemd/system/nextconnect-derper.service <<UNIT
[Unit]
Description=NextConnect DERP Relay Server
After=network.target

[Service]
Type=simple
ExecStart=${DERP_DIR}/derper -a :${DERP_PORT} -c ${DERP_DIR}/derper.key -certdir ${CERT_DIR} -certmode manual -stun
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable nextconnect-derper
systemctl start nextconnect-derper 2>/dev/null || true

info "systemd service 'nextconnect-derper' registered"

# --------------- Firewall ---------------
header "Configuring firewall..."

for FW in ufw firewall-cmd; do
    case "$FW" in
        ufw)
            if command -v ufw &>/dev/null; then
                ufw allow "${DERP_PORT}/tcp" 2>/dev/null || true
                ufw allow "${DERP_PORT}/udp" 2>/dev/null || true
                info "UFW: allowed port ${DERP_PORT} (TCP+UDP)"
            fi
            ;;
        firewall-cmd)
            if command -v firewall-cmd &>/dev/null; then
                firewall-cmd --permanent --add-port="${DERP_PORT}/tcp" 2>/dev/null || true
                firewall-cmd --permanent --add-port="${DERP_PORT}/udp" 2>/dev/null || true
                firewall-cmd --reload 2>/dev/null || true
                info "firewalld: allowed port ${DERP_PORT} (TCP+UDP)"
            fi
            ;;
    esac
done

# --------------- Summary ---------------
header "DERP Installation Complete"

echo ""
printf "  ${GREEN}✓${NC} DERP relay server: ${DERP_DOMAIN}:${DERP_PORT}\n"
printf "  ${GREEN}✓${NC} Config directory: ${DERP_DIR}\n"
printf "  ${GREEN}✓${NC} Certificate dir: ${CERT_DIR}\n"
echo ""
echo "  To register this DERP node in your NextConnect control plane:"
echo "    1. Go to https://nextconnect.com/account/derp-settings"
echo "    2. Add a new DERP node with:"
echo "       - Address: ${DERP_DOMAIN}:${DERP_PORT}"
echo "       - Secret: ${DERP_SECRET}"
echo ""
echo "  To check status:"
echo "    systemctl status nextconnect-derper"
echo "    tail -f ${DERP_DIR}/derper.log"
echo ""