import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/print_actions.dart';
import '../../core/providers.dart';
import '../../core/widgets/avatar_view.dart';
import '../../data/repositories/settings_repo.dart';
import '../../data/services/arasaac_api.dart';
import '../../domain/models.dart';

/// Impostazioni (spec §6, schermata 9). Dietro gate.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double? _warningDraft;

  SettingsRepo get _repo => ref.read(settingsRepoProvider);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final profiles = ref.watch(profilesProvider).valueOrNull ?? const <Profile>[];
    final warning = _warningDraft ?? settings.warningSeconds.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Header('Profili'),
          for (final p in profiles)
            ListTile(
              leading: AvatarView(avatarId: p.avatarId, size: 40),
              title: Text(p.nickname),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editProfile(p),
            ),
          ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Aggiungi profilo'),
            onTap: () => _editProfile(null),
          ),
          const _Note('Solo un soprannome e un avatar. Nessun altro dato.'),
          const _Header('Sessione'),
          SwitchListTile(
            title: const Text('Voce'),
            subtitle: const Text('Annuncia step e pause'),
            value: settings.voice,
            onChanged: (v) => unawaited(_repo.put(SettingsKeys.voice, '$v')),
          ),
          SwitchListTile(
            title: const Text('Suoni'),
            subtitle: const Text('Un segnale poco prima del cambio e uno a ogni cambio di fase'),
            value: settings.sounds,
            onChanged: (v) => unawaited(_repo.put(SettingsKeys.sounds, '$v')),
          ),
          ListTile(
            title: Text('Preavviso: ${warning.round()} secondi prima del cambio'),
            subtitle: Slider(
              value: warning,
              min: K.warningSecondsMin.toDouble(),
              max: K.warningSecondsMax.toDouble(),
              divisions: (K.warningSecondsMax - K.warningSecondsMin) ~/ 5,
              label: '${warning.round()} s',
              onChanged: (v) => setState(() => _warningDraft = v),
              onChangeEnd: (v) async {
                await _repo.put(SettingsKeys.warningSeconds, '${v.round()}');
                if (mounted) setState(() => _warningDraft = null);
              },
            ),
          ),
          const _Header('Area adulti'),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(settings.hasPin ? 'Cambia PIN' : 'Imposta un PIN'),
            subtitle: Text(settings.hasPin
                ? 'L\'area adulti chiede il PIN'
                : 'Senza PIN l\'area adulti chiede un calcolo'),
            onTap: _setPin,
          ),
          if (settings.hasPin)
            ListTile(
              leading: const Icon(Icons.no_encryption_outlined),
              title: const Text('Rimuovi PIN'),
              onTap: () => unawaited(_repo.clearPin()),
            ),
          const _Header('Stampa'),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Schede di tutte le pause'),
            subtitle: const Text('Una pagina per pausa, da stampare e plastificare'),
            onTap: () => printBreakCards(
                context, ref, ref.read(breaksProvider).valueOrNull ?? const []),
          ),
          const _Header('Informazioni'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            onTap: () => _info(
              'Privacy',
              'Pausa Attiva non raccoglie dati. Non ci sono account, statistiche, '
                  'pubblicità o tracciamenti.\n\n'
                  'Compiti, pause e profili restano solo su questo dispositivo. '
                  'Non viene registrato lo storico delle sessioni.\n\n'
                  'La connessione serve solo per cercare pittogrammi nel catalogo '
                  'pubblico ARASAAC.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Crediti'),
            onTap: () => _info(
              'Crediti',
              '$arasaacAttribution.\n\n'
                  'Illustrazioni delle pause attive: Davide Bertolino.\n\n'
                  'Codice pubblico con licenza PolyForm Noncommercial 1.0.0.',
              link: Uri.parse('https://arasaac.org'),
            ),
          ),
          const AboutListTile(
            icon: Icon(Icons.description_outlined),
            applicationName: 'Pausa Attiva',
            applicationVersion: K.appVersion,
            applicationLegalese: '© 2026 Davide Bertolino',
            child: Text('Licenze'),
          ),
        ],
      ),
    );
  }

  void _info(String title, String body, {Uri? link}) => unawaited(showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            if (link != null)
              TextButton(
                onPressed: () => unawaited(
                    launchUrl(link, mode: LaunchMode.externalApplication)),
                child: Text(link.host),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
          ],
        ),
      ));

  Future<void> _editProfile(Profile? profile) async {
    final result = await showDialog<_ProfileResult>(
      context: context,
      builder: (_) => _ProfileDialog(profile: profile),
    );
    if (result == null) return;
    final repo = ref.read(profileRepoProvider);
    if (result.delete) {
      await repo.delete(profile!.id!);
    } else {
      await repo.save(Profile(
          id: profile?.id, nickname: result.nickname, avatarId: result.avatarId));
    }
  }

  Future<void> _setPin() async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinDialog(),
    );
    if (pin != null) await _repo.setPin(pin);
  }
}

class _ProfileResult {
  const _ProfileResult.save(this.nickname, this.avatarId) : delete = false;
  const _ProfileResult.delete()
      : nickname = '',
        avatarId = '',
        delete = true;

  final String nickname;
  final String avatarId;
  final bool delete;
}

/// I controller vivono nello State del dialog: vengono distrutti solo quando
/// il dialog è davvero smontato, dopo l'animazione di chiusura.
class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.profile});

  final Profile? profile;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _nickname =
      TextEditingController(text: widget.profile?.nickname ?? '');
  late String _avatar = widget.profile?.avatarId ?? avatarIds.first;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.profile == null ? 'Nuovo profilo' : 'Modifica profilo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nickname,
                maxLength: 40,
                autofocus: widget.profile == null,
                decoration: const InputDecoration(
                  labelText: 'Soprannome',
                  helperText: 'Un soprannome basta: non serve il nome vero',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in avatarIds)
                    GestureDetector(
                      onTap: () => setState(() => _avatar = id),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            width: 3,
                            color: _avatar == id
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: AvatarView(avatarId: id, size: 48),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (widget.profile != null)
            TextButton(
              onPressed: () => Navigator.pop(context, const _ProfileResult.delete()),
              child: const Text('Elimina'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final name = _nickname.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, _ProfileResult.save(name, _avatar));
            },
            child: const Text('Salva'),
          ),
        ],
      );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    if (_first.text.length < 4) {
      setState(() => _error = 'Almeno 4 cifre');
    } else if (_first.text != _second.text) {
      setState(() => _error = 'I due PIN non coincidono');
    } else {
      Navigator.pop(context, _first.text);
    }
  }

  Widget _field(TextEditingController controller, String label, {bool autofocus = false}) =>
      TextField(
        controller: controller,
        autofocus: autofocus,
        obscureText: true,
        maxLength: 8,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, counterText: ''),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('PIN area adulti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_first, 'Nuovo PIN (da 4 a 8 cifre)', autofocus: true),
            _field(_second, 'Ripeti il PIN'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Salva')),
        ],
      );
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(text, style: const TextStyle(color: Color(0xFF757575))),
      );
}
