import 'enums.dart';
import 'models.dart';

/// Rotazione deterministica delle pause tra i tre tipi (spec §7.1):
/// intervallo 0 attivazione, 1 scarico, 2 rientro calmo, 3 attivazione...
/// Dentro ogni tipo scorre le pause nell'ordine della libreria.
/// Mai casuale: il bambino deve poter anticipare.
///
/// Esclude le pause che richiedono spazio: il precompilato deve funzionare
/// in qualunque aula. L'adulto le può scegliere a mano.
List<BreakActivity> rotateBreaks(List<BreakActivity> library, int gaps) {
  if (gaps <= 0) return const [];

  final byKind = <BreakKind, List<BreakActivity>>{
    for (final kind in BreakKind.values)
      kind: library
          .where((b) => b.kind == kind && b.space != SpaceRequired.spazio)
          .toList(),
  };
  final available = BreakKind.values.where((k) => byKind[k]!.isNotEmpty).toList();
  if (available.isEmpty) return const [];

  final used = {for (final kind in BreakKind.values) kind: 0};
  return List.generate(gaps, (gap) {
    final kind = available[gap % available.length];
    final pool = byKind[kind]!;
    final pick = pool[used[kind]! % pool.length];
    used[kind] = used[kind]! + 1;
    return pick;
  });
}
