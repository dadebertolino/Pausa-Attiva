import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pausa_attiva/core/providers.dart';
import 'package:pausa_attiva/data/repositories/settings_repo.dart';
import 'package:pausa_attiva/data/seed/builtin_breaks.dart';
import 'package:pausa_attiva/domain/enums.dart';
import 'package:pausa_attiva/domain/models.dart';
import 'package:pausa_attiva/domain/movement_manifest.dart';
import 'package:pausa_attiva/features/sessione/session_screen.dart';

const _task = TaskTemplate(
  title: 'Scheda',
  timerMode: TimerMode.step,
  workSeconds: 300,
  blocksCount: 2,
  useBreaks: true,
  steps: [
    TaskStep(label: 'Leggi il testo', pictogram: PictogramRef.own('marcia_sul_posto')),
    TaskStep(label: 'Rispondi', pictogram: PictogramRef.own('marcia_sul_posto')),
  ],
  breakIds: ['respiro_quadrato'],
);

Future<void> _pumpSession(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    manifestProvider.overrideWithValue(MovementManifest.parse(
        File('assets/pictograms/own/manifest.json').readAsStringSync())),
    documentsDirProvider.overrideWithValue(Directory.systemTemp),
    breaksProvider.overrideWith((ref) => Stream.value(builtinBreaks)),
    settingsProvider.overrideWith(
        (ref) => Stream.value(const AppSettings(voice: false, sounds: false))),
  ]);
  addTearDown(container.dispose);
  container.listen(breaksProvider, (_, _) {});
  container.listen(settingsProvider, (_, _) {});
  await container.read(breaksProvider.future);
  await container.read(settingsProvider.future);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: SessionScreen(task: _task)),
  ));
  await tester.pump();
}

void main() {
  for (final (name, size) in [
    ('telefono verticale', const Size(780, 1690)),
    ('tablet orizzontale', const Size(2360, 1640)),
  ]) {
    testWidgets('lavoro → "Fatto" → pausa guidata, $name', (tester) async {
      await _pumpSession(tester, size);

      expect(find.text('Leggi il testo'), findsOneWidget);
      expect(find.text('Fatto'), findsOneWidget);

      await tester.tap(find.text('Fatto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Etichetta del movimento (+ nome nel segnaposto finché manca il disegno).
      expect(find.text('Respiro quadrato'), findsWidgets);
      expect(find.text('Inspira'), findsOneWidget);
      expect(find.text('Salta'), findsOneWidget);
      expect(find.text('Cambia'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Smonta la schermata: ferma timer e ticker.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
