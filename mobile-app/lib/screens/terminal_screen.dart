import 'package:flutter/material.dart';

class NCTerminalScreen extends StatelessWidget {
  const NCTerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        actions: [
          // TODO: Ctrl, Alt, Esc, Tab shortcut keys toolbar
        ],
      ),
      body: Center(
        child: Text('Terminal screen - not yet implemented',
          style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}