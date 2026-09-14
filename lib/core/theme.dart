import 'package:flutter/material.dart';

/// Colori di fase. Lavoro e pausa devono distinguersi a colpo d'occhio (§6).
abstract final class AppColors {
  static const work = Color(0xFF3949AB);
  static const workSurface = Color(0xFFE8EAF6);
  static const pause = Color(0xFFEF6C00);
  static const pauseSurface = Color(0xFFFFF3E0);
  static const warning = Color(0xFFFFB300);
  static const track = Color(0xFFE0E0E0);
}

ThemeData buildTheme() => ThemeData(
      colorSchemeSeed: AppColors.work,
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );

/// "30 s", "5 min", "1 min 30 s".
String formatSeconds(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m == 0) return '$s s';
  if (s == 0) return '$m min';
  return '$m min $s s';
}
