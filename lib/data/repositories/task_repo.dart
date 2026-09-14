import 'package:drift/drift.dart';

import '../../domain/models.dart';
import '../db/database.dart';

class TaskRepo {
  TaskRepo(this._db);

  final AppDatabase _db;

  Future<List<TaskTemplate>> loadAll() async {
    final taskRows = await (_db.select(_db.tasks)
          ..orderBy([
            (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .get();
    final stepRows = await (_db.select(_db.taskSteps)
          ..orderBy([(t) => OrderingTerm(expression: t.position)]))
        .get();
    final breakRows = await _db.select(_db.taskBreaks).get();

    final stepsByTask = <int, List<TaskStep>>{};
    for (final s in stepRows) {
      stepsByTask.putIfAbsent(s.taskId, () => []).add(TaskStep(
            label: s.label,
            pictogram: PictogramRef(s.pictogramSource, s.pictogramRef),
          ));
    }
    final breaksByTask = <int, Map<int, String>>{};
    for (final b in breakRows) {
      breaksByTask.putIfAbsent(b.taskId, () => {})[b.position] = b.breakId;
    }

    return [
      for (final t in taskRows)
        if (stepsByTask[t.id]?.isNotEmpty ?? false)
          _toTemplate(t, stepsByTask[t.id]!, breaksByTask[t.id] ?? const {}),
    ];
  }

  Stream<List<TaskTemplate>> watchAll() async* {
    yield await loadAll();
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables(
        [_db.tasks, _db.taskSteps, _db.taskBreaks, _db.breakActivities]))) {
      yield await loadAll();
    }
  }

  Future<TaskTemplate?> load(int id) async {
    final all = await loadAll();
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Salva il template con step e pause. Restituisce l'id.
  Future<int> save(TaskTemplate task) => _db.transaction(() async {
        final companion = TasksCompanion(
          profileId: Value(task.profileId),
          title: Value(task.title),
          timerMode: Value(task.timerMode),
          workSeconds: Value(task.workSeconds),
          blocksCount: Value(task.effectiveBlocks),
          useBreaks: Value(task.useBreaks),
          updatedAt: Value(DateTime.now()),
        );

        final int id;
        if (task.id == null) {
          id = await _db.into(_db.tasks).insert(companion);
        } else {
          id = task.id!;
          await (_db.update(_db.tasks)..where((t) => t.id.equals(id)))
              .write(companion);
          await (_db.delete(_db.taskSteps)..where((t) => t.taskId.equals(id)))
              .go();
          await (_db.delete(_db.taskBreaks)..where((t) => t.taskId.equals(id)))
              .go();
        }

        for (var i = 0; i < task.steps.length; i++) {
          final s = task.steps[i];
          await _db.into(_db.taskSteps).insert(TaskStepsCompanion.insert(
                taskId: id,
                position: i,
                label: s.label,
                pictogramSource: s.pictogram.source,
                pictogramRef: s.pictogram.ref,
              ));
        }
        for (var gap = 0; gap < task.gapCount; gap++) {
          final breakId = gap < task.breakIds.length ? task.breakIds[gap] : null;
          if (breakId == null) continue;
          await _db.into(_db.taskBreaks).insert(TaskBreaksCompanion.insert(
                taskId: id,
                position: gap,
                breakId: breakId,
              ));
        }
        return id;
      });

  Future<void> delete(int id) =>
      (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();

  TaskTemplate _toTemplate(
    TaskRow row,
    List<TaskStep> steps,
    Map<int, String> breaks,
  ) {
    final template = TaskTemplate(
      id: row.id,
      profileId: row.profileId,
      title: row.title,
      timerMode: row.timerMode,
      workSeconds: row.workSeconds,
      blocksCount: row.blocksCount,
      useBreaks: row.useBreaks,
      steps: steps,
    );
    return template.copyWith(
      breakIds: List.generate(template.gapCount, (gap) => breaks[gap]),
    );
  }
}
