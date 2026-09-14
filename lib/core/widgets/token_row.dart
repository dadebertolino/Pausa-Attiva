import 'package:flutter/material.dart';

import '../theme.dart';

/// Gettoni di completamento: si riempiono, senza punteggio (spec §4.6).
class TokenRow extends StatelessWidget {
  const TokenRow({
    super.key,
    required this.filled,
    required this.total,
    this.size = 36,
  });

  final int filled;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Gettoni: $filled di $total',
        child: Wrap(
          spacing: size * 0.3,
          runSpacing: size * 0.3,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? AppColors.work : Colors.transparent,
                  border: Border.all(color: AppColors.work, width: size * 0.1),
                ),
              ),
          ],
        ),
      );
}
