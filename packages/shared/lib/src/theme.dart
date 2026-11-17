import 'package:flutter/material.dart';

/// App theme. Emergency red is reserved for active-session affordances only.
class GuardianTheme {
  const GuardianTheme._();

  static const emergencyRed = Color(0xFFD32F2F);
  static const safeGreen = Color(0xFF2E7D32);
  static const seed = Color(0xFF1565C0);

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seed),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ),
  );
}
