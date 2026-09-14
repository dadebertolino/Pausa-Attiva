import 'package:drift/drift.dart';

import '../../domain/enums.dart';

/// Profilo del bambino. SOLO nickname e avatar disegnato: nessun campo
/// diagnosi, nota o testo libero, mai (spec §4).
@DataClassName('ProfileRow')
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// personal
  TextColumn get nickname => text().withLength(min: 1, max: 40)();

  /// Id di un avatar disegnato incluso nell'app (`assets/avatars/`).
  TextColumn get avatarId => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Template di compito riutilizzabile (spec §7, §7.1).
@DataClassName('TaskRow')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Null = visibile a tutti i profili.
  IntColumn get profileId => integer()
      .nullable()
      .references(Profiles, #id, onDelete: KeyAction.setNull)();

  TextColumn get title => text().withLength(min: 1, max: 80)();
  TextColumn get timerMode => textEnum<TimerMode>()();
  IntColumn get workSeconds => integer()();

  /// In modalità `step` coincide con il numero di step.
  IntColumn get blocksCount => integer()();

  BoolColumn get useBreaks => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('TaskStepRow')
class TaskSteps extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get label => text().withLength(min: 1, max: 60)();
  TextColumn get pictogramSource => textEnum<PictogramSource>()();
  TextColumn get pictogramRef => text()();
}

/// Pause attive: di sistema (id stabile, riscritte a ogni avvio) o create
/// dall'adulto. La durata è la somma dei movimenti (spec §7).
@DataClassName('BreakActivityRow')
class BreakActivities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get kind => textEnum<BreakKind>()();
  TextColumn get spaceRequired => textEnum<SpaceRequired>()();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();

  /// Id della pausa di sistema da cui è stata duplicata.
  TextColumn get copiedFrom => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get pictogramSource => textEnum<PictogramSource>()();
  TextColumn get pictogramRef => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BreakMoveRow')
class BreakMoves extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get breakId =>
      text().references(BreakActivities, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get label => text().withLength(min: 1, max: 60)();
  IntColumn get seconds => integer()();
  TextColumn get pictogramSource => textEnum<PictogramSource>()();
  TextColumn get pictogramRef => text()();
}

/// Pausa assegnata a ogni intervallo tra due blocchi (spec §7.1).
/// Se la pausa viene cancellata la riga sparisce e la sessione usa la
/// rotazione di ripiego.
@DataClassName('TaskBreakRow')
class TaskBreaks extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get breakId =>
      text().references(BreakActivities, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, position};
}

/// Cache ricerche ARASAAC: il picker funziona offline sulle query già fatte.
@DataClassName('ArasaacCacheRow')
class ArasaacCache extends Table {
  TextColumn get query => text()();
  TextColumn get lang => text()();
  TextColumn get resultsJson => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {query, lang};
}

/// Chiave/valore. Chiavi in `SettingsKeys`.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
