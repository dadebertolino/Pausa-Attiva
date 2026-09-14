import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/pictogram_view.dart';
import '../../data/services/arasaac_api.dart';
import '../picker/pictogram_picker.dart';

/// Prima / Dopo (spec §6, schermata 7; §11). Schermata autonoma per la
/// transizione improvvisa: due pittogrammi, mostra, chiudi.
/// Effimera: non tocca il data model.
class PrimaDopoScreen extends StatefulWidget {
  const PrimaDopoScreen({super.key});

  @override
  State<PrimaDopoScreen> createState() => _PrimaDopoScreenState();
}

class _PrimaDopoScreenState extends State<PrimaDopoScreen> {
  PictogramSelection? _now;
  PictogramSelection? _next;

  Future<void> _pick(bool isNow) async {
    final selection = await showPictogramPicker(context);
    if (selection == null || !mounted) return;
    setState(() => isNow ? _now = selection : _next = selection);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Prima / Dopo')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Slot(
                          title: 'Ora',
                          selection: _now,
                          onTap: () => _pick(true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 40),
                      ),
                      Expanded(
                        child: _Slot(
                          title: 'Dopo',
                          selection: _next,
                          onTap: () => _pick(false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                  onPressed: _now != null && _next != null
                      ? () => unawaited(Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => _Display(now: _now!, next: _next!),
                            ),
                          ))
                      : null,
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Mostra'),
                ),
                const SizedBox(height: 8),
                const Text(
                  arasaacAttribution,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF757575)),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Slot extends StatelessWidget {
  const _Slot({required this.title, required this.selection, required this.onTap});

  final String title;
  final PictogramSelection? selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.track, width: 2),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              Expanded(
                child: selection == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 48),
                            Text('Scegli'),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (_, box) => Center(
                          child: PictogramView(
                            pictogram: selection!.pictogram,
                            size: box.biggest.shortestSide,
                          ),
                        ),
                      ),
              ),
              if (selection != null)
                Text(selection!.suggestedLabel,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
}

/// Visualizzazione a schermo pieno. Tocca un riquadro per ingrandirlo.
class _Display extends StatefulWidget {
  const _Display({required this.now, required this.next});

  final PictogramSelection now;
  final PictogramSelection next;

  @override
  State<_Display> createState() => _DisplayState();
}

class _DisplayState extends State<_Display> {
  int? _focused;

  @override
  Widget build(BuildContext context) {
    final panels = [
      _Panel(title: 'Ora', selection: widget.now, color: AppColors.work),
      _Panel(title: 'Dopo', selection: widget.next, color: const Color(0xFF757575)),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final landscape = box.maxWidth > box.maxHeight;
                final children = [
                  for (var i = 0; i < panels.length; i++)
                    if (_focused == null || _focused == i)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _focused = _focused == null ? i : null),
                          child: panels[i],
                        ),
                      ),
                ];
                return Flex(
                  direction: landscape ? Axis.horizontal : Axis.vertical,
                  children: children,
                );
              },
            ),
            Positioned(
              left: 8,
              top: 8,
              child: IconButton.filledTonal(
                tooltip: 'Chiudi',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.selection, required this.color});

  final String title;
  final PictogramSelection selection;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 4),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color)),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) => Center(
                  child: PictogramView(
                    pictogram: selection.pictogram,
                    size: box.biggest.shortestSide,
                  ),
                ),
              ),
            ),
            Text(selection.suggestedLabel,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 32)),
          ],
        ),
      );
}
