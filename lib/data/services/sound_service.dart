import 'package:audioplayers/audioplayers.dart';

/// Segnali sonori della sessione (spec §6). Due suoni soli, sempre uguali:
/// nessun suono festoso, nessuna variazione (spec §3).
enum AppSound {
  /// Poco prima della fine di un blocco o di una pausa.
  preavviso,

  /// Ogni cambio di fase: inizio lavoro, inizio pausa, fine compito.
  cambio,
}

/// Fail-silent come la voce: senza audio l'app non deve rompersi.
class SoundService {
  final Map<AppSound, AudioPlayer> _players = {};

  Future<void> play(AppSound sound) async {
    try {
      final player = _players[sound] ?? await _create(sound);
      await player.stop();
      await player.play(AssetSource('sounds/${sound.name}.wav'));
    } catch (_) {
      // Audio non disponibile: si prosegue in silenzio.
    }
  }

  Future<AudioPlayer> _create(AppSound sound) async {
    final player = AudioPlayer(playerId: 'pausa_attiva_${sound.name}');
    // Si mescola alla voce invece di interromperla; suona anche con
    // l'interruttore silenzioso, come la voce (spec §9).
    await player.setAudioContext(AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
      respectSilence: false,
    ).build());
    await player.setReleaseMode(ReleaseMode.stop);
    _players[sound] = player;
    return player;
  }

  Future<void> dispose() async {
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}
