/// VPN/Tunnel Service Stub
///
/// This service is responsible for activating the local WireGuard/Tailscale
/// tunnel on the mobile device. When implemented, it will:
///
/// 1. Receive the user's Namespace credentials from the login flow
/// 2. Initialize the platform's VPN adapter (via flutter_wireguard or
///    platform-specific bindings to libtailscale)
/// 3. Connect to the Headscale control plane at api.nextconnect.com
/// 4. Obtain a virtual IP (e.g. 100.64.0.x) for P2P communication
///
/// The VPN tunnel **must** be active before SSH connections to paired
/// Linux devices can succeed, since dartssh2 connects to the virtual
/// IP assigned by the tunnel interface.
///
/// Integration points:
/// - Android: use android.net.VpnService + WireGuard tun interface
/// - iOS: use NetworkExtension (NEPacketTunnelProvider) + WireGuard
///
/// Status: stub — requires native platform plugin integration.
class VpnService {
  bool _connected = false;

  bool get isConnected => _connected;

  /// Connect to the Headscale control plane.
  /// [namespace] is the user's assigned namespace from login.
  Future<void> connect(String namespace) async {
    // TODO: implement platform VPN tunnel
    _connected = true;
  }

  /// Disconnect the VPN tunnel.
  Future<void> disconnect() async {
    // TODO: tear down platform VPN tunnel
    _connected = false;
  }
}