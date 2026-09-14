import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/enums.dart';
import 'tables.dart';

part 'database.g.dart';

// Nessuna tabella sessions / events / progress: scelta deliberata (spec §7).
@DriftDatabase(
  tables: [
    Profiles,
    Tasks,
    TaskSteps,
    BreakActivities,
    BreakMoves,
    TaskBreaks,
    ArasaacCache,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() =>
      driftDatabase(name: 'pausa_attiva');
}
