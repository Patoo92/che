import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class CheWebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  // TODO: Reemplazar con IP real de Tailscale
  static const String _backendUrl = 'ws://100.x.x.x:8000/ws';

  Future<void> connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_backendUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final msg = json.decode(data as String) as Map<String, dynamic>;
            _messageController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _reconnect();
        },
        onError: (error) {
          _isConnected = false;
          _reconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) connect();
    });
  }

  void sendMessage(String text) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(json.encode({
        'type': 'message',
        'text': text,
      }));
    }
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
