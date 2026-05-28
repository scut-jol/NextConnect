import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/device_list_screen.dart';
import 'screens/terminal_screen.dart';

void main() {
  runApp(const NextConnectApp());
}

class NextConnectApp extends StatelessWidget {
  const NextConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF00FF41),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          secondary: Color(0xFF00FF41),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const NCLoginScreen(),
        '/devices': (_) => const NCDeviceListScreen(),
        '/terminal': (_) => const NCTerminalScreen(),
      },
    );
  }
}