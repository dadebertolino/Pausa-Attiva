import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../domain/models.dart';
import 'providers.dart';

/// Apre l'anteprima di stampa del sistema (stampa, salva PDF, condividi).
Future<void> printTaskSheet(
  BuildContext context,
  WidgetRef ref,
  TaskTemplate task,
) {
  final library = {
    for (final b in ref.read(breaksProvider).valueOrNull ?? const <BreakActivity>[])
      b.id: b,
  };
  return _print(
    context,
    'Compito - ${task.title}',
    () => ref.read(pdfExportProvider).taskSheet(task, library),
  );
}

Future<void> printBreakCards(
  BuildContext context,
  WidgetRef ref,
  List<BreakActivity> breaks, {
  String name = 'Pause attive',
}) =>
    _print(context, name, () => ref.read(pdfExportProvider).breakCards(breaks));

Future<void> _print(
  BuildContext context,
  String name,
  Future<Uint8List> Function() build,
) async {
  final messenger = ScaffoldMessenger.of(context)
    ..showSnackBar(const SnackBar(
      content: Text('Preparo la stampa…'),
      duration: Duration(seconds: 2),
    ));
  try {
    final bytes = await build();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  } catch (_) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Stampa non riuscita. Riprova.')));
  }
}
