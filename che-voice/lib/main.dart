import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String serverUrl = 'ws://100.78.234.8:8000/ws/voice';
const String wakeWord = 'che';
const String notificationChannelId = 'che_service';
const String notificationChannelName = 'CHE';
const int notificationId = 888;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  runApp(const CheApp());
}

Future<void> _initNotifications() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    notificationChannelName,
    description: 'CHE voice assistant',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

class CheApp extends StatelessWidget {
  const CheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHE',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
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
  String _status = 'Iniciando...';
  String _lastCommand = '';
  String _lastResponse = '';
  bool _isListening = false;

  VoskFlutterPlugin? _vosk;
  Model? _model;
  SpeechService? _speechService;
  WebSocketChannel? _channel;
  final FlutterTts _tts = FlutterTts();

  bool _awaitingCommand = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _listeningForWakeWord = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _showForegroundNotification();

      setState(() => _status = 'Configurando voz...');
      await _tts.setLanguage('es-AR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() {
        print('[CHE] TTS finished, listening again...');
        _isSpeaking = false;
        _startWakeWordListening();
      });

      setState(() => _status = 'Pidiendo permisos...');

      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          setState(() => _status = 'Permiso de micrófono denegado');
          return;
        }
      }

      setState(() => _status = 'Conectando al server...');
      _connectWs();

      setState(() => _status = 'Cargando modelo de voz...');
      _vosk = VoskFlutterPlugin.instance();
      final modelLoader = ModelLoader();

      final modelsList = await modelLoader.loadModelsList();
      print('[CHE] Models: ${modelsList.map((m) => m.name).join(', ')}');

      final modelDesc = modelsList.firstWhere(
        (m) => m.name == 'vosk-model-small-es-0.42',
        orElse: () => modelsList.first,
      );
      print('[CHE] Loading: ${modelDesc.name}');

      final modelPath = await modelLoader.loadFromNetwork(modelDesc.url);
      print('[CHE] Model downloaded');

      final model = await _vosk!.createModel(modelPath);
      _model = model;
      print('[CHE] Model created');

      await _startWakeWordListening();
    } catch (e, stack) {
      print('[CHE] Init error: $e');
      print('[CHE] Stack: $stack');
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _startWakeWordListening() async {
    try {
      if (_speechService != null) {
        await _speechService!.stop();
        await _speechService!.dispose();
        await Future.delayed(const Duration(milliseconds: 200));
        _speechService = null;
      }

      final recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: ['che', 'ok che', 'ey che'],
      );
      print('[CHE] Grammar recognizer created for wake word');

      _speechService = await _vosk!.initSpeechService(recognizer);
      print('[CHE] Speech service ready (grammar mode)');

      _listeningForWakeWord = true;

      _speechService!.onPartial().listen((partial) {
        if (!_listeningForWakeWord) return;
        String text = partial;
        try {
          final json = jsonDecode(partial);
          text = json['partial'] ?? json['text'] ?? partial;
        } catch (_) {}
        if (text.isNotEmpty) {
          print('[CHE] Wake partial: "$text"');
        }
      });

      _speechService!.onResult().listen((result) {
        if (!_listeningForWakeWord) return;
        String text = result;
        try {
          final json = jsonDecode(result);
          text = json['text'] ?? result;
        } catch (_) {}
        print('[CHE] Wake result: "$text"');

        if (text.trim().toLowerCase().contains(wakeWord)) {
          print('[CHE] Wake word detected!');
          _listeningForWakeWord = false;
          setState(() {
            _status = 'Escuchando...';
            _lastCommand = '';
          });
          _startCommandListening();
        }
      });

      await _speechService!.start();
      _isListening = true;
      setState(() => _status = 'Escuchando "che"...');
    } catch (e) {
      print('[CHE] Wake word init error: $e');
      setState(() => _status = 'Error wake: $e');
    }
  }

  Future<void> _startCommandListening() async {
    try {
      if (_speechService != null) {
        await _speechService!.stop();
        await _speechService!.dispose();
        await Future.delayed(const Duration(milliseconds: 200));
        _speechService = null;
      }

      final recognizer = await _vosk!.createRecognizer(
        model: _model!,
        sampleRate: 16000,
      );
      print('[CHE] Free recognizer created for command');

      _speechService = await _vosk!.initSpeechService(recognizer);
      print('[CHE] Speech service ready (free mode)');

      _awaitingCommand = true;

      _speechService!.onPartial().listen((partial) {
        if (!_awaitingCommand) return;
        String text = partial;
        try {
          final json = jsonDecode(partial);
          text = json['partial'] ?? json['text'] ?? partial;
        } catch (_) {}
        if (text.isNotEmpty) {
          print('[CHE] Command partial: "$text"');
          setState(() => _lastCommand = text);
        }
      });

      _speechService!.onResult().listen((result) {
        if (!_awaitingCommand) return;
        String text = result;
        try {
          final json = jsonDecode(result);
          text = json['text'] ?? result;
        } catch (_) {}
        print('[CHE] Command result: "$text"');

        final command = text.trim();
        if (command.isNotEmpty) {
          _awaitingCommand = false;
          setState(() {
            _lastCommand = command;
            _status = 'Procesando...';
          });
          _isProcessing = true;
          _channel?.sink.add(jsonEncode({
            'type': 'transcript',
            'text': command,
          }));
        }
      });

      await _speechService!.start();
      print('[CHE] Listening for command...');
    } catch (e) {
      print('[CHE] Command init error: $e');
    }
  }

  void _connectWs() {
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        final type = data['type'];

        if (type == 'response') {
          final text = data['text'] ?? '';
          setState(() {
            _lastResponse = text;
            _status = 'Hablando...';
          });
          _isProcessing = false;
          _isSpeaking = true;
          _speak(text);
        } else if (type == 'status') {
          _isProcessing = data['text'] == 'procesando';
        } else if (type == 'error') {
          _isProcessing = false;
          setState(() => _status = 'Error: ${data['text']}');
        }
      },
      onDone: () {
        print('[CHE] WS disconnected, reconnecting...');
        Future.delayed(const Duration(seconds: 3), _connectWs);
      },
      onError: (error) {
        print('[CHE] WS error: $error');
        Future.delayed(const Duration(seconds: 3), _connectWs);
      },
    );
    print('[CHE] WebSocket connecting...');
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    print('[CHE] Speaking: $text');
    await _tts.speak(text);
  }

  void _showForegroundNotification() async {
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'CHE',
      'Escuchando...',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          notificationChannelName,
          icon: 'ic_bg_service_small',
          ongoing: true,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CHE',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isListening ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: _isListening ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              if (_lastCommand.isNotEmpty) ...[
                const Text(
                  'Vos:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastCommand,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.cyan,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_lastResponse.isNotEmpty) ...[
                const Text(
                  'CHE:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastResponse,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
