import 'package:flutter/material.dart';
import '../theme/rpg_theme.dart';

// Section divider with optional label
class GoldDivider extends StatelessWidget {
  final String? label;
  const GoldDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: RpgColors.border)),
        if (label != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label!, style: TextStyle(
              color: RpgColors.textMuted,
              fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w500,
            )),
          )
        else
          SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: RpgColors.border)),
      ],
    );
  }
}

// Rating badge using dynamic config
class RatingBadge extends StatelessWidget {
  final String? label;
  final double? fontSize;
  const RatingBadge({super.key, this.label, this.fontSize});

  @override
  Widget build(BuildContext context) {
    if (label == null || label == 'sin_valorar') return const SizedBox.shrink();
    final color = RatingConfigCache.colorFor(label);
    final text = RatingConfigCache.labelFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize ?? 11,
          fontFamily: 'DMSans',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Emission status badge
class EmissionBadge extends StatelessWidget {
  final String? status;
  const EmissionBadge({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final label = emissionLabel(status);
    if (label.isEmpty) return const SizedBox.shrink();
    final color = emissionColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'DMSans', fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// User watching status badge
class StatusBadge extends StatelessWidget {
  final String? status;
  const StatusBadge({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final text = statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontFamily: 'DMSans', fontWeight: FontWeight.w500),
      ),
    );
  }
}

// Legacy compat: OrnamentalBorder → simple card
class OrnamentalBorder extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const OrnamentalBorder({super.key, required this.child, this.padding = const EdgeInsets.all(24)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RpgColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RpgColors.border),
      ),
      padding: padding,
      child: child,
    );
  }
}
