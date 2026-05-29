class LoginRequest {
  final String phoneNumber;

  LoginRequest({required this.phoneNumber});

  Map<String, dynamic> toJson() => {'phone_number': phoneNumber};
}

class LoginResponse {
  final String token;
  final String namespace;
  final int userId;

  LoginResponse({
    required this.token,
    required this.namespace,
    required this.userId,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      namespace: json['namespace'] as String,
      userId: json['user_id'] as int,
    );
  }
}

class ConfirmRequest {
  final String pairingToken;

  ConfirmRequest({required this.pairingToken});

  Map<String, dynamic> toJson() => {'pairing_token': pairingToken};
}

class PollResponse {
  final String status;
  final String? namespace;

  PollResponse({required this.status, this.namespace});

  factory PollResponse.fromJson(Map<String, dynamic> json) {
    return PollResponse(
      status: json['status'] as String,
      namespace: json['namespace'] as String?,
    );
  }
}