import 'package:audioplayers/audioplayers.dart';

class CheTtsService {
  final AudioPlayer _player = AudioPlayer();

  // TODO: Reemplazar con IP real de Tailscale
  static const String _ttsUrl = 'http://100.x.x.x:8000/tts';

  Future<void> speak(String text) async {
    try {
      await _player.play(
        UrlSource('$_ttsUrl?texto=${Uri.encodeComponent(text)}'),
      );
    } catch (e) {
      // Si no hay conexión al servidor, silenciar error
    }
  }

  void dispose() {
    _player.dispose();
  }
}
