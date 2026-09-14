import 'package:flutter/material.dart';

/// Respiro quadrato 4-4-4-4 (spec §13, n. 9): un punto percorre il perimetro,
/// un lato per fase. Disegnato nel codice sopra la sagoma (brief §6, n. 9).
class BreathingSquare extends StatelessWidget {
  const BreathingSquare({
    super.key,
    required this.elapsed,
    required this.color,
    this.size = 200,
    this.phaseSeconds = 4,
  });

  final Duration elapsed;
  final Color color;
  final double size;
  final int phaseSeconds;

  static const phases = ['Inspira', 'Trattieni', 'Espira', 'Trattieni'];

  @override
  Widget build(BuildContext context) {
    final phaseMs = phaseSeconds * 1000;
    final t = elapsed.inMilliseconds % (phaseMs * 4);
    final phase = t ~/ phaseMs;
    final progress = (t % phaseMs) / phaseMs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _SquarePainter(
                phase: phase, progress: progress, color: color),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          phases[phase],
          style: TextStyle(
              fontSize: size * 0.14, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

class _SquarePainter extends CustomPainter {
  _SquarePainter({
    required this.phase,
    required this.progress,
    required this.color,
  });

  final int phase;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = size.width * 0.08;
    final corners = [
      Offset(inset, inset),
      Offset(size.width - inset, inset),
      Offset(size.width - inset, size.height - inset),
      Offset(inset, size.height - inset),
    ];
    final stroke = size.width * 0.03;

    canvas.drawRect(
      Rect.fromPoints(corners[0], corners[2]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = const Color(0xFFE0E0E0),
    );

    final from = corners[phase];
    final to = corners[(phase + 1) % 4];
    final dot = Offset.lerp(from, to, progress)!;

    canvas.drawLine(
      from,
      dot,
      Paint()
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(dot, stroke * 1.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SquarePainter old) =>
      old.phase != phase || old.progress != progress || old.color != color;
}
