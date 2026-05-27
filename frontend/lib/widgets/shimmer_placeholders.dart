import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/rpg_theme.dart';
import '../utils/responsive.dart';

// ---------------------------------------------------------------------------
// Shimmer base
// ---------------------------------------------------------------------------

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: RpgColors.surfaceHigh,
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
    );
  }
}

Widget _shimmerWrap(Widget child) {
  return Shimmer.fromColors(
    baseColor: RpgColors.surface,
    highlightColor: RpgColors.surfaceHigh,
    child: child,
  );
}

// ---------------------------------------------------------------------------
// ShimmerGrid — placeholder for MediaListScreen loading state
// ---------------------------------------------------------------------------

class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  const ShimmerGrid({super.key, this.itemCount = 12});

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;
    return _shimmerWrap(
      GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.52,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) => _ShimmerCard(),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: RpgColors.surfaceHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShimmerBox(width: double.infinity, height: 10),
                SizedBox(height: 4),
                const _ShimmerBox(width: 60, height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ShimmerList — placeholder for list view
// ---------------------------------------------------------------------------

class ShimmerList extends StatelessWidget {
  final int itemCount;
  const ShimmerList({super.key, this.itemCount = 10});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      ListView.builder(
        padding: const EdgeInsets.all(12),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => _ShimmerListTile(),
      ),
    );
  }
}

class _ShimmerListTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: RpgColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: RpgColors.border, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 58,
            decoration: BoxDecoration(
              color: RpgColors.surfaceHigh,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ShimmerBox(width: double.infinity, height: 14),
                SizedBox(height: 6),
                const _ShimmerBox(width: 100, height: 10),
                SizedBox(height: 8),
                const _ShimmerBox(width: 140, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ShimmerStatCard — placeholder for stats screen
// ---------------------------------------------------------------------------

class ShimmerStatCard extends StatelessWidget {
  final double height;
  const ShimmerStatCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      Container(
        height: height,
        decoration: BoxDecoration(
          color: RpgColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: RpgColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ShimmerBox(width: 80, height: 12),
            SizedBox(height: 8),
            const _ShimmerBox(width: 40, height: 24),
            const Spacer(),
            const _ShimmerBox(width: double.infinity, height: 8),
          ],
        ),
      ),
    );
  }
}
