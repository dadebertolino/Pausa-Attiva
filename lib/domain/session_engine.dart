import 'enums.dart';
import 'models.dart';

/// Motore della sessione (spec §7.1). Dart puro, nessun Flutter, nessun timer
/// interno: riceve l'orario da fuori, così è testabile e resta giusto anche se
/// l'app va in background (il salto di tempo viene consumato al tick dopo).
///
/// Non registra nulla: nessuno storico, nessuna durata effettiva (spec §4).
enum SessionPhase { work, pause, finished }

sealed class SessionEvent {
  const SessionEvent();
}

/// Inizio di un blocco di lavoro.
class WorkStarted extends SessionEvent {
  const WorkStarted(this.blockIndex, this.step);
  final int blockIndex;
  final TaskStep step;
}

/// Cambio di step dentro lo stesso blocco (modalità `blocco`).
class StepChanged extends SessionEvent {
  const StepChanged(this.step);
  final TaskStep step;
}

class PauseStarted extends SessionEvent {
  const PauseStarted(this.activity);
  final BreakActivity activity;
}

class MoveStarted extends SessionEvent {
  const MoveStarted(this.move, this.index);
  final BreakMove move;
  final int index;
}

/// Preavviso di fine blocco o fine pausa.
class WarningStarted extends SessionEvent {
  const WarningStarted(this.phase);
  final SessionPhase phase;
}

class SessionFinished extends SessionEvent {
  const SessionFinished();
}

class SessionSnapshot {
  const SessionSnapshot({
    required this.phase,
    required this.blockIndex,
    required this.totalBlocks,
    required this.stepIndex,
    required this.tokensFilled,
    required this.phaseDuration,
    required this.phaseElapsed,
    required this.paused,
    required this.warning,
    this.activity,
    this.moveIndex = 0,
    this.moveElapsed = Duration.zero,
  });

  final SessionPhase phase;
  final int blockIndex;
  final int totalBlocks;
  final int stepIndex;
  final int tokensFilled;

  /// Lavoro: durata del blocco. Pausa: durata dell'intera pausa.
  final Duration phaseDuration;
  final Duration phaseElapsed;
  final bool paused;
  final bool warning;

  final BreakActivity? activity;
  final int moveIndex;
  final Duration moveElapsed;

  Duration get remaining {
    final r = phaseDuration - phaseElapsed;
    return r.isNegative ? Duration.zero : r;
  }

  /// 1.0 = pieno, 0.0 = vuoto. Il disco si svuota (spec §3).
  double get fractionRemaining => phaseDuration.inMilliseconds <= 0
      ? 0
      : remaining.inMilliseconds / phaseDuration.inMilliseconds;

  BreakMove? get move => activity?.moves[moveIndex];
}

class SessionEngine {
  SessionEngine({
    required this.task,
    required List<BreakActivity?> breaksByGap,
    required List<BreakActivity> fallbackBreaks,
    required int warningSeconds,
  })  : _breaksByGap = breaksByGap,
        _fallback = fallbackBreaks,
        _warning = Duration(seconds: warningSeconds),
        assert(task.steps.isNotEmpty, 'Un compito ha almeno uno step');

  final TaskTemplate task;
  final List<BreakActivity?> _breaksByGap;
  final List<BreakActivity> _fallback;
  final Duration _warning;

  SessionPhase _phase = SessionPhase.work;
  int _block = 0;
  int _step = 0;
  int _tokens = 0;
  int _gap = 0;
  BreakActivity? _activity;
  int _move = 0;
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  bool _warningFired = false;
  DateTime? _lastTick;

  int get totalBlocks => task.effectiveBlocks;
  Duration get _workDuration => Duration(seconds: task.workSeconds);

  List<SessionEvent> start(DateTime now) {
    _lastTick = now;
    return _startWork(0);
  }

  SessionSnapshot get snapshot {
    final isPause = _phase == SessionPhase.pause;
    final duration = switch (_phase) {
      SessionPhase.work => _workDuration,
      SessionPhase.pause => Duration(seconds: _activity!.totalSeconds),
      SessionPhase.finished => Duration.zero,
    };
    return SessionSnapshot(
      phase: _phase,
      blockIndex: _block,
      totalBlocks: totalBlocks,
      stepIndex: _step.clamp(0, task.steps.length - 1),
      tokensFilled: _tokens,
      phaseDuration: duration,
      phaseElapsed: _elapsed,
      paused: _paused,
      warning: _inWarning(duration),
      activity: isPause ? _activity : null,
      moveIndex: isPause ? _move : 0,
      moveElapsed: isPause ? _elapsed - _moveStart(_move) : Duration.zero,
    );
  }

  List<SessionEvent> tick(DateTime now) {
    final last = _lastTick ?? now;
    _lastTick = now;
    if (_paused || _phase == SessionPhase.finished) return const [];
    final delta = now.difference(last);
    if (delta <= Duration.zero) return const [];
    return _advance(delta);
  }

  /// "Fatto" nella fase di lavoro.
  List<SessionEvent> stepDone(DateTime now) {
    final events = [...tick(now)];
    if (_phase != SessionPhase.work || _paused) return events;

    if (task.timerMode == TimerMode.step) {
      return events..addAll(_endBlock());
    }
    _step++;
    if (_step >= task.steps.length) {
      return events..addAll(_finish());
    }
    return events..add(StepChanged(task.steps[_step]));
  }

  List<SessionEvent> skipPause(DateTime now) {
    final events = [...tick(now)];
    if (_phase != SessionPhase.pause) return events;
    return events..addAll(_endPause());
  }

  List<SessionEvent> replacePause(BreakActivity activity, DateTime now) {
    final events = [...tick(now)];
    if (_phase != SessionPhase.pause) return events;
    return events..addAll(_startPause(activity));
  }

  void pause(DateTime now) {
    tick(now);
    _paused = true;
  }

  void resume(DateTime now) {
    _lastTick = now;
    _paused = false;
  }

  // ---- interno ----

  List<SessionEvent> _advance(Duration delta) {
    final events = <SessionEvent>[];
    var left = delta;
    while (_phase != SessionPhase.finished) {
      final duration = _phase == SessionPhase.work
          ? _workDuration
          : Duration(seconds: _activity!.totalSeconds);
      final remaining = duration - _elapsed;
      if (left < remaining) {
        _elapsed += left;
        if (_phase == SessionPhase.pause) _syncMove(events);
        if (!_warningFired && _inWarning(duration)) {
          _warningFired = true;
          events.add(WarningStarted(_phase));
        }
        break;
      }
      left -= remaining;
      _elapsed = duration;
      events.addAll(
          _phase == SessionPhase.work ? _endBlock() : _endPause());
    }
    return events;
  }

  bool _inWarning(Duration duration) =>
      _phase != SessionPhase.finished &&
      duration > _warning &&
      duration - _elapsed <= _warning;

  List<SessionEvent> _startWork(int block) {
    _phase = SessionPhase.work;
    _block = block;
    _elapsed = Duration.zero;
    _warningFired = false;
    if (task.timerMode == TimerMode.step) _step = block;
    return [WorkStarted(block, task.steps[_step.clamp(0, task.steps.length - 1)])];
  }

  List<SessionEvent> _endBlock() {
    _tokens = _block + 1;
    final isLast = _block >= totalBlocks - 1;
    if (isLast) return _finish();

    if (task.useBreaks) {
      final activity = _breakForGap(_block);
      if (activity != null) {
        _gap = _block;
        return _startPause(activity);
      }
    }
    return _startWork(_block + 1);
  }

  List<SessionEvent> _startPause(BreakActivity activity) {
    _phase = SessionPhase.pause;
    _activity = activity;
    _move = 0;
    _elapsed = Duration.zero;
    _warningFired = false;
    return [PauseStarted(activity), MoveStarted(activity.moves.first, 0)];
  }

  List<SessionEvent> _endPause() => _startWork(_gap + 1);

  List<SessionEvent> _finish() {
    _phase = SessionPhase.finished;
    // Gettoni completi: un compito chiuso non è mai "incompleto" (spec §3).
    _tokens = totalBlocks;
    _elapsed = Duration.zero;
    return const [SessionFinished()];
  }

  BreakActivity? _breakForGap(int gap) {
    if (gap < _breaksByGap.length && _breaksByGap[gap] != null) {
      return _breaksByGap[gap];
    }
    if (_fallback.isEmpty) return null;
    return _fallback[gap % _fallback.length];
  }

  Duration _moveStart(int index) => Duration(
      seconds: _activity!.moves
          .take(index)
          .fold(0, (sum, m) => sum + m.seconds));

  void _syncMove(List<SessionEvent> events) {
    final moves = _activity!.moves;
    var index = 0;
    while (index < moves.length - 1 && _elapsed >= _moveStart(index + 1)) {
      index++;
    }
    if (index != _move) {
      _move = index;
      events.add(MoveStarted(moves[index], index));
    }
  }
}
