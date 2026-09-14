import 'package:flutter_tts/flutter_tts.dart';

/// Voce italiana on-device. Fail-silent: se il TTS non è disponibile
/// (test, emulatori senza engine) l'app non deve rompersi.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _configure() async {
    // iOS: categoria playback = suona anche con l'interruttore silenzioso;
    // istanza condivisa per non farsi silenziare da altre app (spec §9).
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.duckOthers],
      );
    } catch (_) {
      // Android o piattaforma senza queste API.
    }
    await _tts.setLanguage('it-IT');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _configured = true;
  }

  Future<void> speak(String text) async {
    try {
      if (!_configured) await _configure();
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // TTS non disponibile: silenzio, nessun crash.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
