import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pausa_attiva/core/constants.dart';
import 'package:pausa_attiva/data/db/database.dart';
import 'package:pausa_attiva/data/seed/builtin_breaks.dart';
import 'package:pausa_attiva/data/services/arasaac_api.dart';
import 'package:pausa_attiva/data/services/pdf_export.dart';
import 'package:pausa_attiva/domain/enums.dart';
import 'package:pausa_attiva/domain/models.dart';
import 'package:pausa_attiva/domain/movement_manifest.dart';

/// Offline: il download fallisce sempre, si usa solo ciò che è su disco.
class _OfflineArasaac extends ArasaacApi {
  _OfflineArasaac(super.db, super.dir);

  @override
  Future<File> download(int id, {int res = K.resUi}) =>
      Future.error(ArasaacException('offline'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory dir;
  late PdfExportService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('pdf_test');
    service = PdfExportService(
      api: _OfflineArasaac(db, dir),
      manifest: MovementManifest.parse(
          File('assets/pictograms/own/manifest.json').readAsStringSync()),
    );
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  bool isPdf(List<int> bytes) => ascii.decode(bytes.take(5).toList()) == '%PDF-';

  test('scheda compito con pittogrammi mancanti e pause', () async {
    const task = TaskTemplate(
      title: 'Scheda di matematica',
      timerMode: TimerMode.blocco,
      workSeconds: 300,
      blocksCount: 3,
      useBreaks: true,
      steps: [
        TaskStep(label: 'Leggi', pictogram: PictogramRef.arasaac('100')),
        TaskStep(label: 'Scrivi', pictogram: PictogramRef.arasaac('200')),
        TaskStep(label: 'Consegna', pictogram: PictogramRef.arasaac('300')),
      ],
      breakIds: ['marcia_sul_posto', null],
    );
    final bytes = await service.taskSheet(
        task, {for (final b in builtinBreaks) b.id: b});
    expect(isPdf(bytes), isTrue);
  });

  test('schede di tutte le pause, circuiti compresi', () async {
    final bytes = await service.breakCards(builtinBreaks);
    expect(isPdf(bytes), isTrue);
  });

  test('attribuzione ARASAAC solo se ci sono pittogrammi ARASAAC', () {
    expect(PdfExportService.needsAttribution(
        builtinBreaks.expand((b) => b.moves).map((m) => m.pictogram)), isFalse);
    expect(PdfExportService.needsAttribution(const [
      PictogramRef.own('marcia_sul_posto'),
      PictogramRef.arasaac('100'),
    ]), isTrue);
  });
}
