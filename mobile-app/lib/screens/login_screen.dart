import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/vpn_service.dart';
import '../models/api_types.dart';
import 'device_list_screen.dart';

class NCLoginScreen extends StatefulWidget {
  const NCLoginScreen({super.key});

  @override
  State<NCLoginScreen> createState() => _NCLoginScreenState();
}

class _NCLoginScreenState extends State<NCLoginScreen> {
  final _phoneController = TextEditingController();
  final _apiService = ApiService();
  final _authService = AuthService();
  final _vpnService = VpnService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = '请输入手机号');
      return;
    }
    if (phone.length < 11) {
      setState(() => _error = '请输入完整的 11 位手机号');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _apiService.login(phone);

      await _authService.saveLogin(
        token: resp.token,
        namespace: resp.namespace,
        userId: resp.userId,
        phone: phone,
      );
      _apiService.setToken(resp.token);

      // Activate local VPN tunnel in background
      _vpnService.connect(resp.namespace);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => NCDeviceListScreen(
            apiService: _apiService,
            authService: _authService,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = '登录失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo area
                _buildLogo(),
                const SizedBox(height: 48),
                // Phone input
                _buildPhoneInput(),
                const SizedBox(height: 8),
                if (_error != null) _buildError(),
                const SizedBox(height: 24),
                // Login button
                _buildLoginButton(),
                const SizedBox(height: 16),
                // WeChat login
                _buildWeChatButton(),
                const SizedBox(height: 32),
                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00FF41), width: 2),
          ),
          child: const Center(
            child: Icon(Icons.terminal, color: Color(0xFF00FF41), size: 40),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'NextConnect',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00FF41),
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: const Color(0xFF00FF41).withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Secure P2P Terminal',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
        color: Colors.grey[900],
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        maxLength: 11,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          counterText: '',
          hintText: '手机号',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.phone_android, color: Colors.grey[500]),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text('+86 ', style: TextStyle(color: Colors.grey, fontSize: 18)),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _error!,
        style: const TextStyle(color: Color(0xFFFF4444), fontSize: 13),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF41),
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF00FF41).withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : const Text('获取验证码 / 登录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildWeChatButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          // TODO: implement WeChat OAuth login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('微信登录功能开发中')),
          );
        },
        icon: const Icon(Icons.wechat, color: Color(0xFF07C160)),
        label: const Text('微信一键登录', style: TextStyle(color: Colors.white70)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey[700]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      '登录即表示同意《用户协议》和《隐私政策》',
      style: TextStyle(color: Colors.grey[700], fontSize: 12),
    );
  }
}