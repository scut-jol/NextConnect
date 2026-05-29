class NCDevice {
  final String id;
  final String name;
  final String virtualIp;
  final bool online;
  final String? machineKey;

  NCDevice({
    required this.id,
    required this.name,
    required this.virtualIp,
    this.online = false,
    this.machineKey,
  });

  factory NCDevice.fromJson(Map<String, dynamic> json) {
    return NCDevice(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown',
      virtualIp: json['virtual_ip'] as String? ?? '0.0.0.0',
      online: json['online'] as bool? ?? false,
      machineKey: json['machine_key'] as String?,
    );
  }
}