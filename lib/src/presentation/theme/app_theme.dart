import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color _seed = Color(0xFF00897B);

  static final ThemeData light = ThemeData(colorSchemeSeed: _seed);
}
