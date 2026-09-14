import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repo.dart';
import '../providers.dart';

/// Gate adulto (spec §4.7): PIN se impostato, altrimenti un calcolo che un
/// bambino piccolo non risolve al volo. Restituisce true se superato.
Future<bool> showAdultGate(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider).valueOrNull ?? const AppSettings();
  final passed = await showDialog<bool>(
    context: context,
    builder: (_) => _GateDialog(pinHash: settings.pinHash),
  );
  return passed ?? false;
}

class _GateDialog extends StatefulWidget {
  const _GateDialog({required this.pinHash});

  final String? pinHash;

  @override
  State<_GateDialog> createState() => _GateDialogState();
}

class _GateDialogState extends State<_GateDialog> {
  final _random = Random();
  final _controller = TextEditingController();
  late int _a, _b, _c;
  String? _error;

  bool get _usePin => widget.pinHash != null;

  @override
  void initState() {
    super.initState();
    _newQuestion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _newQuestion() {
    _a = 6 + _random.nextInt(4);
    _b = 6 + _random.nextInt(4);
    _c = 11 + _random.nextInt(19);
  }

  void _submit() {
    final value = _controller.text.trim();
    final ok = _usePin
        ? verifyPin(value, widget.pinHash!)
        : int.tryParse(value) == _a * _b + _c;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _controller.clear();
      if (_usePin) {
        _error = 'PIN non corretto';
      } else {
        _error = 'Risposta non corretta, riprova';
        _newQuestion();
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Area adulti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _usePin ? 'Inserisci il PIN' : 'Quanto fa $_a × $_b + $_c ?',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: _usePin,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _error,
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Conferma')),
        ],
      );
}
