import 'package:flutter/material.dart';
import 'services/vosk_service.dart';
import 'services/websocket_service.dart';
import 'services/cache_service.dart';
import 'services/tts_service.dart';
import 'widgets/overlay_widget.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CheApp());
}

class CheApp extends StatelessWidget {
  const CheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CheHome(),
    );
  }
}

class CheHome extends StatefulWidget {
  const CheHome({super.key});

  @override
  State<CheHome> createState() => _CheHomeState();
}

class _CheHomeState extends State<CheHome> {
  final CheVoskService _vosk = CheVoskService();
  final CheWebSocketService _ws = CheWebSocketService();
  final CheTtsService _tts = CheTtsService();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isListening = false;
  bool _isOnline = false;
  StreamSubscription? _messageSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _vosk.init();
    await _ws.connect();
    _isOnline = _ws.isConnected;
    _messageSub = _ws.messages.listen((msg) {
      if (msg['type'] == 'response') {
        setState(() {
          _messages.add({'role': 'che', 'text': msg['text']});
        });
        _tts.speak(msg['text']);
        CacheService.guardar('che', msg['text']);
      }
    });
    setState(() {});
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);
    try {
      final texto = await _vosk.listenOnce();
      if (texto == null || texto.isEmpty) return;

      setState(() {
        _messages.add({'role': 'user', 'text': texto});
      });
      await CacheService.guardar('user', texto);

      if (_isOnline) {
        _ws.sendMessage(texto);
      } else {
        setState(() {
          _messages.add({
            'role': 'che',
            'text': 'Estoy offline, cuando conecte sincronizo.'
          });
        });
      }
    } finally {
      setState(() => _isListening = false);
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _controller.dispose();
    _vosk.dispose();
    _ws.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('CHE'),
        actions: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            color: _isOnline ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[800] : Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['text']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Escribí un comando...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        setState(() {
                          _messages.add({'role': 'user', 'text': text});
                        });
                        _ws.sendMessage(text);
                        _controller.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _isListening ? null : _startListening,
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                  child: Icon(_isListening ? Icons.mic : Icons.mic_none),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
