import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../models/device.dart';
import 'scanner_screen.dart';
import 'terminal_screen.dart';

class NCDeviceListScreen extends StatefulWidget {
  final ApiService apiService;
  final AuthService authService;

  const NCDeviceListScreen({
    super.key,
    required this.apiService,
    required this.authService,
  });

  @override
  State<NCDeviceListScreen> createState() => _NCDeviceListScreenState();
}

class _NCDeviceListScreenState extends State<NCDeviceListScreen> {
  final _deviceService = DeviceService();
  List<NCDevice> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _deviceService.getDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载设备列表失败: $e';
        _loading = false;
      });
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NCScannerScreen(apiService: widget.apiService),
      ),
    ).then((_) => _loadDevices());
  }

  void _openTerminal(NCDevice device) {
    if (!device.online) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device.name} 离线中，无法连接')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NCTerminalScreen(
          host: device.virtualIp,
          hostname: device.name,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设备大厅'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00FF41)),
            onPressed: _openScanner,
            tooltip: '扫描二维码绑定设备',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onSelected: (v) {
              if (v == 'logout') _logout();
              if (v == 'refresh') _loadDevices();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh), title: Text('刷新'))),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('退出登录'))),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF41)));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey[400]), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDevices,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.devices, color: Colors.grey[700], size: 64),
            const SizedBox(height: 16),
            Text('暂无设备', style: TextStyle(color: Colors.grey[500], fontSize: 18)),
            const SizedBox(height: 8),
            Text('点击右上角扫码添加', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('扫描绑定'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00FF41),
      onRefresh: _loadDevices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _devices.length + 1,
        itemBuilder: (_, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '共 ${_devices.length} 台设备',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            );
          }
          return _buildDeviceCard(_devices[index - 1]);
        },
      ),
    );
  }

  Widget _buildDeviceCard(NCDevice device) {
    return Card(
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: device.online ? const Color(0xFF00FF41).withOpacity(0.3) : Colors.grey[800]!,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openTerminal(device),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: device.online ? const Color(0xFF00FF41) : Colors.grey[700],
                  boxShadow: device.online
                      ? [BoxShadow(color: const Color(0xFF00FF41).withOpacity(0.4), blurRadius: 8)]
                      : [],
                ),
              ),
              const SizedBox(width: 16),
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.virtualIp,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
              // Status text
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: device.online
                      ? const Color(0xFF00FF41).withOpacity(0.15)
                      : Colors.grey[800],
                ),
                child: Text(
                  device.online ? '在线' : '离线',
                  style: TextStyle(
                    fontSize: 12,
                    color: device.online ? const Color(0xFF00FF41) : Colors.grey[500],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[700]),
            ],
          ),
        ),
      ),
    );
  }
}