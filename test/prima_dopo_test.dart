import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pausa_attiva/core/constants.dart';
import 'package:pausa_attiva/core/providers.dart';
import 'package:pausa_attiva/data/db/database.dart';
import 'package:pausa_attiva/data/services/arasaac_api.dart';
import 'package:pausa_attiva/domain/movement_manifest.dart';
import 'package:pausa_attiva/features/prima_dopo/prima_dopo_screen.dart';

/// PNG 1×1 trasparente.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// ARASAAC finto: nessuna rete, file già su disco.
class _FakeArasaac extends ArasaacApi {
  _FakeArasaac(super.db, super.dir);

  static const _results = {
    'zaino': ArasaacPictogram(id: 101, keyword: 'zaino', sex: false, violence: false),
    'pullman': ArasaacPictogram(id: 202, keyword: 'pullman', sex: false, violence: false),
  };

  @override
  Future<List<ArasaacPictogram>> search(String text, {String lang = 'it'}) async =>
      [if (_results[text.trim()] != null) _results[text.trim()]!];

  @override
  Future<File> download(int id, {int res = K.resUi}) async => localFile(id, res: res);
}

void main() {
  late Directory dir;
  late AppDatabase db;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pausa_attiva_test');
    for (final id in [101, 202]) {
      File('${dir.path}/media/arasaac/${id}_${K.resUi}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(_png);
    }
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// Frame brevi e ripetuti: un solo pump lungo non completa le transizioni.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> choose(WidgetTester tester, String word) async {
    await tester.tap(find.text('Scegli').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField), word);
    await tester.pump(K.searchDebounce);
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(GridView), matching: find.text(word)));
    await settle(tester);
  }

  testWidgets('Prima/Dopo: scegli, mostra, ingrandisci, chiudi', (tester) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      documentsDirProvider.overrideWithValue(dir),
      manifestProvider.overrideWithValue(MovementManifest.parse(
          File('assets/pictograms/own/manifest.json').readAsStringSync())),
      arasaacApiProvider.overrideWith((ref) => _FakeArasaac(db, dir)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PrimaDopoScreen()),
    ));

    await choose(tester, 'zaino');
    expect(tester.takeException(), isNull);
    await choose(tester, 'pullman');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mostra'));
    await settle(tester);
    // Il selettore mette la maiuscola all'etichetta.
    expect(find.text('Pullman'), findsOneWidget);

    // Ingrandisci "Dopo", poi torna ai due riquadri.
    await tester.tap(find.text('Pullman'));
    await settle(tester);
    await tester.tap(find.text('Pullman'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Chiudi'));
    await settle(tester);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
