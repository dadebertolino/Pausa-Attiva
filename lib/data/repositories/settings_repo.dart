import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/constants.dart';
import '../db/database.dart';

abstract final class SettingsKeys {
  static const voice = 'voce';
  static const sounds = 'suoni';
  static const warningSeconds = 'preavviso_secondi';
  static const activeProfile = 'profilo_attivo';
  static const pinHash = 'gate_pin_hash';
}

class AppSettings {
  const AppSettings({
    this.voice = true,
    this.sounds = true,
    this.warningSeconds = K.warningSecondsDefault,
    this.activeProfileId,
    this.pinHash,
  });

  factory AppSettings.fromMap(Map<String, String> map) => AppSettings(
        voice: map[SettingsKeys.voice] != 'false',
        sounds: map[SettingsKeys.sounds] != 'false',
        warningSeconds: (int.tryParse(map[SettingsKeys.warningSeconds] ?? '') ??
                K.warningSecondsDefault)
            .clamp(K.warningSecondsMin, K.warningSecondsMax),
        activeProfileId: int.tryParse(map[SettingsKeys.activeProfile] ?? ''),
        pinHash: map[SettingsKeys.pinHash],
      );

  final bool voice;
  final bool sounds;
  final int warningSeconds;
  final int? activeProfileId;

  /// `sale:sha256(sale+pin)`. Mai il PIN in chiaro.
  final String? pinHash;

  bool get hasPin => pinHash != null;
}

class SettingsRepo {
  SettingsRepo(this._db);

  final AppDatabase _db;

  Stream<AppSettings> watch() => _db.select(_db.settings).watch().map(
      (rows) => AppSettings.fromMap({for (final r in rows) r.key: r.value}));

  Future<void> put(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> remove(String key) =>
      (_db.delete(_db.settings)..where((t) => t.key.equals(key))).go();

  Future<void> setPin(String pin) => put(SettingsKeys.pinHash, hashPin(pin));

  Future<void> clearPin() => remove(SettingsKeys.pinHash);
}

String hashPin(String pin, {String? salt}) {
  final s = salt ??
      base64Url.encode(List.generate(16, (_) => Random.secure().nextInt(256)));
  final digest = sha256.convert(utf8.encode('$s$pin'));
  return '$s:$digest';
}

bool verifyPin(String pin, String stored) {
  final separator = stored.indexOf(':');
  if (separator <= 0) return false;
  return hashPin(pin, salt: stored.substring(0, separator)) == stored;
}
