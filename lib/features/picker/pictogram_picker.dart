import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/widgets/pose_animation.dart';
import '../../data/services/arasaac_api.dart';
import '../../domain/models.dart';

class PictogramSelection {
  const PictogramSelection({required this.pictogram, required this.suggestedLabel});

  final PictogramRef pictogram;
  final String suggestedLabel;
}

/// Selettore pittogrammi (spec §6, schermata 4).
/// [includeOwn]: nelle pause offre prima i movimenti disegnati (spec §7.1).
/// Negli step e nel Prima/Dopo solo ARASAAC (spec §12).
Future<PictogramSelection?> showPictogramPicker(
  BuildContext context, {
  bool includeOwn = false,
}) =>
    Navigator.of(context).push<PictogramSelection>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PickerScreen(includeOwn: includeOwn),
    ));

class _PickerScreen extends StatelessWidget {
  const _PickerScreen({required this.includeOwn});

  final bool includeOwn;

  @override
  Widget build(BuildContext context) {
    if (!includeOwn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scegli un pittogramma')),
        body: const _ArasaacTab(),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scegli un pittogramma'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Movimenti'),
            Tab(text: 'ARASAAC'),
          ]),
        ),
        body: const TabBarView(children: [_OwnTab(), _ArasaacTab()]),
      ),
    );
  }
}

class _OwnTab extends ConsumerWidget {
  const _OwnTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movements = ref.watch(manifestProvider).movements.values.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: movements.length,
      itemBuilder: (context, i) {
        final m = movements[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(
            context,
            PictogramSelection(
                pictogram: PictogramRef.own(m.id), suggestedLabel: m.name),
          ),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_, box) => PoseAnimation(
                    movementId: m.id,
                    size: box.biggest.shortestSide,
                    animate: false,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(m.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

class _ArasaacTab extends ConsumerStatefulWidget {
  const _ArasaacTab();

  @override
  ConsumerState<_ArasaacTab> createState() => _ArasaacTabState();
}

class _ArasaacTabState extends ConsumerState<_ArasaacTab> {
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<ArasaacPictogram> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(K.searchDebounce, () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    setState(() {
      _query = query;
      _error = null;
      _loading = query.isNotEmpty;
      if (query.isEmpty) _results = const [];
    });
    if (query.isEmpty) return;

    try {
      final results = await ref.read(arasaacApiProvider).search(query);
      if (!mounted || query != _query) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Serve la connessione per cercare nuovi pittogrammi. '
            'Le ricerche già fatte funzionano anche offline.';
      });
    }
  }

  void _select(ArasaacPictogram p) {
    // Scarica subito su disco: il compito deve funzionare senza rete.
    unawaited(ref.read(arasaacApiProvider).download(p.id).then((_) {}, onError: (_) {}));
    final label = p.keyword.isEmpty
        ? p.keyword
        : p.keyword[0].toUpperCase() + p.keyword.substring(1);
    Navigator.pop(
      context,
      PictogramSelection(
        pictogram: PictogramRef.arasaac(p.id.toString()),
        suggestedLabel: label,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cerca: leggere, scrivere, zaino…',
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          Expanded(child: _body()),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              arasaacAttribution,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF757575)),
            ),
          ),
        ],
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_query.isEmpty) {
      return const Center(
        child: Text('Scrivi una parola per cercare',
            style: TextStyle(color: Color(0xFF757575))),
      );
    }
    if (_results.isEmpty) return const Center(child: Text('Nessun risultato'));

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final p = _results[i];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _select(p),
          child: Column(
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: ArasaacApi.imageUrl(p.id, res: K.resThumb),
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                ),
              ),
              const SizedBox(height: 4),
              Text(p.keyword,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
