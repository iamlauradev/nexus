/// Compact stat display chip — used in home screen summary and stats screen.
library;

import 'package:flutter/material.dart';
import '../../theme/rpg_theme.dart';

class StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final IconData? icon;

  const StatChip({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? RpgColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: RpgColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: c, size: 16),
            const SizedBox(height: 4),
          ],
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 10,
              color: RpgColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
