import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../services/terminal_service.dart';

class NCTerminalScreen extends StatefulWidget {
  final String host;
  final String hostname;

  const NCTerminalScreen({
    super.key,
    required this.host,
    required this.hostname,
  });

  @override
  State<NCTerminalScreen> createState() => _NCTerminalScreenState();
}

class _NCTerminalScreenState extends State<NCTerminalScreen> {
  final _terminalService = TerminalService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  String _output = '';
  bool _connected = false;
  String? _error;

  static const String _sshUser = 'root';
  static const String _sshPass = '';

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    await _terminalService.connect(
      host: widget.host,
      username: _sshUser,
      password: _sshPass,
      onData: _onData,
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _error = err;
          _connected = false;
        });
      },
    );
    if (mounted) setState(() => _connected = true);
  }

  void _onData(Uint8List data) {
    final text = String.fromCharCodes(data);
    setState(() {
      _output += text;
      if (_output.length > 100000) {
        _output = _output.substring(_output.length - 50000);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String cmd) {
    if (!_connected) return;
    _terminalService.send(cmd);
  }

  @override
  void dispose() {
    _terminalService.disconnect();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _connected ? const Color(0xFF00FF41) : Colors.red[400],
                boxShadow: _connected
                    ? [BoxShadow(color: const Color(0xFF00FF41).withOpacity(0.5), blurRadius: 6)]
                    : [],
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.hostname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Text(
              widget.host,
              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildTerminalOutput()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _toolbarBtn('Tab', () => _send('\t')),
          _toolbarBtn('Esc', () => _send('\x1b')),
          _toolbarBtn('↑', () => _send('\x1b[A')),
          _toolbarBtn('↓', () => _send('\x1b[B')),
          const SizedBox(width: 8),
          _toolbarBtn('Ctrl', _showCtrlPicker),
          _toolbarBtn('Alt', _showAltPicker),
          const Spacer(),
          // Clear screen
          _toolbarBtn('Clear', () => setState(() => _output = '')),
        ],
      ),
    );
  }

  Widget _toolbarBtn(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: Colors.grey[850],
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }

  void _showCtrlPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _buildKeyPicker('Ctrl +', (char) {
        final code = char.codeUnitAt(0) - 64; // A=1, B=2, ...
        _terminalService.sendControl(code);
        Navigator.pop(context);
      }),
    );
  }

  void _showAltPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _buildKeyPicker('Alt +', (char) {
        _send('\x1b${char}'); // ESC prefix = Alt
        Navigator.pop(context);
      }),
    );
  }

  Widget _buildKeyPicker(String prefix, void Function(String) onSelect) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(prefix, style: const TextStyle(color: Color(0xFF00FF41), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((char) {
              return GestureDetector(
                onTap: () => onSelect(char),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[850],
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: Text(char, style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace')),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTerminalOutput() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Color(0xFFFF4444), size: 48),
              const SizedBox(height: 16),
              Text('连接失败', style: TextStyle(color: Colors.grey[400], fontSize: 18)),
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() { _error = null; _output = ''; });
                  _connect();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF41), foregroundColor: Colors.black),
                child: const Text('重新连接'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_connected) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00FF41)),
            SizedBox(height: 16),
            Text('正在建立 SSH 连接...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SelectableText(
          _output.isEmpty ? '\$ ' : _output,
          style: const TextStyle(color: Color(0xFFE0E0E0), fontFamily: 'monospace', fontSize: 13, height: 1.3),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('\$', style: TextStyle(color: const Color(0xFF00FF41), fontFamily: 'monospace', fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14),
              decoration: InputDecoration(
                hintText: _connected ? 'Enter command...' : 'connecting...',
                hintStyle: TextStyle(color: Colors.grey[700], fontFamily: 'monospace'),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              enabled: _connected,
              onSubmitted: (v) {
                _send('$v\n');
                _inputController.clear();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF00FF41), size: 20),
            onPressed: _connected ? () {
              _send('${_inputController.text}\n');
              _inputController.clear();
            } : null,
          ),
        ],
      ),
    );
  }
}