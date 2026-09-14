import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/adult_gate.dart';
import '../../core/widgets/avatar_view.dart';
import '../../core/widgets/pictogram_view.dart';
import '../../data/repositories/settings_repo.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../editor/task_editor_screen.dart';
import '../impostazioni/settings_screen.dart';
import '../libreria_pause/break_library_screen.dart';
import '../prima_dopo/prima_dopo_screen.dart';
import '../sessione/session_screen.dart';

/// Home (spec §6, schermata 1): compiti, profilo attivo, avvio rapido.
/// La configurazione compare solo dopo il gate adulto.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _push(BuildContext context, Widget screen) => unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)));

  Future<void> _toggleAdult(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(adultModeProvider.notifier);
    if (notifier.state) {
      notifier.state = false;
      return;
    }
    if (await showAdultGate(context, ref)) notifier.state = true;
  }

  void _start(BuildContext context, WidgetRef ref, TaskTemplate task) {
    // Il dispositivo passa al bambino: l'area adulti si richiude.
    ref.read(adultModeProvider.notifier).state = false;
    _push(context, SessionScreen(task: task));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tiene vive libreria e impostazioni: la sessione le legge all'avvio.
    ref.watch(breaksProvider);
    final adult = ref.watch(adultModeProvider);
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final profiles = ref.watch(profilesProvider).valueOrNull ?? const <Profile>[];
    final tasks = ref.watch(tasksProvider);

    final activeId = profiles.any((p) => p.id == settings.activeProfileId)
        ? settings.activeProfileId
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pausa Attiva'),
        actions: [
          IconButton(
            tooltip: adult ? 'Chiudi area adulti' : 'Area adulti',
            icon: Icon(adult ? Icons.lock_open : Icons.lock_outline),
            onPressed: () => _toggleAdult(context, ref),
          ),
        ],
      ),
      floatingActionButton: adult
          ? FloatingActionButton.extended(
              onPressed: () => _push(context, const TaskEditorScreen()),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo compito'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (profiles.isNotEmpty)
            _ProfileBar(
              profiles: profiles,
              activeId: activeId,
              onSelect: (id) {
                final repo = ref.read(settingsRepoProvider);
                unawaited(id == null
                    ? repo.remove(SettingsKeys.activeProfile)
                    : repo.put(SettingsKeys.activeProfile, '$id'));
              },
            ),
          Card(
            color: AppColors.workSurface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.compare_arrows, size: 36),
              title: const Text('Prima / Dopo', style: TextStyle(fontSize: 18)),
              subtitle: const Text('Cosa faccio ora, cosa viene dopo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _push(context, const PrimaDopoScreen()),
            ),
          ),
          if (adult)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _push(context, const BreakLibraryScreen()),
                    icon: const Icon(Icons.directions_run),
                    label: const Text('Libreria pause'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _push(context, const SettingsScreen()),
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Impostazioni'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text('Compiti', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...tasks.when(
            loading: () => const [Center(child: CircularProgressIndicator())],
            error: (e, _) => [Text('Errore nel caricamento: $e')],
            data: (all) {
              final visible = all
                  .where((t) =>
                      activeId == null || t.profileId == null || t.profileId == activeId)
                  .toList();
              if (visible.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      adult
                          ? 'Crea il primo compito con "Nuovo compito".'
                          : 'Nessun compito. Tocca il lucchetto in alto per crearne uno.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF616161)),
                    ),
                  ),
                ];
              }
              return [
                for (final t in visible)
                  _TaskCard(
                    task: t,
                    adult: adult,
                    onStart: () => _start(context, ref, t),
                    onEdit: () => _push(context, TaskEditorScreen(initial: t)),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileBar extends StatelessWidget {
  const _ProfileBar({
    required this.profiles,
    required this.activeId,
    required this.onSelect,
  });

  final List<Profile> profiles;
  final int? activeId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Tutti'),
                selected: activeId == null,
                onSelected: (_) => onSelect(null),
              ),
            ),
            for (final p in profiles)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: AvatarView(avatarId: p.avatarId, size: 28),
                  label: Text(p.nickname),
                  selected: activeId == p.id,
                  onSelected: (_) => onSelect(p.id),
                ),
              ),
          ],
        ),
      );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.adult,
    required this.onStart,
    required this.onEdit,
  });

  final TaskTemplate task;
  final bool adult;
  final VoidCallback onStart;
  final VoidCallback onEdit;

  String get _summary {
    final steps = '${task.steps.length} step';
    final time = task.timerMode == TimerMode.step
        ? '${formatSeconds(task.workSeconds)} per step'
        : '${task.blocksCount} ${task.blocksCount == 1 ? 'blocco' : 'blocchi'} '
            'da ${formatSeconds(task.workSeconds)}';
    return [
      steps,
      time,
      task.useBreaks && task.gapCount > 0 ? 'con pause' : 'senza pause',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              PictogramView(pictogram: task.steps.first.pictogram, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${task.timerMode.label} · $_summary',
                        style: const TextStyle(color: Color(0xFF616161))),
                  ],
                ),
              ),
              if (adult)
                IconButton(
                  tooltip: 'Modifica',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                ),
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Avvia'),
              ),
            ],
          ),
        ),
      );
}
