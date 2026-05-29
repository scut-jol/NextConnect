class NCUser {
  final int id;
  final String phoneNumber;
  final String namespace;
  final String token;

  NCUser({
    required this.id,
    required this.phoneNumber,
    required this.namespace,
    required this.token,
  });

  factory NCUser.fromJson(Map<String, dynamic> json) {
    return NCUser(
      id: json['user_id'] as int,
      phoneNumber: json['phone_number'] as String? ?? '',
      namespace: json['namespace'] as String,
      token: json['token'] as String,
    );
  }
}