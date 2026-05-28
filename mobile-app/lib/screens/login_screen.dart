import 'package:flutter/material.dart';

class NCLoginScreen extends StatelessWidget {
  const NCLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'NextConnect',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF00FF41),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Secure P2P Terminal',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 48),
              // TODO: phone number input + SMS code login
              // TODO: WeChat login button
              Text('Login screen - not yet implemented',
                style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}