import 'package:flutter/material.dart';

// Palette reference:
//   Primary   #2E7D32  Forest Green
//   Secondary #B87333  Copper
//   Surface   #F5F5F5
//   Text      #1A1A1B / #757575 (muted)
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color secondary = Color(0xFFB87333);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF1A1A1B);
  static const Color textMuted = Color(0xFF757575);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      surface: surface,
      primary: primary,
      secondary: secondary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['Roboto'],
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['Roboto'],
        color: textPrimary,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['Roboto'],
        color: textMuted,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['Roboto'],
        color: textMuted,
      ),
    ),
  );
}
