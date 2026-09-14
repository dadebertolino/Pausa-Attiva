/// Costanti di prodotto. I default temporali di spec §8 sono DA TARARE IN
/// CLASSE: tutti qui, in un punto solo, per renderli banali da cambiare.
abstract final class K {
  // ---- Default temporali (spec §8) ----

  static const int workSecondsDefault = 5 * 60;
  static const int workSecondsMin = 2 * 60;
  static const int workSecondsMax = 20 * 60;

  static const int blocksDefault = 2;
  static const int blocksMin = 1;
  static const int blocksMax = 6;

  static const int stepsMax = 5;

  static const int warningSecondsDefault = 10;
  static const int warningSecondsMin = 5;
  static const int warningSecondsMax = 30;

  static const int moveSecondsDefault = 30;
  static const int moveSecondsMin = 5;
  static const int moveSecondsMax = 120;

  static const int breakTotalSecondsMin = 20;
  static const int breakTotalSecondsMax = 5 * 60;

  static const int movesMax = 4;

  /// Salta / cambia / pausa in sessione (spec §7.1).
  static const Duration sessionLongPress = Duration(milliseconds: 1500);

  // ---- UI ----

  /// Touch target minimo per ciò che tocca il bambino.
  static const double childMinTouchTarget = 64;

  /// Cambio posa nell'animazione delle pause (brief §3).
  static const Duration poseCrossfade = Duration(milliseconds: 150);

  // ---- ARASAAC ----

  /// Mai una chiamata per keystroke.
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const Duration arasaacCacheTtl = Duration(days: 30);
  static const int resThumb = 300;
  static const int resUi = 500;
  static const int resPdf = 2500;

  static const String appVersion = '1.0.0';
}
