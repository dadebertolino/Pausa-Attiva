import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/arasaac_api.dart';
import '../../domain/enums.dart';
import '../../domain/models.dart';
import '../providers.dart';
import 'pose_animation.dart';

/// Rendering unico di un pittogramma, qualunque sia la fonte (spec §7).
/// ARASAAC: prima il file su disco (funziona senza rete), poi la rete.
class PictogramView extends ConsumerWidget {
  const PictogramView({
    super.key,
    required this.pictogram,
    this.size = 96,
    this.animate = false,
  });

  final PictogramRef pictogram;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget child = switch (pictogram.source) {
      PictogramSource.own => PoseAnimation(
          movementId: pictogram.ref,
          size: size,
          animate: animate,
        ),
      PictogramSource.arasaac => _arasaac(ref),
      PictogramSource.photo => Icon(Icons.photo, size: size * 0.5),
    };
    return SizedBox.square(dimension: size, child: child);
  }

  Widget _arasaac(WidgetRef ref) {
    final id = int.tryParse(pictogram.ref);
    if (id == null) return Icon(Icons.broken_image, size: size * 0.5);

    final file = ref.watch(arasaacApiProvider).localFile(id);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain, gaplessPlayback: true);
    }
    return CachedNetworkImage(
      imageUrl: ArasaacApi.imageUrl(id),
      fit: BoxFit.contain,
      placeholder: (_, _) => const Center(
        child: SizedBox.square(
            dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => Icon(Icons.cloud_off, size: size * 0.4),
    );
  }
}
