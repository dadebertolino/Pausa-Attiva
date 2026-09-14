import '../../domain/enums.dart';
import '../../domain/models.dart';

/// Set iniziale: 12 pause + 2 mini-circuiti (spec §13).
/// Nomi e durate PROVVISORI, da validare in classe. Gli id sono stabili:
/// non cambiarli mai, anche se cambia il nome mostrato.
/// Riscritte nel database a ogni avvio; le copie dell'adulto non si toccano.
BreakActivity _single(
  String id,
  String name,
  BreakKind kind,
  SpaceRequired space,
  int seconds,
) =>
    BreakActivity(
      id: id,
      name: name,
      kind: kind,
      space: space,
      pictogram: PictogramRef.own(id),
      isBuiltin: true,
      moves: [
        BreakMove(label: name, seconds: seconds, pictogram: PictogramRef.own(id)),
      ],
    );

final List<BreakActivity> _singles = [
  // Attivazione
  _single('marcia_sul_posto', 'Marcia sul posto', BreakKind.attivazione,
      SpaceRequired.inPiedi, 30),
  _single('saltelli_a_stella', 'Saltelli a stella', BreakKind.attivazione,
      SpaceRequired.spazio, 20),
  _single('tocca_ginocchio_opposto', 'Tocca il ginocchio opposto',
      BreakKind.attivazione, SpaceRequired.inPiedi, 30),
  _single('alzati_e_siediti', 'Alzati e siediti', BreakKind.attivazione,
      SpaceRequired.banco, 30),
  // Scarico
  _single('spingi_i_palmi', 'Spingi i palmi', BreakKind.scarico,
      SpaceRequired.banco, 20),
  _single('rotazione_spalle', 'Rotazione delle spalle', BreakKind.scarico,
      SpaceRequired.banco, 20),
  _single('mani_verso_i_piedi', 'Mani verso i piedi', BreakKind.scarico,
      SpaceRequired.inPiedi, 20),
  _single('allungati_come_albero', 'Allungati come un albero',
      BreakKind.scarico, SpaceRequired.inPiedi, 20),
  // Rientro calmo
  _single('respiro_quadrato', 'Respiro quadrato', BreakKind.rientroCalmo,
      SpaceRequired.banco, 60),
  _single('pollice_tocca_le_dita', 'Pollice che tocca le dita',
      BreakKind.rientroCalmo, SpaceRequired.banco, 30),
  _single('testa_sul_banco', 'Testa sul banco', BreakKind.rientroCalmo,
      SpaceRequired.banco, 45),
  _single('traccia_forma_col_dito', 'Traccia una forma col dito',
      BreakKind.rientroCalmo, SpaceRequired.banco, 30),
];

BreakActivity _byId(String id) => _singles.firstWhere((b) => b.id == id);

BreakActivity _circuit(
  String id,
  String name,
  BreakKind kind,
  SpaceRequired space,
  List<String> moveIds,
) {
  final moves = [for (final m in moveIds) ..._byId(m).moves];
  return BreakActivity(
    id: id,
    name: name,
    kind: kind,
    space: space,
    pictogram: moves.first.pictogram,
    isBuiltin: true,
    moves: moves,
  );
}

final List<BreakActivity> builtinBreaks = [
  ..._singles,
  // 1 → 2 → 6 → 7, ~90 s. Contiene i saltelli: serve spazio.
  _circuit('circuito_da_fermo_e_in_movimento', 'Da fermo e in movimento',
      BreakKind.attivazione, SpaceRequired.spazio, [
    'marcia_sul_posto',
    'saltelli_a_stella',
    'rotazione_spalle',
    'mani_verso_i_piedi',
  ]),
  // 5 → 9 → 10, ~110 s.
  _circuit('circuito_ricarica_calma', 'Ricarica calma', BreakKind.rientroCalmo,
      SpaceRequired.banco, [
    'spingi_i_palmi',
    'respiro_quadrato',
    'pollice_tocca_le_dita',
  ]),
];
