import 'package:flutter_test/flutter_test.dart';
import 'package:pausa_attiva/domain/enums.dart';
import 'package:pausa_attiva/domain/models.dart';
import 'package:pausa_attiva/domain/session_engine.dart';

const _p = PictogramRef.arasaac('1');

TaskTemplate _task({
  TimerMode mode = TimerMode.blocco,
  int workSeconds = 60,
  int blocks = 2,
  int steps = 3,
  bool useBreaks = true,
}) =>
    TaskTemplate(
      title: 'Test',
      timerMode: mode,
      workSeconds: workSeconds,
      blocksCount: blocks,
      useBreaks: useBreaks,
      steps: List.generate(steps, (i) => TaskStep(label: 'S$i', pictogram: _p)),
    );

BreakActivity _break(String id, List<int> moveSeconds) => BreakActivity(
      id: id,
      name: id,
      kind: BreakKind.scarico,
      space: SpaceRequired.banco,
      pictogram: const PictogramRef.own('x'),
      moves: [
        for (var i = 0; i < moveSeconds.length; i++)
          BreakMove(
              label: 'M$i',
              seconds: moveSeconds[i],
              pictogram: const PictogramRef.own('x')),
      ],
    );

final t0 = DateTime(2026, 10, 1, 9);
DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

void main() {
  group('modalità blocco', () {
    test('blocco → preavviso → pausa → blocco → fine', () {
      final e = SessionEngine(
        task: _task(),
        breaksByGap: [_break('b', [10, 20])],
        fallbackBreaks: const [],
        warningSeconds: 10,
      );
      expect(e.start(t0).single, isA<WorkStarted>());

      expect(e.tick(at(49)), isEmpty);
      expect(e.tick(at(50)).single, isA<WarningStarted>());
      expect(e.snapshot.warning, isTrue);

      final toPause = e.tick(at(60));
      expect(toPause.whereType<PauseStarted>().single.activity.id, 'b');
      expect(e.snapshot.phase, SessionPhase.pause);
      expect(e.snapshot.tokensFilled, 1);
      expect(e.snapshot.phaseDuration, const Duration(seconds: 30));

      final move = e.tick(at(71));
      expect(move.whereType<MoveStarted>().single.index, 1);
      expect(e.snapshot.moveElapsed, const Duration(seconds: 1));

      final back = e.tick(at(90));
      expect(back.whereType<WorkStarted>().single.blockIndex, 1);
      // Al rientro si riprende dallo stesso step.
      expect(e.snapshot.stepIndex, 0);

      expect(e.tick(at(150)).single, isA<SessionFinished>());
      expect(e.snapshot.phase, SessionPhase.finished);
      expect(e.snapshot.tokensFilled, 2);
    });

    test('"fatto" avanza lo step, non il blocco', () {
      final e = SessionEngine(
        task: _task(),
        breaksByGap: const [],
        fallbackBreaks: const [],
        warningSeconds: 10,
      )..start(t0);
      expect(e.stepDone(at(5)).single, isA<StepChanged>());
      expect(e.snapshot.stepIndex, 1);
      expect(e.snapshot.blockIndex, 0);
    });

    test('tutti gli step fatti → fine subito, gettoni completi', () {
      final e = SessionEngine(
        task: _task(steps: 2, blocks: 3),
        breaksByGap: const [],
        fallbackBreaks: const [],
        warningSeconds: 10,
      )..start(t0);
      e.stepDone(at(5));
      expect(e.stepDone(at(6)).single, isA<SessionFinished>());
      expect(e.snapshot.tokensFilled, 3);
    });

    test('senza pause si passa direttamente al blocco dopo', () {
      final e = SessionEngine(
        task: _task(useBreaks: false),
        breaksByGap: [_break('b', [10])],
        fallbackBreaks: const [],
        warningSeconds: 10,
      )..start(t0);
      final events = e.tick(at(60));
      expect(events.whereType<PauseStarted>(), isEmpty);
      expect(events.whereType<WorkStarted>().single.blockIndex, 1);
    });

    test('senza pausa assegnata usa la rotazione di ripiego', () {
      final e = SessionEngine(
        task: _task(blocks: 3),
        breaksByGap: [null, null],
        fallbackBreaks: [_break('f0', [10]), _break('f1', [10])],
        warningSeconds: 10,
      )..start(t0);
      expect(e.tick(at(60)).whereType<PauseStarted>().single.activity.id, 'f0');
      e.tick(at(70));
      expect(e.tick(at(130)).whereType<PauseStarted>().single.activity.id, 'f1');
    });
  });

  group('modalità step', () {
    test('ogni step è un blocco; "fatto" chiude il blocco in anticipo', () {
      final e = SessionEngine(
        task: _task(mode: TimerMode.step, blocks: 99, steps: 2),
        breaksByGap: [_break('b', [10])],
        fallbackBreaks: const [],
        warningSeconds: 10,
      );
      e.start(t0);
      expect(e.totalBlocks, 2);

      final events = e.stepDone(at(5));
      expect(events.whereType<PauseStarted>(), hasLength(1));
      expect(e.snapshot.tokensFilled, 1);

      e.tick(at(15));
      expect(e.snapshot.phase, SessionPhase.work);
      expect(e.snapshot.stepIndex, 1);
    });
  });

  group('tempo', () {
    test('un salto lungo (app in background) attraversa più fasi', () {
      final e = SessionEngine(
        task: _task(blocks: 3),
        breaksByGap: [_break('a', [10]), _break('b', [10])],
        fallbackBreaks: const [],
        warningSeconds: 10,
      )..start(t0);
      e.tick(at(85)); // 60 lavoro + 10 pausa + 15 nel secondo blocco
      expect(e.snapshot.phase, SessionPhase.work);
      expect(e.snapshot.blockIndex, 1);
      expect(e.snapshot.phaseElapsed, const Duration(seconds: 15));
    });

    test('in pausa il tempo non scorre', () {
      final e = SessionEngine(
        task: _task(),
        breaksByGap: const [],
        fallbackBreaks: const [],
        warningSeconds: 10,
      )..start(t0);
      e.tick(at(10));
      e.pause(at(20));
      e.tick(at(500));
      e.resume(at(500));
      e.tick(at(505));
      expect(e.snapshot.phaseElapsed, const Duration(seconds: 25));
      expect(e.snapshot.blockIndex, 0);
    });

    test('nessun preavviso se la fase è più corta del preavviso', () {
      final e = SessionEngine(
        task: _task(workSeconds: 8),
        breaksByGap: const [],
        fallbackBreaks: const [],
        warningSeconds: 10,
      )..start(t0);
      expect(e.tick(at(3)).whereType<WarningStarted>(), isEmpty);
    });
  });

  group('controlli in pausa', () {
    SessionEngine inPause() {
      final e = SessionEngine(
        task: _task(),
        breaksByGap: [_break('b', [30])],
        fallbackBreaks: const [],
        warningSeconds: 10,
      )..start(t0);
      e.tick(at(60));
      return e;
    }

    test('salta torna al lavoro', () {
      final e = inPause();
      expect(e.skipPause(at(65)).whereType<WorkStarted>(), hasLength(1));
      expect(e.snapshot.blockIndex, 1);
    });

    test('cambia riparte con la nuova pausa da zero', () {
      final e = inPause();
      e.replacePause(_break('c', [20]), at(70));
      expect(e.snapshot.activity!.id, 'c');
      expect(e.snapshot.phaseElapsed, Duration.zero);
    });
  });
}
