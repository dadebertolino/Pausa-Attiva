import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/repositories/break_repo.dart';
import '../data/repositories/profile_repo.dart';
import '../data/repositories/settings_repo.dart';
import '../data/repositories/task_repo.dart';
import '../data/services/arasaac_api.dart';
import '../data/services/pdf_export.dart';
import '../data/services/sound_service.dart';
import '../data/services/tts_service.dart';
import '../domain/models.dart';
import '../domain/movement_manifest.dart';

// Provider root inizializzati in main() prima di runApp e passati come override.

final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError('override in main'));

final documentsDirProvider =
    Provider<Directory>((ref) => throw UnimplementedError('override in main'));

final manifestProvider = Provider<MovementManifest>(
    (ref) => throw UnimplementedError('override in main'));

// Repository e servizi.

final breakRepoProvider =
    Provider<BreakRepo>((ref) => BreakRepo(ref.watch(databaseProvider)));

final taskRepoProvider =
    Provider<TaskRepo>((ref) => TaskRepo(ref.watch(databaseProvider)));

final profileRepoProvider =
    Provider<ProfileRepo>((ref) => ProfileRepo(ref.watch(databaseProvider)));

final settingsRepoProvider =
    Provider<SettingsRepo>((ref) => SettingsRepo(ref.watch(databaseProvider)));

final arasaacApiProvider = Provider<ArasaacApi>((ref) =>
    ArasaacApi(ref.watch(databaseProvider), ref.watch(documentsDirProvider)));

final ttsProvider = Provider<TtsService>((ref) => TtsService());

final soundProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});

final pdfExportProvider = Provider<PdfExportService>((ref) => PdfExportService(
      api: ref.watch(arasaacApiProvider),
      manifest: ref.watch(manifestProvider),
    ));

// Stato osservabile.

final settingsProvider = StreamProvider<AppSettings>(
    (ref) => ref.watch(settingsRepoProvider).watch());

final breaksProvider = StreamProvider<List<BreakActivity>>(
    (ref) => ref.watch(breakRepoProvider).watchAll());

final tasksProvider = StreamProvider<List<TaskTemplate>>(
    (ref) => ref.watch(taskRepoProvider).watchAll());

final profilesProvider = StreamProvider<List<Profile>>(
    (ref) => ref.watch(profileRepoProvider).watchAll());

/// Modalità adulto sbloccata dal gate. Si richiude quando parte una sessione.
final adultModeProvider = StateProvider<bool>((ref) => false);
