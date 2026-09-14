import 'dart:math' as math;

import 'enums.dart';

/// Riferimento polimorfico a un pittogramma (spec §7).
/// `own`: id del movimento nel manifest. `arasaac`: id numerico come stringa.
class PictogramRef {
  const PictogramRef(this.source, this.ref);
  const PictogramRef.own(this.ref) : source = PictogramSource.own;
  const PictogramRef.arasaac(this.ref) : source = PictogramSource.arasaac;

  final PictogramSource source;
  final String ref;

  @override
  bool operator ==(Object other) =>
      other is PictogramRef && other.source == source && other.ref == ref;

  @override
  int get hashCode => Object.hash(source, ref);
}

class BreakMove {
  const BreakMove({
    required this.label,
    required this.seconds,
    required this.pictogram,
  });

  final String label;
  final int seconds;
  final PictogramRef pictogram;

  BreakMove copyWith({String? label, int? seconds, PictogramRef? pictogram}) =>
      BreakMove(
        label: label ?? this.label,
        seconds: seconds ?? this.seconds,
        pictogram: pictogram ?? this.pictogram,
      );
}

/// Pausa attiva. Sempre almeno un movimento; durata = somma dei movimenti.
class BreakActivity {
  const BreakActivity({
    required this.id,
    required this.name,
    required this.kind,
    required this.space,
    required this.moves,
    required this.pictogram,
    this.isBuiltin = false,
    this.copiedFrom,
  });

  final String id;
  final String name;
  final BreakKind kind;
  final SpaceRequired space;
  final List<BreakMove> moves;
  final PictogramRef pictogram;
  final bool isBuiltin;
  final String? copiedFrom;

  int get totalSeconds => moves.fold(0, (sum, m) => sum + m.seconds);
  bool get isCircuit => moves.length > 1;

  BreakActivity copyWith({
    String? id,
    String? name,
    BreakKind? kind,
    SpaceRequired? space,
    List<BreakMove>? moves,
    PictogramRef? pictogram,
    bool? isBuiltin,
    String? copiedFrom,
  }) =>
      BreakActivity(
        id: id ?? this.id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        space: space ?? this.space,
        moves: moves ?? this.moves,
        pictogram: pictogram ?? this.pictogram,
        isBuiltin: isBuiltin ?? this.isBuiltin,
        copiedFrom: copiedFrom ?? this.copiedFrom,
      );
}

class TaskStep {
  const TaskStep({required this.label, required this.pictogram});

  final String label;
  final PictogramRef pictogram;
}

/// Template di compito (spec §7, regole in §7.1).
class TaskTemplate {
  const TaskTemplate({
    this.id,
    this.profileId,
    required this.title,
    required this.timerMode,
    required this.workSeconds,
    required this.blocksCount,
    required this.useBreaks,
    required this.steps,
    this.breakIds = const [],
  });

  final int? id;
  final int? profileId;
  final String title;
  final TimerMode timerMode;
  final int workSeconds;
  final int blocksCount;
  final bool useBreaks;
  final List<TaskStep> steps;

  /// Pausa per ogni intervallo tra blocchi, indicizzata per intervallo.
  /// Null = nessuna pausa assegnata: la sessione usa la rotazione.
  final List<String?> breakIds;

  /// In modalità `step` ogni step è un blocco.
  int get effectiveBlocks =>
      timerMode == TimerMode.step ? steps.length : blocksCount;

  int get gapCount => useBreaks ? math.max(0, effectiveBlocks - 1) : 0;

  TaskTemplate copyWith({
    int? id,
    int? Function()? profileId,
    String? title,
    TimerMode? timerMode,
    int? workSeconds,
    int? blocksCount,
    bool? useBreaks,
    List<TaskStep>? steps,
    List<String?>? breakIds,
  }) =>
      TaskTemplate(
        id: id ?? this.id,
        profileId: profileId != null ? profileId() : this.profileId,
        title: title ?? this.title,
        timerMode: timerMode ?? this.timerMode,
        workSeconds: workSeconds ?? this.workSeconds,
        blocksCount: blocksCount ?? this.blocksCount,
        useBreaks: useBreaks ?? this.useBreaks,
        steps: steps ?? this.steps,
        breakIds: breakIds ?? this.breakIds,
      );
}

class Profile {
  const Profile({this.id, required this.nickname, required this.avatarId});

  final int? id;

  /// personal
  final String nickname;
  final String avatarId;
}
