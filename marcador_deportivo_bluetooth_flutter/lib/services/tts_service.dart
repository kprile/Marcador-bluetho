import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool isEnabled = true;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("es-419"); // Español Latinoamericano
    await _tts.setSpeechRate(0.52); // Velocidad natural de árbitro
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.98); // Tono ligeramente más grave para sonar humano

    // Intentar seleccionar voz neuronal de alta calidad (Google Network Voice)
    try {
      final List<dynamic>? voices = await _tts.getVoices;
      if (voices != null) {
        for (var voice in voices) {
          final Map<dynamic, dynamic> v = voice as Map<dynamic, dynamic>;
          final String name = (v['name'] ?? '').toString().toLowerCase();
          final String locale = (v['locale'] ?? '').toString().toLowerCase();

          if (locale.startsWith('es') && (name.contains('network') || name.contains('natural') || name.contains('neural'))) {
            await _tts.setVoice({"name": v['name'], "locale": v['locale']});
            break;
          }
        }
      }
    } catch (_) {
      // Usar voz predeterminada del sistema
    }
  }

  Future<void> speak(String text) async {
    if (!isEnabled || text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> testSpeaker() async {
    await speak("Prueba de altavoz Bluetooth. Treinta iguales. Punto de oro para la pareja receptora.");
  }
}
