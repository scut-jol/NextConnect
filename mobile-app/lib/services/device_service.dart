import '../models/device.dart';

/// Manages the list of paired devices for the current user.
///
/// In production, this fetches from the cloud API (which queries Headscale
/// for nodes in the user's namespace). For now, returns mock data matching
/// the expected device schema.
class DeviceService {
  /// Fetches all devices in the user's namespace.
  ///
  /// TODO: Replace with real API call:
  /// GET /api/v1/devices (Authorization: Bearer <jwt>)
  Future<List<NCDevice>> getDevices() async {
    // Mock data — replace with real API integration
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      NCDevice(
        id: 'node-001',
        name: 'WSL2-Ubuntu',
        virtualIp: '100.64.0.3',
        online: true,
      ),
      NCDevice(
        id: 'node-002',
        name: 'Lab-Server',
        virtualIp: '100.64.0.4',
        online: false,
      ),
    ];
  }
}