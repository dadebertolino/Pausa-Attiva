import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pausa_attiva/data/seed/builtin_breaks.dart';
import 'package:pausa_attiva/domain/break_rotation.dart';
import 'package:pausa_attiva/domain/enums.dart';
import 'package:pausa_attiva/domain/movement_manifest.dart';

void main() {
  final manifest = MovementManifest.parse(
      File('assets/pictograms/own/manifest.json').readAsStringSync());

  group('manifest', () {
    test('12 movimenti', () {
      expect(manifest.movements, hasLength(12));
    });

    test('repeat alterna le pose secondo le durate', () {
      final m = manifest['spingi_i_palmi']!; // 1000 ms, 4000 ms
      expect(m.frameIndexAt(Duration.zero), 0);
      expect(m.frameIndexAt(const Duration(milliseconds: 999)), 0);
      expect(m.frameIndexAt(const Duration(milliseconds: 1000)), 1);
      expect(m.frameIndexAt(const Duration(milliseconds: 5000)), 0);
    });

    test('pingpong torna indietro senza ripetere gli estremi', () {
      final m = manifest['pollice_tocca_le_dita']!;
      expect(m.cycle, [0, 1, 2, 3, 2, 1]);
    });

    test('posa unica resta ferma', () {
      expect(manifest['testa_sul_banco']!.frameIndexAt(const Duration(hours: 1)), 0);
    });
  });

  group('pause di sistema', () {
    test('12 pause + 2 circuiti, id unici', () {
      expect(builtinBreaks, hasLength(14));
      expect(builtinBreaks.map((b) => b.id).toSet(), hasLength(14));
    });

    test('ogni movimento ha un pittogramma nel manifest', () {
      for (final b in builtinBreaks) {
        for (final m in b.moves) {
          expect(manifest[m.pictogram.ref], isNotNull,
              reason: '${b.id} → ${m.pictogram.ref}');
        }
      }
    });

    test('durate dei circuiti come da spec §13', () {
      int total(String id) =>
          builtinBreaks.firstWhere((b) => b.id == id).totalSeconds;
      expect(total('circuito_da_fermo_e_in_movimento'), 90);
      expect(total('circuito_ricarica_calma'), 110);
    });
  });

  group('rotazione', () {
    test('alterna i tipi ed esclude le pause che richiedono spazio', () {
      final picks = rotateBreaks(builtinBreaks, 5);
      expect(picks.map((b) => b.kind), [
        BreakKind.attivazione,
        BreakKind.scarico,
        BreakKind.rientroCalmo,
        BreakKind.attivazione,
        BreakKind.scarico,
      ]);
      expect(picks.any((b) => b.space == SpaceRequired.spazio), isFalse);
      // Dentro lo stesso tipo non si ripete la stessa pausa.
      expect(picks[0].id, isNot(picks[3].id));
    });

    test('deterministica', () {
      expect(rotateBreaks(builtinBreaks, 4).map((b) => b.id),
          rotateBreaks(builtinBreaks, 4).map((b) => b.id));
    });
  });
}
