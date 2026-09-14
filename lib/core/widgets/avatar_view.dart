import 'package:flutter/material.dart';

/// Avatar disegnati inclusi nell'app (brief §7). Nessuna foto (spec §4).
const avatarIds = [
  'gatto',
  'cane',
  'volpe',
  'gufo',
  'orso',
  'coniglio',
  'tartaruga',
  'riccio',
];

/// Il colore di sfondo lo mette il codice: il disegno è solo la sagoma.
const _avatarColors = {
  'gatto': Color(0xFF7986CB),
  'cane': Color(0xFF4DB6AC),
  'volpe': Color(0xFFFF8A65),
  'gufo': Color(0xFFA1887F),
  'orso': Color(0xFF90A4AE),
  'coniglio': Color(0xFFF06292),
  'tartaruga': Color(0xFF81C784),
  'riccio': Color(0xFFFFD54F),
};

class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.avatarId, this.size = 48});

  final String avatarId;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _avatarColors[avatarId] ?? const Color(0xFFBDBDBD),
        ),
        padding: EdgeInsets.all(size * 0.12),
        child: Image.asset(
          'assets/avatars/avatar_$avatarId.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              avatarId.isEmpty ? '?' : avatarId[0].toUpperCase(),
              style: TextStyle(
                fontSize: size * 0.45,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
}
