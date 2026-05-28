import 'package:flutter/material.dart';

class NCDeviceListScreen extends StatelessWidget {
  const NCDeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              // TODO: navigate to QR scanner
            },
          ),
        ],
      ),
      body: Center(
        child: Text('Device list - not yet implemented',
          style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}