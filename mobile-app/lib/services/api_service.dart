import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/api_types.dart';

class ApiService {
  static const String baseUrl = 'https://api.nextconnect.com';

  final http.Client _client = http.Client();
  String? _jwtToken;

  void setToken(String token) {
    _jwtToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_jwtToken != null) 'Authorization': 'Bearer $_jwtToken',
      };

  /// POST /api/v1/auth/login
  Future<LoginResponse> login(String phoneNumber) async {
    final body = LoginRequest(phoneNumber: phoneNumber).toJson();
    final resp = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, _extractError(resp.body));
    }
    return LoginResponse.fromJson(jsonDecode(resp.body));
  }

  /// POST /api/v1/pair/confirm
  Future<void> confirmPairing(String pairingToken) async {
    final body = ConfirmRequest(pairingToken: pairingToken).toJson();
    final resp = await _client.post(
      Uri.parse('$baseUrl/api/v1/pair/confirm'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, _extractError(resp.body));
    }
  }

  /// GET /api/v1/pair/poll?token=...
  Future<PollResponse> pollStatus(String token) async {
    final resp = await _client.get(
      Uri.parse('$baseUrl/api/v1/pair/poll?token=$token'),
      headers: {'User-Agent': 'NextConnect-App/0.1.0'},
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, _extractError(resp.body));
    }
    return PollResponse.fromJson(jsonDecode(resp.body));
  }

  String _extractError(String body) {
    try {
      return jsonDecode(body)['error'] as String? ?? 'unknown error';
    } catch (_) {
      return 'unknown error';
    }
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}