import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/adult_gate.dart';
import '../../core/widgets/breathing_square.dart';
import '../../core/widgets/hold_button.dart';
import '../../core/widgets/pictogram_view.dart';
import '../../core/widgets/timer_disc.dart';
import '../../core/widgets/token_row.dart';
import '../../data/repositories/settings_repo.dart';
import '../../data/services/sound_service.dart';
import '../../data/services/tts_service.dart';
import '../../domain/break_rotation.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../domain/session_engine.dart';

/// Sessione attiva (spec §6, schermate 5, 6, 8). Una cosa sola a schermo:
/// lo step o il movimento corrente e il tempo.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.task});

  final TaskTemplate task;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  late final SessionEngine _engine;
  late final AppSettings _settings;
  late final List<BreakActivity> _library;
  late final TtsService _tts;
  late final SoundService _sound;
  late SessionSnapshot _snap;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Letto qui: in dispose() ref non è più utilizzabile.
    _tts = ref.read(ttsProvider);
    _sound = ref.read(soundProvider);
    _settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
    _library = ref.read(breaksProvider).valueOrNull ?? const [];
    final byId = {for (final b in _library) b.id: b};

    _engine = SessionEngine(
      task: widget.task,
      breaksByGap: [
        for (final id in widget.task.breakIds) id == null ? null : byId[id],
      ],
      fallbackBreaks: rotateBreaks(_library, widget.task.gapCount),
      warningSeconds: _settings.warningSeconds,
    );
    _handle(_engine.start(DateTime.now()));
    _snap = _engine.snapshot;
    _timer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => _run(_engine.tick(DateTime.now())));
    // Fail-silent: senza il plugin (test, piattaforme non supportate) si prosegue.
    unawaited(WakelockPlus.enable().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    unawaited(_tts.stop());
    super.dispose();
  }

  void _run(List<SessionEvent> events) {
    _handle(events);
    if (mounted) setState(() => _snap = _engine.snapshot);
  }

  void _handle(List<SessionEvent> events) {
    for (final event in events) {
      switch (event) {
        case WorkStarted(:final step):
          _phaseChanged(step.label);
        case StepChanged(:final step):
          _say(step.label);
        case PauseStarted(:final activity):
          _phaseChanged(activity.isCircuit
              ? 'Pausa. ${activity.name}. ${activity.moves.first.label}'
              : 'Pausa. ${activity.name}');
        case MoveStarted(:final move, :final index) when index > 0:
          _say(move.label);
        case MoveStarted():
          break;
        case WarningStarted():
          _warn();
        case SessionFinished():
          _phaseChanged('Finito');
      }
    }
  }

  void _say(String text) {
    if (_settings.voice) unawaited(_tts.speak(text));
  }

  /// Ogni cambio di fase è confermato allo stesso modo (spec §6):
  /// stesso suono, poi la voce, così i due non si sovrappongono.
  void _phaseChanged(String announcement) {
    if (!_settings.sounds) {
      _say(announcement);
      return;
    }
    unawaited(_sound.play(AppSound.cambio));
    unawaited(HapticFeedback.mediumImpact());
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _say(announcement);
    }));
  }

  /// Preavviso prima della fine di un blocco o di una pausa.
  void _warn() {
    if (!_settings.sounds) return;
    unawaited(_sound.play(AppSound.preavviso));
    unawaited(HapticFeedback.heavyImpact());
  }

  Future<void> _exit() async {
    if (!await showAdultGate(context, ref)) return;
    if (mounted) Navigator.of(context).pop();
  }

  void _togglePause() {
    final now = DateTime.now();
    _snap.paused ? _engine.resume(now) : _engine.pause(now);
    _run(const []);
  }

  Future<void> _choosePause() async {
    _engine.pause(DateTime.now());
    _run(const []);
    final chosen = await showModalBottomSheet<BreakActivity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PauseChooser(library: _library),
    );
    final now = DateTime.now();
    _engine.resume(now);
    _run(chosen == null ? const [] : _engine.replacePause(chosen, now));
  }

  @override
  Widget build(BuildContext context) {
    final finished = _snap.phase == SessionPhase.finished;
    return PopScope(
      canPop: finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_exit());
      },
      child: Scaffold(
        backgroundColor: switch (_snap.phase) {
          SessionPhase.work => Colors.white,
          SessionPhase.pause => AppColors.pauseSurface,
          SessionPhase.finished => AppColors.workSurface,
        },
        body: SafeArea(
          child: finished
              ? _FinishedView(total: _snap.totalBlocks)
              : Column(
                  children: [
                    _TopBar(
                      paused: _snap.paused,
                      onClose: _exit,
                      onTogglePause: _togglePause,
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: _snap.phase == SessionPhase.work
                                ? _WorkView(
                                    snap: _snap,
                                    task: widget.task,
                                    onDone: () =>
                                        _run(_engine.stepDone(DateTime.now())),
                                  )
                                : _PauseView(
                                    snap: _snap,
                                    onSkip: () =>
                                        _run(_engine.skipPause(DateTime.now())),
                                    onChange: _choosePause,
                                  ),
                          ),
                          if (_snap.paused) const _PausedOverlay(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.paused,
    required this.onClose,
    required this.onTogglePause,
  });

  final bool paused;
  final VoidCallback onClose;
  final VoidCallback onTogglePause;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Esci (area adulti)',
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
            const Spacer(),
            HoldButton(
              label: paused ? 'Riprendi' : 'Ferma',
              icon: paused ? Icons.play_arrow : Icons.pause,
              color: const Color(0xFF616161),
              onConfirmed: onTogglePause,
            ),
          ],
        ),
      );
}

class _PausedOverlay extends StatelessWidget {
  const _PausedOverlay();

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: AbsorbPointer(
          child: ColoredBox(
            color: Colors.white.withValues(alpha: 0.85),
            child: const Center(
              child: Icon(Icons.pause_circle, size: 120, color: Color(0xFF9E9E9E)),
            ),
          ),
        ),
      );
}

/// Adatta la disposizione: affiancata in orizzontale, impilata in verticale.
class _PhaseLayout extends StatelessWidget {
  const _PhaseLayout({required this.main, required this.side});

  final Widget Function(double size) main;
  final List<Widget> side;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth > box.maxHeight;
          final mainSize = landscape
              ? (box.maxHeight * 0.7).clamp(120.0, box.maxWidth * 0.5)
              : (box.maxHeight * 0.4).clamp(120.0, box.maxWidth * 0.8);
          final sideColumn = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: side,
          );
          return Padding(
            padding: const EdgeInsets.all(16),
            child: landscape
                ? Row(children: [
                    Expanded(child: Center(child: main(mainSize))),
                    Expanded(child: sideColumn),
                  ])
                : Column(children: [
                    Expanded(flex: 3, child: Center(child: main(mainSize))),
                    Expanded(flex: 2, child: sideColumn),
                  ]),
          );
        },
      );
}

class _WorkView extends StatelessWidget {
  const _WorkView({required this.snap, required this.task, required this.onDone});

  final SessionSnapshot snap;
  final TaskTemplate task;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final step = task.steps[snap.stepIndex];
    return _PhaseLayout(
      main: (size) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PictogramView(pictogram: step.pictogram, size: size * 0.8),
          const SizedBox(height: 12),
          Text(
            step.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      side: [
        TimerDisc(
          fraction: snap.fractionRemaining,
          color: AppColors.work,
          warning: snap.warning,
          size: 140,
        ),
        const SizedBox(height: 16),
        TokenRow(filled: snap.tokensFilled, total: snap.totalBlocks, size: 28),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(200, 72)),
          onPressed: onDone,
          icon: const Icon(Icons.check, size: 32),
          label: const Text('Fatto', style: TextStyle(fontSize: 26)),
        ),
      ],
    );
  }
}

class _PauseView extends StatelessWidget {
  const _PauseView({
    required this.snap,
    required this.onSkip,
    required this.onChange,
  });

  final SessionSnapshot snap;
  final VoidCallback onSkip;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final activity = snap.activity!;
    final move = snap.move!;
    final isBreathing = move.pictogram.source == PictogramSource.own &&
        move.pictogram.ref == 'respiro_quadrato';

    return _PhaseLayout(
      main: (size) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBreathing)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PictogramView(pictogram: move.pictogram, size: size * 0.5, animate: true),
                const SizedBox(width: 16),
                BreathingSquare(
                  elapsed: snap.moveElapsed,
                  color: AppColors.pause,
                  size: size * 0.4,
                ),
              ],
            )
          else
            PictogramView(
              key: ValueKey('${activity.id}#${snap.moveIndex}'),
              pictogram: move.pictogram,
              size: size * 0.8,
              animate: true,
            ),
          const SizedBox(height: 12),
          Text(
            move.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
          ),
          if (activity.isCircuit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TokenRow(
                filled: snap.moveIndex + 1,
                total: activity.moves.length,
                size: 14,
              ),
            ),
        ],
      ),
      side: [
        TimerDisc(
          fraction: snap.fractionRemaining,
          color: AppColors.pause,
          warning: snap.warning,
          size: 140,
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            HoldButton(
              label: 'Salta',
              icon: Icons.skip_next,
              color: AppColors.pause,
              onConfirmed: onSkip,
            ),
            HoldButton(
              label: 'Cambia',
              icon: Icons.swap_horiz,
              color: AppColors.pause,
              onConfirmed: onChange,
            ),
          ],
        ),
      ],
    );
  }
}

class _PauseChooser extends StatelessWidget {
  const _PauseChooser({required this.library});

  final List<BreakActivity> library;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Scegli un\'altra pausa',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            for (final b in library)
              ListTile(
                leading: PictogramView(pictogram: b.pictogram, size: 48),
                title: Text(b.name),
                subtitle: Text(
                    '${b.kind.label} · ${formatSeconds(b.totalSeconds)} · ${b.space.label}'),
                onTap: () => Navigator.pop(context, b),
              ),
          ],
        ),
      );
}

/// Fine compito: gettoni completi, conferma sobria (spec §6, schermata 8).
class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TokenRow(filled: total, total: total, size: 56),
              const SizedBox(height: 32),
              const Text('Compito finito',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Torna all\'inizio'),
              ),
            ],
          ),
        ),
      );
}
