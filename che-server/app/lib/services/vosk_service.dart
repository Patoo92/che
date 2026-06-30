import 'package:vosk_flutter/vosk_flutter.dart';

class CheVoskService {
  Vosk? _vosk;
  VoskRecognizer? _recognizer;
  bool _isWakeWordDetected = false;
  bool _isInitialized = false;
  final List<String> _wakeWords = ['che'];

  Future<void> init() async {
    if (_isInitialized) return;
    _vosk = Vosk();
    await _vosk!.initialize();

    final model = await _vosk!.createModel('vosk-model-small-es-0.42');

    _recognizer = await model.createRecognizer(
      sampleRate: 16000,
      grammar: _wakeWords,
      partialResults: true,
    );

    _isInitialized = true;
  }

  /// Escucha hasta detectar "Che", luego transcribe el comando.
  Future<String?> listenOnce() async {
    if (!_isInitialized) return null;

    // Modo wake word: escucha hasta detectar "Che"
    while (!_isWakeWordDetected) {
      final result = await _recognizer!.getResult();
      if (result.text.toLowerCase().contains('che')) {
        _isWakeWordDetected = true;
        await _recognizer!.setGrammar(null); // sin restricciones
      }
    }

    // Modo transcripción: escucha el comando completo
    final command = await _recognizer!.getResult();
    _isWakeWordDetected = false;

    // Volver a modo wake word
    await _recognizer!.setGrammar(_wakeWords);
    return command.text;
  }

  void dispose() {
    _recognizer?.dispose();
    _vosk?.dispose();
    _isInitialized = false;
  }
}
