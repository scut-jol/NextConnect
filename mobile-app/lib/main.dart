import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/device_list_screen.dart';

final AuthService authService = AuthService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await authService.init();
  runApp(const NextConnectApp());
}

class NextConnectApp extends StatefulWidget {
  const NextConnectApp({super.key});

  @override
  State<NextConnectApp> createState() => _NextConnectAppState();
}

class _NextConnectAppState extends State<NextConnectApp> {
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    if (authService.token != null) {
      _apiService!.setToken(authService.token!);
    }
  }

  @override
  void dispose() {
    _apiService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF00FF41),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          secondary: Color(0xFF00FF41),
        ),
      ),
      home: authService.isLoggedIn && _apiService != null
          ? NCDeviceListScreen(apiService: _apiService!, authService: authService)
          : const NCLoginScreen(),
    );
  }
}