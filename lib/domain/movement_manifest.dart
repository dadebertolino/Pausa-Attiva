import 'dart:convert';

/// Manifest del set disegnato (`assets/pictograms/own/manifest.json`).
/// Nessun riferimento a codice dell'app dentro il manifest (spec §9).
class MovementManifest {
  const MovementManifest(this.movements);

  factory MovementManifest.parse(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    final list = (json['movements'] as List<dynamic>)
        .map((m) => Movement.fromJson(m as Map<String, dynamic>))
        .toList();
    return MovementManifest({for (final m in list) m.id: m});
  }

  final Map<String, Movement> movements;

  Movement? operator [](String id) => movements[id];
}

enum LoopMode { repeat, pingpong }

class PoseFrame {
  const PoseFrame(this.file, this.duration);

  final String file;
  final Duration duration;
}

class Movement {
  const Movement({
    required this.id,
    required this.name,
    required this.tags,
    required this.frames,
    required this.loop,
  });

  factory Movement.fromJson(Map<String, dynamic> json) => Movement(
        id: json['id'] as String,
        name: json['name'] as String,
        tags: (json['tags'] as List<dynamic>).cast<String>(),
        frames: (json['frames'] as List<dynamic>).map((f) {
          final frame = f as Map<String, dynamic>;
          return PoseFrame(
            frame['file'] as String,
            Duration(milliseconds: frame['ms'] as int),
          );
        }).toList(),
        loop: json['loop'] == 'pingpong' ? LoopMode.pingpong : LoopMode.repeat,
      );

  final String id;
  final String name;
  final List<String> tags;
  final List<PoseFrame> frames;
  final LoopMode loop;

  /// Sequenza di indici di posa in un ciclo.
  /// repeat: 0,1,2,3 — pingpong: 0,1,2,3,2,1.
  List<int> get cycle {
    final n = frames.length;
    if (loop == LoopMode.repeat || n <= 2) {
      return List.generate(n, (i) => i);
    }
    return [
      ...List.generate(n, (i) => i),
      ...List.generate(n - 2, (i) => n - 2 - i),
    ];
  }

  /// Indice della posa da mostrare dopo [elapsed] dall'inizio del movimento.
  int frameIndexAt(Duration elapsed) {
    final order = cycle;
    if (order.length <= 1) return 0;
    final cycleMs =
        order.fold<int>(0, (sum, i) => sum + frames[i].duration.inMilliseconds);
    if (cycleMs <= 0) return 0;
    var t = elapsed.inMilliseconds % cycleMs;
    for (final i in order) {
      final ms = frames[i].duration.inMilliseconds;
      if (t < ms) return i;
      t -= ms;
    }
    return order.last;
  }
}
