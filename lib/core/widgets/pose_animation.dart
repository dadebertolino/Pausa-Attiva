import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import '../providers.dart';

/// Animazione a pose di un movimento del set disegnato (spec §12).
/// Legge pose e tempi dal manifest. Con "riduci movimento" o `animate: false`
/// mostra solo la prima posa. Finché i disegni non ci sono mostra un
/// segnaposto che alterna comunque le pose, per tarare i tempi.
class PoseAnimation extends ConsumerStatefulWidget {
  const PoseAnimation({
    super.key,
    required this.movementId,
    this.size = 200,
    this.animate = true,
  });

  final String movementId;
  final double size;
  final bool animate;

  @override
  ConsumerState<PoseAnimation> createState() => _PoseAnimationState();
}

class _PoseAnimationState extends ConsumerState<PoseAnimation>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  int _frame = 0;

  bool get _shouldAnimate =>
      widget.animate && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(PoseAnimation old) {
    super.didUpdateWidget(old);
    if (old.movementId != widget.movementId || old.animate != widget.animate) {
      _restart();
    }
  }

  void _restart() {
    _ticker.stop();
    _frame = 0;
    if (_shouldAnimate) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final movement = ref.read(manifestProvider)[widget.movementId];
    if (movement == null) return;
    final index = movement.frameIndexAt(elapsed);
    if (index != _frame) setState(() => _frame = index);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movement = ref.watch(manifestProvider)[widget.movementId];
    if (movement == null) {
      return _PosePlaceholder(
          name: widget.movementId, pose: 1, size: widget.size);
    }
    final frame = movement.frames[_frame.clamp(0, movement.frames.length - 1)];
    final pose = _poseNumber(frame.file);

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedSwitcher(
        duration: K.poseCrossfade,
        child: Image.asset(
          'assets/pictograms/own/${frame.file}',
          key: ValueKey(frame.file),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          semanticLabel: movement.name,
          errorBuilder: (_, _, _) => _PosePlaceholder(
            name: movement.name,
            pose: pose,
            size: widget.size,
          ),
        ),
      ),
    );
  }

  static int _poseNumber(String file) =>
      int.tryParse(RegExp(r'_(\d+)\.png$').firstMatch(file)?.group(1) ?? '') ??
      1;
}

/// Segnaposto finché manca il disegno: figura generica che si specchia a
/// ogni posa, nome del movimento e numero di posa.
class _PosePlaceholder extends StatelessWidget {
  const _PosePlaceholder({
    required this.name,
    required this.pose,
    required this.size,
  });

  final String name;
  final int pose;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.08),
          border: Border.all(color: const Color(0xFFBDBDBD)),
        ),
        padding: EdgeInsets.all(size * 0.06),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                child: Transform.flip(
                  flipX: pose.isEven,
                  child: const Icon(Icons.directions_walk, color: Colors.black),
                ),
              ),
            ),
            if (size >= 96) ...[
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: size * 0.07)),
              Text('posa $pose',
                  style: TextStyle(
                      fontSize: size * 0.06, color: const Color(0xFF757575))),
            ],
          ],
        ),
      );
}
