import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  double get _w => MediaQuery.of(this).size.width;

  // Four-tier breakpoint system
  bool get isMobile  => _w < 600;
  bool get isTablet  => _w >= 600 && _w < 1024;
  bool get isDesktop => _w >= 1024;
  bool get isWide    => _w >= 1440;

  // Convenience groups
  bool get isNarrow    => _w < 600;               // phones only
  bool get isMediumUp  => _w >= 600;              // tablet+
  bool get isDesktopUp => _w >= 1024;             // desktop+

  // Grid column counts based on width
  int get gridColumns {
    if (_w >= 1440) return 6;
    if (_w >= 1024) return 5;
    if (_w >= 768)  return 4;
    if (_w >= 600)  return 3;
    return 2;
  }

  // Responsive horizontal padding
  double get pagePadding {
    if (_w >= 1440) return 48.0;
    if (_w >= 1024) return 32.0;
    if (_w >= 600)  return 20.0;
    return 12.0;
  }

  // Max content width (keeps desktop layouts from stretching too wide)
  double get maxContentWidth {
    if (_w >= 1440) return 1320.0;
    if (_w >= 1024) return 960.0;
    return double.infinity;
  }
}

/// Wraps a child in a centered container with maxContentWidth.
class ContentConstraint extends StatelessWidget {
  final Widget child;
  const ContentConstraint({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final max = context.maxContentWidth;
    if (max == double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}
