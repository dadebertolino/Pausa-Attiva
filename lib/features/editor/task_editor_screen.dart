import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/pictogram_view.dart';
import '../../domain/break_rotation.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../picker/pictogram_picker.dart';

/// Editor del compito (spec §6, schermata 2). Dietro gate.
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({super.key, this.initial});

  final TaskTemplate? initial;

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _StepDraft {
  _StepDraft(this.pictogram, String label)
      : controller = TextEditingController(text: label);

  PictogramRef pictogram;
  final TextEditingController controller;
  final Key key = UniqueKey();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  late final TextEditingController _title;
  int? _profileId;
  late TimerMode _mode;
  late int _workSeconds;
  late int _blocks;
  late bool _useBreaks;
  late final List<_StepDraft> _steps;
  late List<String?> _breakIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _title = TextEditingController(text: t?.title ?? '');
    _profileId = t?.profileId;
    _mode = t?.timerMode ?? TimerMode.blocco;
    _workSeconds = t?.workSeconds ?? K.workSecondsDefault;
    _blocks = t?.blocksCount ?? K.blocksDefault;
    _useBreaks = t?.useBreaks ?? true;
    _steps = [for (final s in t?.steps ?? const <TaskStep>[]) _StepDraft(s.pictogram, s.label)];
    _breakIds = [...?t?.breakIds];
    _syncBreaks();
  }

  @override
  void dispose() {
    _title.dispose();
    for (final s in _steps) {
      s.controller.dispose();
    }
    super.dispose();
  }

  /// Il TextField che usa il controller resta nell'albero fino al frame dopo.
  void _disposeLater(TextEditingController controller) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

  int get _effectiveBlocks =>
      _mode == TimerMode.step ? math.max(1, _steps.length) : _blocks;

  int get _gapCount => _useBreaks ? _effectiveBlocks - 1 : 0;

  /// Allinea le pause al numero di intervalli; i nuovi si precompilano a
  /// rotazione, quelli già scelti restano.
  void _syncBreaks() {
    final gaps = _gapCount;
    if (_breakIds.length > gaps) {
      _breakIds = _breakIds.sublist(0, gaps);
      return;
    }
    final library = ref.read(breaksProvider).valueOrNull ?? const [];
    final rotation = rotateBreaks(library, gaps);
    for (var i = _breakIds.length; i < gaps; i++) {
      _breakIds.add(i < rotation.length ? rotation[i].id : null);
    }
  }

  void _update(VoidCallback change) => setState(() {
        change();
        _syncBreaks();
      });

  Future<void> _addStep() async {
    final selection = await showPictogramPicker(context);
    if (selection == null) return;
    _update(() => _steps.add(_StepDraft(selection.pictogram, selection.suggestedLabel)));
  }

  Future<void> _changePictogram(_StepDraft step) async {
    final selection = await showPictogramPicker(context);
    if (selection == null) return;
    setState(() {
      step.pictogram = selection.pictogram;
      if (step.controller.text.trim().isEmpty) {
        step.controller.text = selection.suggestedLabel;
      }
    });
  }

  Future<void> _chooseBreak(int gap) async {
    final library = ref.read(breaksProvider).valueOrNull ?? const [];
    final chosen = await showModalBottomSheet<BreakActivity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Pausa dopo il blocco ${gap + 1}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ),
            for (final b in library)
              ListTile(
                leading: PictogramView(pictogram: b.pictogram, size: 48),
                title: Text(b.name),
                subtitle: Text(
                    '${b.kind.label} · ${formatSeconds(b.totalSeconds)} · ${b.space.label}'),
                onTap: () => Navigator.pop(context, b),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _breakIds[gap] = chosen.id);
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return _snack('Dai un nome al compito');
    if (_steps.isEmpty) return _snack('Aggiungi almeno uno step');
    if (_steps.any((s) => s.controller.text.trim().isEmpty)) {
      return _snack('Ogni step ha bisogno di un\'etichetta');
    }

    setState(() => _saving = true);
    final task = TaskTemplate(
      id: widget.initial?.id,
      profileId: _profileId,
      title: title,
      timerMode: _mode,
      workSeconds: _workSeconds,
      blocksCount: _effectiveBlocks,
      useBreaks: _useBreaks,
      steps: [
        for (final s in _steps)
          TaskStep(label: s.controller.text.trim(), pictogram: s.pictogram),
      ],
      breakIds: _breakIds,
    );

    // Pittogrammi su disco prima di salvare: il compito deve funzionare offline.
    final ids = task.steps
        .where((s) => s.pictogram.source == PictogramSource.arasaac)
        .map((s) => int.tryParse(s.pictogram.ref))
        .whereType<int>();
    final failed = await ref.read(arasaacApiProvider).downloadAll(ids);
    await ref.read(taskRepoProvider).save(task);

    if (!mounted) return;
    if (failed.isNotEmpty) {
      _snack('Compito salvato. Alcuni pittogrammi non sono stati scaricati: '
          'apri il compito con la rete attiva per averli anche offline.');
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare il compito?'),
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
    await ref.read(taskRepoProvider).delete(widget.initial!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Tiene aggiornata la libreria per la rotazione.
    ref.watch(breaksProvider);
    final profiles = ref.watch(profilesProvider).valueOrNull ?? const [];
    final library = {
      for (final b in ref.watch(breaksProvider).valueOrNull ?? const <BreakActivity>[])
        b.id: b,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Nuovo compito' : 'Modifica compito'),
        actions: [
          if (widget.initial != null)
            IconButton(
              tooltip: 'Elimina',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        buildDefaultDragHandles: false,
        onReorder: (from, to) => setState(() {
          if (to > from) to--;
          _steps.insert(to, _steps.removeAt(from));
        }),
        header: _header(profiles),
        footer: _footer(library),
        children: [
          for (var i = 0; i < _steps.length; i++) _stepTile(i),
        ],
      ),
    );
  }

  Widget _header(List<Profile> profiles) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Nome del compito',
              hintText: 'Es. Scheda di matematica',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: profiles.any((p) => p.id == _profileId) ? _profileId : null,
            decoration: const InputDecoration(
              labelText: 'Profilo',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tutti i profili')),
              for (final p in profiles)
                DropdownMenuItem(value: p.id, child: Text(p.nickname)),
            ],
            onChanged: (v) => setState(() => _profileId = v),
          ),
          const SizedBox(height: 20),
          SegmentedButton<TimerMode>(
            segments: [
              for (final m in TimerMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => _update(() => _mode = s.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _mode == TimerMode.blocco
                  ? 'Il tempo scorre per blocchi; lo step avanza quando si tocca "Fatto".'
                  : 'Ogni step ha il suo tempo; dopo ogni step c\'è una pausa.',
              style: const TextStyle(color: Color(0xFF616161)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_mode == TimerMode.blocco ? 'Durata di ogni blocco' : 'Durata di ogni step'}: '
            '${formatSeconds(_workSeconds)}',
            style: const TextStyle(fontSize: 16),
          ),
          Slider(
            value: _workSeconds / 60,
            min: K.workSecondsMin / 60,
            max: K.workSecondsMax / 60,
            divisions: (K.workSecondsMax - K.workSecondsMin) ~/ 60,
            label: formatSeconds(_workSeconds),
            onChanged: (v) => setState(() => _workSeconds = v.round() * 60),
          ),
          if (_mode == TimerMode.blocco)
            Row(
              children: [
                const Expanded(
                    child: Text('Blocchi di lavoro', style: TextStyle(fontSize: 16))),
                IconButton.outlined(
                  icon: const Icon(Icons.remove),
                  onPressed: _blocks > K.blocksMin
                      ? () => _update(() => _blocks--)
                      : null,
                ),
                SizedBox(
                  width: 40,
                  child: Text('$_blocks',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20)),
                ),
                IconButton.outlined(
                  icon: const Icon(Icons.add),
                  onPressed: _blocks < K.blocksMax
                      ? () => _update(() => _blocks++)
                      : null,
                ),
              ],
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pause attive tra i blocchi'),
            value: _useBreaks,
            onChanged: (v) => _update(() => _useBreaks = v),
          ),
          const Divider(height: 32),
          Text('Step (${_steps.length} di ${K.stepsMax})',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
      );

  Widget _stepTile(int i) {
    final step = _steps[i];
    return Card(
      key: step.key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            InkWell(
              onTap: () => _changePictogram(step),
              borderRadius: BorderRadius.circular(8),
              child: PictogramView(pictogram: step.pictogram, size: 64),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: step.controller,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Step ${i + 1}',
                  counterText: '',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Rimuovi',
              icon: const Icon(Icons.close),
              onPressed: () => _update(() => _disposeLater(_steps.removeAt(i).controller)),
            ),
            ReorderableDragStartListener(
              index: i,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_handle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(Map<String, BreakActivity> library) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _steps.length < K.stepsMax ? _addStep : null,
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi step'),
          ),
          if (_gapCount > 0) ...[
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text('Pause', style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => _update(() => _breakIds = []),
                  child: const Text('Ripristina rotazione'),
                ),
              ],
            ),
            for (var gap = 0; gap < _gapCount; gap++) _breakTile(gap, library),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva'),
          ),
        ],
      );

  Widget _breakTile(int gap, Map<String, BreakActivity> library) {
    final id = gap < _breakIds.length ? _breakIds[gap] : null;
    final b = id == null ? null : library[id];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: b == null
            ? const Icon(Icons.autorenew)
            : PictogramView(pictogram: b.pictogram, size: 48),
        title: Text(b?.name ?? 'Automatica'),
        subtitle: Text(b == null
            ? 'Dopo il blocco ${gap + 1}'
            : 'Dopo il blocco ${gap + 1} · ${b.kind.label} · ${formatSeconds(b.totalSeconds)}'),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _chooseBreak(gap),
      ),
    );
  }
}
