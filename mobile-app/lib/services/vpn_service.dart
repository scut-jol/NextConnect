// VPN/Tunnel Service Stub
//
// This service is responsible for activating the local WireGuard/Tailscale
// tunnel on the mobile device. When implemented, it will:
// 1. Receive the user's Namespace credentials from the login flow
// 2. Initialize the platform's VPN adapter (via flutter_wireguard or libtailscale)
// 3. Connect to the Headscale control plane at api.nextconnect.com
// 4. Obtain a virtual IP (e.g. 100.64.0.x) for P2P communication
//
// The VPN tunnel must be active before attempting SSH connections
// to paired Linux devices.