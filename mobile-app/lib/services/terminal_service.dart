import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart' as ssh;

/// Manages an SSH connection to a paired Linux device over the
/// virtual P2P network (Tailscale IP).
///
/// The connection goes directly to the device's virtual IP on port 22
/// via the local VPN tunnel — no traffic passes through external servers.
class TerminalService {
  ssh.SSHClient? _client;
  ssh.SSHSession? _session;
  StreamSubscription? _stdoutSub;

  bool get isConnected => _client != null;

  /// Connect to [host]:22 using SSH password or key auth.
  ///
  /// [onData] receives stdout bytes as they arrive from the remote shell.
  /// [onError] is called on connection or runtime errors.
  Future<void> connect({
    required String host,
    required String username,
    required String password,
    required void Function(Uint8List data) onData,
    required void Function(String error) onError,
  }) async {
    try {
      final socket = await ssh.SSHClient.connect(
        host,
        port: 22,
        username: username,
        onKeyboardInteractive: (_, __, ___) => [password],
      );

      _client = socket;
      _session = await socket.execute('''bash --login''');

      _stdoutSub = _session!.stdout.listen(
        (data) => onData(data),
        onError: (e) => onError('SSH stream error: $e'),
        onDone: () => disconnect(),
      );
    } catch (e) {
      onError('Connection failed: $e');
    }
  }

  /// Send data to the remote shell (stdin).
  void send(String data) {
    _session?.stdin.add(Uint8List.fromList(utf8.encode(data)));
  }

  /// Send a Ctrl+<key> combination as a single byte.
  void sendControl(int charCode) {
    // Ctrl+A = 0x01, Ctrl+B = 0x02, ..., Ctrl+Z = 0x1A
    final byte = charCode - 64; // 'A' = 1, 'B' = 2, etc.
    _session?.stdin.add(Uint8List.fromList([byte & 0xFF]));
  }

  /// Resize the remote terminal PTY.
  void resize(int columns, int rows) {
    _session?.resizeTerminal(columns, rows);
  }

  /// Close the SSH session and client.
  void disconnect() {
    _stdoutSub?.cancel();
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
  }
}