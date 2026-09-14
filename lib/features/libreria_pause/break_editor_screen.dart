import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/pictogram_view.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../picker/pictogram_picker.dart';

/// Dettaglio e modifica di una pausa. Le pause di sistema sono in sola
/// lettura: si duplicano e si modifica la copia (spec §7).
class BreakEditorScreen extends ConsumerStatefulWidget {
  const BreakEditorScreen({super.key, this.initial});

  final BreakActivity? initial;

  @override
  ConsumerState<BreakEditorScreen> createState() => _BreakEditorScreenState();
}

class _MoveDraft {
  _MoveDraft(this.pictogram, String label, this.seconds)
      : controller = TextEditingController(text: label);

  PictogramRef pictogram;
  int seconds;
  final TextEditingController controller;
}

class _BreakEditorScreenState extends ConsumerState<BreakEditorScreen> {
  late final TextEditingController _name;
  late BreakKind _kind;
  late SpaceRequired _space;
  late final List<_MoveDraft> _moves;

  bool get _readOnly => widget.initial?.isBuiltin ?? false;

  int get _total => _moves.fold(0, (sum, m) => sum + m.seconds);

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _name = TextEditingController(text: b?.name ?? '');
    _kind = b?.kind ?? BreakKind.attivazione;
    _space = b?.space ?? SpaceRequired.banco;
    _moves = [
      for (final m in b?.moves ?? const <BreakMove>[])
        _MoveDraft(m.pictogram, m.label, m.seconds),
    ];
  }

  @override
  void dispose() {
    _name.dispose();
    for (final m in _moves) {
      m.controller.dispose();
    }
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _duplicate() async {
    final repo = ref.read(breakRepoProvider);
    final id = await repo.duplicate(widget.initial!);
    final copy = (await repo.loadAll()).firstWhere((b) => b.id == id);
    if (!mounted) return;
    unawaited(Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => BreakEditorScreen(initial: copy),
    )));
  }

  Future<void> _addMove() async {
    final selection = await showPictogramPicker(context, includeOwn: true);
    if (selection == null) return;
    setState(() => _moves.add(_MoveDraft(
        selection.pictogram, selection.suggestedLabel, K.moveSecondsDefault)));
  }

  Future<void> _changePictogram(_MoveDraft move) async {
    final selection = await showPictogramPicker(context, includeOwn: true);
    if (selection == null) return;
    setState(() {
      move.pictogram = selection.pictogram;
      if (move.controller.text.trim().isEmpty) {
        move.controller.text = selection.suggestedLabel;
      }
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return _snack('Dai un nome alla pausa');
    if (_moves.isEmpty) return _snack('Aggiungi almeno un movimento');
    if (_moves.any((m) => m.controller.text.trim().isEmpty)) {
      return _snack('Ogni movimento ha bisogno di un nome');
    }
    if (_total < K.breakTotalSecondsMin || _total > K.breakTotalSecondsMax) {
      return _snack('La pausa deve durare tra ${formatSeconds(K.breakTotalSecondsMin)} '
          'e ${formatSeconds(K.breakTotalSecondsMax)}');
    }

    final moves = [
      for (final m in _moves)
        BreakMove(
            label: m.controller.text.trim(),
            seconds: m.seconds,
            pictogram: m.pictogram),
    ];
    await ref.read(breakRepoProvider).save(BreakActivity(
          id: widget.initial?.id ?? '',
          name: name,
          kind: _kind,
          space: _space,
          moves: moves,
          pictogram: moves.first.pictogram,
          copiedFrom: widget.initial?.copiedFrom,
        ));

    final arasaacIds = moves
        .where((m) => m.pictogram.source == PictogramSource.arasaac)
        .map((m) => int.tryParse(m.pictogram.ref))
        .whereType<int>();
    unawaited(ref.read(arasaacApiProvider).downloadAll(arasaacIds));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare la pausa?'),
        content: const Text(
            'Nei compiti che la usano verrà proposta una pausa automatica.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(breakRepoProvider).delete(widget.initial!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.initial;
    return Scaffold(
      appBar: AppBar(
        title: Text(_readOnly
            ? b!.name
            : b == null
                ? 'Nuova pausa'
                : 'Modifica pausa'),
        actions: [
          if (!_readOnly && b != null)
            IconButton(
              tooltip: 'Elimina',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: _readOnly ? _readOnlyView(b!) : _editView(),
      ),
    );
  }

  List<Widget> _readOnlyView(BreakActivity b) => [
        Center(
          child: PictogramView(pictogram: b.pictogram, size: 200, animate: true),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            Chip(avatar: Icon(b.kind.icon, size: 18), label: Text(b.kind.label)),
            Chip(avatar: Icon(b.space.icon, size: 18), label: Text(b.space.label)),
            Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text(formatSeconds(b.totalSeconds))),
          ],
        ),
        const SizedBox(height: 16),
        for (final m in b.moves)
          ListTile(
            leading: PictogramView(pictogram: m.pictogram, size: 48),
            title: Text(m.label),
            trailing: Text(formatSeconds(m.seconds)),
          ),
        const SizedBox(height: 24),
        const Text(
          'Questa è una pausa di sistema. Per cambiarla crea una copia: '
          'l\'originale resta disponibile.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF616161)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _duplicate,
          icon: const Icon(Icons.copy),
          label: const Text('Duplica per modificare'),
        ),
      ];

  List<Widget> _editView() => [
        TextField(
          controller: _name,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Nome della pausa',
            hintText: 'Es. Marcia e respiro',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Tipo'),
        const SizedBox(height: 8),
        SegmentedButton<BreakKind>(
          showSelectedIcon: false,
          segments: [
            for (final k in BreakKind.values)
              ButtonSegment(value: k, icon: Icon(k.icon), label: Text(k.label)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 16),
        const Text('Spazio richiesto'),
        const SizedBox(height: 8),
        SegmentedButton<SpaceRequired>(
          showSelectedIcon: false,
          segments: [
            for (final s in SpaceRequired.values)
              ButtonSegment(value: s, icon: Icon(s.icon), label: Text(s.label)),
          ],
          selected: {_space},
          onSelectionChanged: (s) => setState(() => _space = s.first),
        ),
        const Divider(height: 32),
        Text('Movimenti (${_moves.length} di ${K.movesMax})',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < _moves.length; i++) _moveCard(i),
        OutlinedButton.icon(
          onPressed: _moves.length < K.movesMax ? _addMove : null,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi movimento'),
        ),
        const SizedBox(height: 16),
        Text(
          'Durata totale: ${formatSeconds(_total)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: _moves.isNotEmpty &&
                    (_total < K.breakTotalSecondsMin ||
                        _total > K.breakTotalSecondsMax)
                ? Theme.of(context).colorScheme.error
                : null,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: const Text('Salva')),
      ];

  Widget _moveCard(int i) {
    final m = _moves[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            InkWell(
              onTap: () => _changePictogram(m),
              borderRadius: BorderRadius.circular(8),
              child: PictogramView(pictogram: m.pictogram, size: 72),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: m.controller,
                    maxLength: 60,
                    decoration: InputDecoration(
                      labelText: 'Movimento ${i + 1}',
                      counterText: '',
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: m.seconds > K.moveSecondsMin
                            ? () => setState(() => m.seconds -= 5)
                            : null,
                      ),
                      Text(formatSeconds(m.seconds)),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: m.seconds < K.moveSecondsMax
                            ? () => setState(() => m.seconds += 5)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'Su',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i > 0
                      ? () => setState(() => _moves.insert(i - 1, _moves.removeAt(i)))
                      : null,
                ),
                IconButton(
                  tooltip: 'Rimuovi',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    final removed = _moves.removeAt(i);
                    setState(() {});
                    // Il TextField resta nell'albero fino al frame dopo.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => removed.controller.dispose());
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
