import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter_service/vosk_flutter_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String serverUrl = 'ws://100.78.234.8:8000/ws/voice';
const String wsSecret = 'drtWCjmGRU9/pAOfvNH9VUtR3w0vME/W5oneIHrxErI=';
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
  final AudioRecorder _recorder = AudioRecorder();

  bool _awaitingCommand = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _listeningForWakeWord = true;
  bool _audioSent = false;
  Timer? _silenceTimer;
  DateTime? _recordingStartTime;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _showForegroundNotification();

      setState(() => _status = 'Configurando voz...');
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      final voices = await _tts.getVoices;
      String? selectedVoice;
      for (final v in voices) {
        final name = v['name'] ?? '';
        final locale = v['locale'] ?? '';
        if (locale.startsWith('es-ES') && name.contains('local')) {
          print('[CHE] TTS voice: $name ($locale)');
          if (selectedVoice == null) selectedVoice = name;
        }
      }
      if (selectedVoice != null) {
        await _tts.setVoice({'name': selectedVoice, 'locale': 'es-ES'});
        print('[CHE] TTS voice selected: $selectedVoice');
      }

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

      final modelDesc = modelsList.firstWhere(
        (m) => m.name == 'vosk-model-small-es-0.42',
        orElse: () => modelsList.firstWhere(
          (m) => m.name == 'vosk-model-es-0.42-lgraph',
          orElse: () => modelsList.first,
        ),
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
            _status = 'Grabando...';
            _lastCommand = '';
          });
          _startRecording();
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

  Future<void> _startRecording() async {
    try {
      if (_speechService != null) {
        await _speechService!.stop();
        await _speechService!.dispose();
        await Future.delayed(const Duration(milliseconds: 200));
        _speechService = null;
      }

      final tempDir = Directory.systemTemp;
      final tempPath = '${tempDir.path}/che_recording.wav';

      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: tempPath,
      );

      _recordingStartTime = DateTime.now();
      _awaitingCommand = true;
      _audioSent = false;
      _startAmplitudeMonitoring();

      print('[CHE] Recording started to $tempPath');
    } catch (e) {
      print('[CHE] Recording error: $e');
      setState(() => _status = 'Error grabando: $e');
    }
  }

  void _startAmplitudeMonitoring() {
    _silenceTimer?.cancel();
    bool hasSpoken = false;
    double peakAmplitude = -100;
    Timer? monitorTimer;

    monitorTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!_awaitingCommand) {
        timer.cancel();
        return;
      }

      try {
        final amplitude = await _recorder.getAmplitude();
        final current = amplitude.current;
        final elapsed = DateTime.now().difference(_recordingStartTime!).inMilliseconds;

        if (current > peakAmplitude) {
          peakAmplitude = current;
        }

        final silenceThreshold = peakAmplitude > -35 ? peakAmplitude - 12 : -55;

        if (current > silenceThreshold && current > -55) {
          if (!hasSpoken) {
            print('[CHE] Speech! peak=${peakAmplitude.toStringAsFixed(1)} current=${current.toStringAsFixed(1)}');
          }
          hasSpoken = true;
          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(seconds: 1), () {
            if (_awaitingCommand) {
              print('[CHE] Silence after speech (peak=${peakAmplitude.toStringAsFixed(1)})');
              _stopRecordingAndSend();
            }
          });
        }

        if (elapsed >= 6000) {
          print('[CHE] Max recording 6s');
          timer.cancel();
          _silenceTimer?.cancel();
          if (hasSpoken) {
            _stopRecordingAndSend();
          } else {
            print('[CHE] No speech, discarding');
            _awaitingCommand = false;
            await _recorder.stop();
            _startWakeWordListening();
          }
        }
      } catch (_) {}
    });

    _silenceTimer = Timer(const Duration(seconds: 4), () {
      if (_awaitingCommand && !hasSpoken) {
        print('[CHE] No speech in 4s, abort');
        monitorTimer?.cancel();
        _awaitingCommand = false;
        _recorder.stop().then((_) => _startWakeWordListening());
      }
    });
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_awaitingCommand || _audioSent) return;
    _awaitingCommand = false;
    _audioSent = true;
    _silenceTimer?.cancel();

    try {
      final path = await _recorder.stop();
      print('[CHE] Recording stopped, path: $path');

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final rawBytes = await file.readAsBytes();
          final bytes = _amplifyPcm16(rawBytes, gain: 4.0);
          if (bytes.length > 500) {
            print('[CHE] Audio: ${bytes.length} bytes (amplified), sending...');

            setState(() => _status = 'Procesando...');
            _isProcessing = true;

            _channel?.sink.add(jsonEncode({
              'type': 'audio',
              'data': base64Encode(bytes),
            }));

            await file.delete();
            return;
          }
          await file.delete();
        }
      }

      print('[CHE] No audio recorded, going back to wake word');
      _isProcessing = false;
      _startWakeWordListening();
    } catch (e) {
      print('[CHE] Stop recording error: $e');
      _isProcessing = false;
      _startWakeWordListening();
    }
  }

  void _connectWs() {
    _channel = WebSocketChannel.connect(Uri.parse('$serverUrl?token=$wsSecret'));
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
        } else if (type == 'transcript') {
          final text = data['text'] ?? '';
          setState(() {
            _lastCommand = text;
          });
          print('[CHE] Whisper transcript: "$text"');
        } else if (type == 'status') {
          final st = data['text'] ?? '';
          if (st == 'procesando') {
            _isProcessing = true;
            setState(() => _status = 'Procesando...');
          } else if (st == 'transcribiendo') {
            setState(() => _status = 'Transcribiendo...');
          }
        } else if (type == 'error') {
          _isProcessing = false;
          setState(() => _status = 'Error: ${data['text']}');
          Future.delayed(const Duration(seconds: 3), _startWakeWordListening);
        }
      },
      onDone: () {
        if (_isProcessing) {
          print('[CHE] WS disconnected while processing, waiting...');
          Future.delayed(const Duration(seconds: 5), _connectWs);
        } else {
          print('[CHE] WS disconnected, reconnecting...');
          Future.delayed(const Duration(seconds: 3), _connectWs);
        }
      },
      onError: (error) {
        print('[CHE] WS error: $error');
        if (!_isProcessing) {
          Future.delayed(const Duration(seconds: 3), _connectWs);
        }
      },
    );
    print('[CHE] WebSocket connecting...');
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    print('[CHE] Speaking: $text');
    await _tts.speak(text);
  }

  Uint8List _amplifyPcm16(Uint8List data, {double gain = 4.0}) {
    final amplified = Int16List(data.length ~/ 2);
    final view = ByteData.view(data.buffer);
    for (var i = 0; i < data.length; i += 2) {
      var sample = view.getInt16(i, Endian.little);
      sample = (sample * gain).clamp(-32768, 32767).toInt();
      amplified[i ~/ 2] = sample;
    }
    return amplified.buffer.asUint8List();
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
    _silenceTimer?.cancel();
    _channel?.sink.close();
    _tts.stop();
    _recorder.dispose();
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
