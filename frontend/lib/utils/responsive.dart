import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  bool get isDesktop => MediaQuery.of(this).size.width >= 700;
}
