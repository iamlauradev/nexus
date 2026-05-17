import 'package:flutter/material.dart';
import '../theme/rpg_theme.dart';

class OrnamentalBorder extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const OrnamentalBorder({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OrnamentPainter(),
      child: Container(
        decoration: BoxDecoration(
          color: RpgColors.surface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: RpgColors.goldDark.withOpacity(0.6)),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = RpgColors.gold.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const c = 14.0; // corner ornament size
    const gap = 4.0;

    // Top-left corner
    _drawCorner(canvas, paint, Offset(gap, gap), c, 0);
    // Top-right corner
    _drawCorner(canvas, paint, Offset(size.width - gap, gap), c, 1);
    // Bottom-left corner
    _drawCorner(canvas, paint, Offset(gap, size.height - gap), c, 2);
    // Bottom-right corner
    _drawCorner(canvas, paint, Offset(size.width - gap, size.height - gap), c, 3);
  }

  void _drawCorner(Canvas canvas, Paint paint, Offset origin, double size, int quadrant) {
    final path = Path();
    switch (quadrant) {
      case 0: // top-left
        path.moveTo(origin.dx, origin.dy + size);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx + size, origin.dy);
        path.moveTo(origin.dx + 4, origin.dy + 4);
        path.lineTo(origin.dx + 4, origin.dy + size * 0.6);
        path.moveTo(origin.dx + 4, origin.dy + 4);
        path.lineTo(origin.dx + size * 0.6, origin.dy + 4);
        break;
      case 1: // top-right
        path.moveTo(origin.dx - size, origin.dy);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx, origin.dy + size);
        path.moveTo(origin.dx - 4, origin.dy + 4);
        path.lineTo(origin.dx - size * 0.6, origin.dy + 4);
        path.moveTo(origin.dx - 4, origin.dy + 4);
        path.lineTo(origin.dx - 4, origin.dy + size * 0.6);
        break;
      case 2: // bottom-left
        path.moveTo(origin.dx, origin.dy - size);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx + size, origin.dy);
        path.moveTo(origin.dx + 4, origin.dy - 4);
        path.lineTo(origin.dx + 4, origin.dy - size * 0.6);
        path.moveTo(origin.dx + 4, origin.dy - 4);
        path.lineTo(origin.dx + size * 0.6, origin.dy - 4);
        break;
      case 3: // bottom-right
        path.moveTo(origin.dx - size, origin.dy);
        path.lineTo(origin.dx, origin.dy);
        path.lineTo(origin.dx, origin.dy - size);
        path.moveTo(origin.dx - 4, origin.dy - 4);
        path.lineTo(origin.dx - size * 0.6, origin.dy - 4);
        path.moveTo(origin.dx - 4, origin.dy - 4);
        path.lineTo(origin.dx - 4, origin.dy - size * 0.6);
        break;
    }
    canvas.drawPath(path, paint);

    // Central dot
    canvas.drawCircle(origin, 2, Paint()..color = RpgColors.gold.withOpacity(0.8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Gold divider with ornamental center
class GoldDivider extends StatelessWidget {
  final String? label;
  const GoldDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, RpgColors.goldDark.withOpacity(0.8)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: label != null
            ? Text(label!, style: const TextStyle(
                fontFamily: 'Cinzel', color: RpgColors.gold,
                fontSize: 11, letterSpacing: 2,
              ))
            : Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  color: RpgColors.gold, shape: BoxShape.circle,
                ),
              ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [RpgColors.goldDark.withOpacity(0.8), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Rating badge chip
class RatingBadge extends StatelessWidget {
  final String? label;
  final double? fontSize;
  const RatingBadge({super.key, this.label, this.fontSize});

  @override
  Widget build(BuildContext context) {
    if (label == null || label == 'sin_valorar') return const SizedBox.shrink();
    final color = ratingColor(label);
    final text = ratingLabel(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.7)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize ?? 11,
          fontFamily: 'Crimson',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Status badge
class StatusBadge extends StatelessWidget {
  final String? status;
  const StatusBadge({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    final text = statusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontFamily: 'Crimson'),
      ),
    );
  }
}
