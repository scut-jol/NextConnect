import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class NCScannerScreen extends StatefulWidget {
  final ApiService apiService;

  const NCScannerScreen({super.key, required this.apiService});

  @override
  State<NCScannerScreen> createState() => _NCScannerScreenState();
}

class _NCScannerScreenState extends State<NCScannerScreen> {
  final _manualController = TextEditingController();
  bool _loading = false;
  String? _status;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('绑定设备'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Camera preview placeholder
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FF41).withOpacity(0.5), width: 2),
                color: Colors.black,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: const Color(0xFF00FF41).withOpacity(0.3), size: 80),
                    const SizedBox(height: 16),
                    Text('扫描 Linux 终端上的二维码', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Manual token input
            Text('或者手动输入配对码', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),

            Row(
              children: [
                const Text('NC-', style: TextStyle(color: Colors.grey, fontSize: 18, fontFamily: 'monospace')),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                      color: Colors.grey[900],
                    ),
                    child: TextField(
                      controller: _manualController,
                      style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 3, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'XXXXXX',
                        hintStyle: TextStyle(color: Colors.grey[700], letterSpacing: 3),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      inputFormatters: [
                        UpperCaseTextFormatter(),
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onSubmitted: (v) => _confirmPairing('NC-$v'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF00FF41)),
                  onPressed: () => _confirmPairing('NC-${_manualController.text}'),
                ),
              ],
            ),

            const SizedBox(height: 16),
            if (_status != null) _buildStatus(),
            if (_loading) const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(color: Color(0xFF00FF41)),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final isError = _status!.contains('失败') || _status!.contains('错误');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isError ? const Color(0xFFFF4444).withOpacity(0.1) : const Color(0xFF00FF41).withOpacity(0.1),
        border: Border.all(
          color: isError ? const Color(0xFFFF4444).withOpacity(0.3) : const Color(0xFF00FF41).withOpacity(0.3),
        ),
      ),
      child: Text(
        _status!,
        style: TextStyle(color: isError ? const Color(0xFFFF4444) : const Color(0xFF00FF41), fontSize: 14),
      ),
    );
  }

  Future<void> _confirmPairing(String pairingToken) async {
    if (pairingToken.length != 9) { // "NC-" + 6 chars
      setState(() => _status = '请输入 6 位配对码');
      return;
    }
    setState(() { _loading = true; _status = null; });

    try {
      await widget.apiService.confirmPairing(pairingToken);
      if (!mounted) return;
      setState(() { _status = '✅ 绑定成功！设备已添加到您的账号'; _loading = false; });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _status = '❌ 绑定失败: $e'; _loading = false; });
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}