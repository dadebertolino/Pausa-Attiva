import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';

/// Pulsante che scatta solo dopo una pressione prolungata (spec §7.1):
/// l'adulto agisce senza uscire dal flusso, il bambino non lo tocca per caso.
/// Il riempimento mostra quanto manca.
class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onConfirmed,
    this.color,
    this.duration = K.sessionLongPress,
  });

  final String label;
  final IconData icon;
  final VoidCallback onConfirmed;
  final Color? color;
  final Duration duration;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            HapticFeedback.mediumImpact();
            _controller.reset();
            widget.onConfirmed();
          }
        });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: '${widget.label}, tieni premuto',
      onLongPress: widget.onConfirmed,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Container(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: color, width: 2),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.35), Colors.transparent],
                stops: [_controller.value, _controller.value],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: color),
                    const SizedBox(width: 8),
                    Text(widget.label,
                        style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                Text('tieni premuto',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.8), fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
