import 'package:flutter/widgets.dart';

abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}

const EdgeInsets paddingMd = EdgeInsets.all(Spacing.md);
const SizedBox gapSm = SizedBox(height: Spacing.sm, width: Spacing.sm);
const SizedBox gapMd = SizedBox(height: Spacing.md, width: Spacing.md);
