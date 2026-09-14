import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Il tempo è una quantità, non un numero (spec §3): un disco che si svuota.
/// Nessuna cifra. Il preavviso è un anello ambra, uguale ogni volta.
class TimerDisc extends StatelessWidget {
  const TimerDisc({
    super.key,
    required this.fraction,
    required this.color,
    this.warning = false,
    this.size = 160,
  });

  /// 1.0 pieno, 0.0 vuoto.
  final double fraction;
  final Color color;
  final bool warning;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: warning ? 'Tempo quasi finito' : 'Tempo rimasto',
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _DiscPainter(
              fraction: fraction.clamp(0, 1),
              color: color,
              warning: warning,
            ),
          ),
        ),
      );
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({
    required this.fraction,
    required this.color,
    required this.warning,
  });

  final double fraction;
  final Color color;
  final bool warning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final ring = size.width * 0.06;
    final radius = size.width / 2 - ring;

    canvas.drawCircle(center, radius, Paint()..color = AppColors.track);

    // Settore residuo: parte da ore 12 e si ritira in senso orario.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      -2 * math.pi * fraction,
      true,
      Paint()..color = color,
    );

    canvas.drawCircle(
      center,
      radius + ring / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = warning ? ring : ring * 0.25
        ..color = warning ? AppColors.warning : AppColors.track,
    );
  }

  @override
  bool shouldRepaint(_DiscPainter old) =>
      old.fraction != fraction || old.color != color || old.warning != warning;
}
