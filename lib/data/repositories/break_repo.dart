import 'dart:math';

import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../db/database.dart';
import '../seed/builtin_breaks.dart';

class BreakRepo {
  BreakRepo(this._db);

  final AppDatabase _db;

  /// Riscrive le pause di sistema dal codice. Upsert, non delete+insert:
  /// le assegnazioni nei compiti (FK) restano intatte. Le copie non si toccano.
  Future<void> syncBuiltins([List<BreakActivity>? builtins]) =>
      _db.transaction(() async {
        for (final b in builtins ?? builtinBreaks) {
          await _write(b);
        }
      });

  Future<List<BreakActivity>> loadAll() async {
    final rows = await _db.select(_db.breakActivities).get();
    final moveRows = await (_db.select(_db.breakMoves)
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();

    final movesByBreak = <String, List<BreakMove>>{};
    for (final m in moveRows) {
      movesByBreak.putIfAbsent(m.breakId, () => []).add(BreakMove(
            label: m.label,
            seconds: m.seconds,
            pictogram: PictogramRef(m.pictogramSource, m.pictogramRef),
          ));
    }

    final builtinOrder = {
      for (var i = 0; i < builtinBreaks.length; i++) builtinBreaks[i].id: i,
    };
    final visible = rows
        .where((r) => movesByBreak[r.id]?.isNotEmpty ?? false)
        // Una pausa di sistema tolta dal codice non si mostra più.
        .where((r) => !r.isBuiltin || builtinOrder.containsKey(r.id))
        .toList()
      ..sort((a, b) {
        if (a.isBuiltin != b.isBuiltin) return a.isBuiltin ? -1 : 1;
        if (a.isBuiltin) return builtinOrder[a.id]!.compareTo(builtinOrder[b.id]!);
        return a.createdAt.compareTo(b.createdAt);
      });

    return [
      for (final r in visible)
        BreakActivity(
          id: r.id,
          name: r.name,
          kind: r.kind,
          space: r.spaceRequired,
          isBuiltin: r.isBuiltin,
          copiedFrom: r.copiedFrom,
          pictogram: PictogramRef(r.pictogramSource, r.pictogramRef),
          moves: movesByBreak[r.id]!,
        ),
    ];
  }

  Stream<List<BreakActivity>> watchAll() async* {
    yield await loadAll();
    await for (final _ in _db.tableUpdates(
        TableUpdateQuery.onAllTables([_db.breakActivities, _db.breakMoves]))) {
      yield await loadAll();
    }
  }

  /// Salva una pausa dell'adulto. Id vuoto = nuova. Restituisce l'id.
  Future<String> save(BreakActivity activity) async {
    assert(!activity.isBuiltin, 'Le pause di sistema non si modificano');
    final withId = activity.id.isEmpty
        ? activity.copyWith(id: newBreakId())
        : activity;
    final pictogram = withId.moves.first.pictogram;
    await _db.transaction(() => _write(withId.copyWith(pictogram: pictogram)));
    return withId.id;
  }

  /// Copia modificabile di una pausa (anche di sistema).
  Future<String> duplicate(BreakActivity source) {
    final name = '${source.name} (copia)';
    return save(BreakActivity(
      id: '',
      name: name.length > 60 ? name.substring(0, 60) : name,
      kind: source.kind,
      space: source.space,
      moves: source.moves,
      pictogram: source.pictogram,
      copiedFrom: source.isBuiltin ? source.id : source.copiedFrom,
    ));
  }

  /// Le pause di sistema non sono cancellabili.
  Future<void> delete(String id) => (_db.delete(_db.breakActivities)
        ..where((t) => t.id.equals(id) & t.isBuiltin.equals(false)))
      .go();

  Future<void> _write(BreakActivity b) async {
    await _db.into(_db.breakActivities).insertOnConflictUpdate(
          BreakActivitiesCompanion.insert(
            id: b.id,
            name: b.name,
            kind: b.kind,
            spaceRequired: b.space,
            isBuiltin: Value(b.isBuiltin),
            copiedFrom: Value(b.copiedFrom),
            pictogramSource: b.pictogram.source,
            pictogramRef: b.pictogram.ref,
          ),
        );
    await (_db.delete(_db.breakMoves)..where((t) => t.breakId.equals(b.id)))
        .go();
    for (var i = 0; i < b.moves.length; i++) {
      final m = b.moves[i];
      await _db.into(_db.breakMoves).insert(BreakMovesCompanion.insert(
            breakId: b.id,
            position: i,
            label: m.label,
            seconds: m.seconds,
            pictogramSource: m.pictogram.source,
            pictogramRef: m.pictogram.ref,
          ));
    }
  }
}

String newBreakId() {
  final random = Random.secure();
  final hex = List.generate(
      8, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  return 'own_$hex';
}
