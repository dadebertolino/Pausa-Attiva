import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants.dart';
import '../../core/labels.dart';
import '../../core/theme.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../../domain/movement_manifest.dart';
import 'arasaac_api.dart';

/// Stampa / PDF (spec §4.9). Stessa grafica dell'app: l'insegnante che
/// plastifica le schede deve poter continuare a farlo (spec §5).
class PdfExportService {
  PdfExportService({
    required this.api,
    required this.manifest,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final ArasaacApi api;
  final MovementManifest manifest;
  final AssetBundle _bundle;

  static const _grey = PdfColor.fromInt(0xFF757575);
  static const _line = PdfColor.fromInt(0xFFBDBDBD);

  /// L'attribuzione ARASAAC si decide sui pittogrammi presenti nella pagina,
  /// non sul tipo di scheda (spec §4.9): una pausa dell'adulto con un
  /// pittogramma ARASAAC la richiede.
  static bool needsAttribution(Iterable<PictogramRef> pictograms) =>
      pictograms.any((p) => p.source == PictogramSource.arasaac);

  /// Scheda del compito: step in fila, pause assegnate sotto. A4 orizzontale.
  Future<Uint8List> taskSheet(
    TaskTemplate task,
    Map<String, BreakActivity> library,
  ) async {
    final doc = pw.Document(theme: await _theme(), title: task.title);
    final images = [for (final s in task.steps) await _pictogram(s.pictogram)];
    final breaks = [
      for (var gap = 0; gap < task.gapCount; gap++)
        gap < task.breakIds.length ? library[task.breakIds[gap]] : null,
    ];
    final format = PdfPageFormat.a4.landscape;
    const margin = 36.0;
    final available = format.width - margin * 2;
    final size = ((available - (task.steps.length - 1) * 16) / task.steps.length)
        .clamp(80.0, 200.0);

    doc.addPage(pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(margin),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(task.title,
              style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(_taskSummary(task),
              style: const pw.TextStyle(fontSize: 12, color: _grey)),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < task.steps.length; i++)
                pw.SizedBox(
                  width: size,
                  child: pw.Column(children: [
                    pw.Text('${i + 1}',
                        style: const pw.TextStyle(fontSize: 14, color: _grey)),
                    pw.SizedBox(height: 4),
                    _imageBox(images[i], size, task.steps[i].label),
                    pw.SizedBox(height: 8),
                    pw.Text(task.steps[i].label,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
            ],
          ),
          pw.Spacer(),
          if (breaks.isNotEmpty) ...[
            pw.Divider(color: _line),
            pw.Text('Pause',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (var gap = 0; gap < breaks.length; gap++)
              pw.Text(
                'Dopo il blocco ${gap + 1}: '
                '${breaks[gap] == null ? 'pausa automatica' : '${breaks[gap]!.name} (${formatSeconds(breaks[gap]!.totalSeconds)})'}',
                style: const pw.TextStyle(fontSize: 12),
              ),
          ],
          _footer(needsAttribution(task.steps.map((s) => s.pictogram))),
        ],
      ),
    ));
    return doc.save();
  }

  /// Una scheda A4 verticale per pausa, con le pose affiancate.
  Future<Uint8List> breakCards(List<BreakActivity> activities) async {
    final doc = pw.Document(theme: await _theme(), title: 'Pause attive');
    const format = PdfPageFormat.a4;
    const margin = 40.0;
    final available = format.width - margin * 2;

    for (final activity in activities) {
      final moves = <_MoveImages>[];
      for (final move in activity.moves) {
        moves.add(_MoveImages(move, await _moveImages(move)));
      }
      final sizeByMoves = switch (activity.moves.length) {
        1 => 220.0,
        2 => 170.0,
        _ => 110.0,
      };

      doc.addPage(pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(margin),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(activity.name,
                style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              '${activity.kind.label} · ${activity.space.label} · '
              '${formatSeconds(activity.totalSeconds)}',
              style: const pw.TextStyle(fontSize: 14, color: _grey),
            ),
            pw.SizedBox(height: 24),
            for (var i = 0; i < moves.length; i++) ...[
              if (activity.isCircuit)
                pw.Text(
                  '${i + 1}. ${moves[i].move.label} · ${formatSeconds(moves[i].move.seconds)}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              pw.SizedBox(height: 8),
              _poseRow(moves[i], sizeByMoves, available),
              pw.SizedBox(height: 20),
            ],
            pw.Spacer(),
            _footer(needsAttribution(activity.moves.map((m) => m.pictogram))),
          ],
        ),
      ));
    }
    return doc.save();
  }

  // ---- interno ----

  Future<pw.ThemeData> _theme() async {
    final font = pw.Font.ttf(await _bundle.load('assets/fonts/NotoSans.ttf'));
    return pw.ThemeData.withFont(
        base: font, bold: font, italic: font, boldItalic: font);
  }

  String _taskSummary(TaskTemplate task) => task.timerMode == TimerMode.step
      ? '${task.steps.length} step · ${formatSeconds(task.workSeconds)} per step'
      : '${task.steps.length} step · ${task.blocksCount} '
          '${task.blocksCount == 1 ? 'blocco' : 'blocchi'} da '
          '${formatSeconds(task.workSeconds)}';

  /// Pittogramma singolo: ARASAAC in alta risoluzione se possibile, altrimenti
  /// quella già su disco; per i movimenti propri la prima posa.
  Future<pw.ImageProvider?> _pictogram(PictogramRef p) async =>
      switch (p.source) {
        PictogramSource.arasaac => _arasaac(p.ref),
        PictogramSource.own => _asset(_poseFiles(p.ref).firstOrNull),
        PictogramSource.photo => null,
      };

  Future<List<_Pose>> _moveImages(BreakMove move) async {
    if (move.pictogram.source != PictogramSource.own) {
      return [_Pose(await _pictogram(move.pictogram), move.label)];
    }
    final name = manifest[move.pictogram.ref]?.name ?? move.label;
    final files = _poseFiles(move.pictogram.ref);
    return [
      for (var i = 0; i < files.length; i++)
        _Pose(await _asset(files[i]), '$name\nposa ${i + 1}'),
    ];
  }

  /// File di posa distinti, nell'ordine del manifest.
  List<String> _poseFiles(String movementId) {
    final movement = manifest[movementId];
    if (movement == null) return const [];
    final seen = <String>{};
    return [
      for (final f in movement.frames)
        if (seen.add(f.file)) f.file,
    ];
  }

  Future<pw.ImageProvider?> _arasaac(String ref) async {
    final id = int.tryParse(ref);
    if (id == null) return null;
    try {
      final file = await api.download(id, res: K.resPdf);
      return pw.MemoryImage(await file.readAsBytes());
    } catch (_) {
      // Offline: si ripiega sulla risoluzione già scaricata.
    }
    final local = api.localFile(id);
    if (await local.exists()) return pw.MemoryImage(await local.readAsBytes());
    return null;
  }

  Future<pw.ImageProvider?> _asset(String? file) async {
    if (file == null) return null;
    try {
      final data = await _bundle.load('assets/pictograms/own/$file');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null; // Disegno non ancora consegnato.
    }
  }

  pw.Widget _poseRow(_MoveImages move, double sizeByMoves, double available) {
    final count = move.poses.length;
    const arrow = 28.0;
    final size = ((available - (count - 1) * arrow) / count).clamp(60.0, sizeByMoves);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0)
            pw.SizedBox(
              width: arrow,
              child: pw.Text('→',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 20, color: _grey)),
            ),
          _imageBox(move.poses[i].image, size, move.poses[i].fallback),
        ],
      ],
    );
  }

  pw.Widget _imageBox(pw.ImageProvider? image, double size, String fallback) {
    if (image != null) {
      return pw.Image(image, width: size, height: size, fit: pw.BoxFit.contain);
    }
    return pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Text(fallback,
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 10, color: _grey)),
    );
  }

  pw.Widget _footer(bool arasaac) => arasaac
      ? pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(arasaacAttribution,
              style: const pw.TextStyle(fontSize: 8, color: _grey)),
        )
      : pw.SizedBox();
}

class _Pose {
  const _Pose(this.image, this.fallback);

  final pw.ImageProvider? image;
  final String fallback;
}

class _MoveImages {
  const _MoveImages(this.move, this.poses);

  final BreakMove move;
  final List<_Pose> poses;
}
