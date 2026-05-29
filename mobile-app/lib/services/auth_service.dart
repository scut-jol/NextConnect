import 'package:shared_preferences/shared_preferences.dart';

/// Manages JWT token persistence across app restarts.
class AuthService {
  static const _tokenKey = 'nc_jwt_token';
  static const _namespaceKey = 'nc_namespace';
  static const _userIdKey = 'nc_user_id';
  static const _phoneKey = 'nc_phone';

  String? token;
  String? namespace;
  int? userId;
  String? phone;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    namespace = prefs.getString(_namespaceKey);
    userId = prefs.getInt(_userIdKey);
    phone = prefs.getString(_phoneKey);
  }

  Future<void> saveLogin({
    required String token,
    required String namespace,
    required int userId,
    String phone = '',
  }) async {
    this.token = token;
    this.namespace = namespace;
    this.userId = userId;
    this.phone = phone;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_namespaceKey, namespace);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_phoneKey, phone);
  }

  Future<void> logout() async {
    token = null;
    namespace = null;
    userId = null;
    phone = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_namespaceKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_phoneKey);
  }
}