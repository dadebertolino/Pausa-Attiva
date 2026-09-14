import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/pictogram_view.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import 'break_editor_screen.dart';

/// Libreria pause (spec §6, schermata 3). Dietro gate.
/// Sfoglia per tipo, filtra per spazio richiesto, crea e modifica.
class BreakLibraryScreen extends ConsumerStatefulWidget {
  const BreakLibraryScreen({super.key});

  @override
  ConsumerState<BreakLibraryScreen> createState() => _BreakLibraryScreenState();
}

class _BreakLibraryScreenState extends ConsumerState<BreakLibraryScreen> {
  SpaceRequired? _space;

  void _open(BreakActivity? activity) => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => BreakEditorScreen(initial: activity)),
      );

  @override
  Widget build(BuildContext context) {
    final breaks = ref.watch(breaksProvider).valueOrNull ?? const <BreakActivity>[];

    return DefaultTabController(
      length: BreakKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Libreria pause'),
          bottom: TabBar(
            tabs: [
              for (final kind in BreakKind.values)
                Tab(icon: Icon(kind.icon), text: kind.label),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(null),
          icon: const Icon(Icons.add),
          label: const Text('Nuova pausa'),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Tutte'),
                    selected: _space == null,
                    onSelected: (_) => setState(() => _space = null),
                  ),
                  for (final space in SpaceRequired.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        avatar: Icon(space.icon, size: 18),
                        label: Text(space.label),
                        selected: _space == space,
                        onSelected: (_) => setState(() => _space = space),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final kind in BreakKind.values)
                    _BreakList(
                      breaks: breaks
                          .where((b) => b.kind == kind)
                          .where((b) => _space == null || b.space == _space)
                          .toList(),
                      onTap: _open,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakList extends StatelessWidget {
  const _BreakList({required this.breaks, required this.onTap});

  final List<BreakActivity> breaks;
  final ValueChanged<BreakActivity> onTap;

  @override
  Widget build(BuildContext context) {
    if (breaks.isEmpty) {
      return const Center(child: Text('Nessuna pausa con questo filtro'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: breaks.length,
      itemBuilder: (context, i) {
        final b = breaks[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(8),
            leading: PictogramView(pictogram: b.pictogram, size: 64),
            title: Text(b.name, style: const TextStyle(fontSize: 18)),
            subtitle: Text([
              formatSeconds(b.totalSeconds),
              b.space.label,
              if (b.isCircuit) '${b.moves.length} movimenti',
            ].join(' · ')),
            trailing: b.isBuiltin
                ? const Tooltip(
                    message: 'Pausa di sistema: si può duplicare',
                    child: Icon(Icons.lock_outline),
                  )
                : null,
            onTap: () => onTap(b),
          ),
        );
      },
    );
  }
}
