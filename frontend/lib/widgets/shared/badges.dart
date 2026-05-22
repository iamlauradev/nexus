/// Additional badge widgets — StatusBadge/RatingBadge/EmissionBadge
/// already live in ornamental_border.dart (kept for backward compat).
/// This file adds TypeChip, a new widget not previously available.
library;

import 'package:flutter/material.dart';
import '../../theme/rpg_theme.dart';

// ---------------------------------------------------------------------------
// TypeChip — colored pill for media type
// ---------------------------------------------------------------------------

class TypeChip extends StatelessWidget {
  final String? type;
  const TypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: RpgColors.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        typeLabel(type),
        style: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 10,
          color: RpgColors.textMuted,
        ),
      ),
    );
  }
}
