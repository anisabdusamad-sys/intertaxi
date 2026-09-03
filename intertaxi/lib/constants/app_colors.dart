import 'package:flutter/material.dart';

/// InterTaxi Design System Colors
/// Premium minimalist color palette - White and Blue theme
class AppColors {
  // Primary brand colors
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color lightBlue = Color(0xFFE6F0FF);
  static const Color darkBlue = Color(0xFF0047B3);
  static const Color accentBlue = Color(0xFF3385FF);

  // Background colors - White theme
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8FAFF);
  static const Color lightGray = Color(0xFFF5F7FA);
  static const Color splashBackground = Color(0xFFF8FBFF);

  // Dark theme colors (kept for reference)
  static const Color darkBackground = Color(0xFF0A0E27);
  static const Color darkSurface = Color(0xFF151B3D);
  static const Color darkCard = Color(0xFF1A2147);

  // Neutral colors
  static const Color black = Color(0xFF000000);
  static const Color gray900 = Color(0xFF1A1A1A);
  static const Color gray700 = Color(0xFF4A4A4A);
  static const Color gray600 = Color(0xFF666666);
  static const Color gray400 = Color(0xFF999999);
  static const Color gray300 = Color(0xFFCCCCCC);
  static const Color gray100 = Color(0xFFF5F5F5);

  // Semantic colors
  static const Color success = Color(0xFF00C853);
  static const Color error = Color(0xFFFF3D00);
  static const Color errorLight = Color(0xFFFFEBEE);

  // Text colors
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFB0B8D9);

  // Card colors - White theme
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8EDF5);
  static const Color cardSelected = Color(0xFFE6F0FF);

  // Input field colors
  static const Color inputBackground = Color(0xFFF5F7FA);
  static const Color inputBorder = Color(0xFFE0E5EF);
  static const Color inputFocusedBorder = Color(0xFF0066FF);

  // Gradient colors
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0066FF), Color(0xFF3385FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient lightGradient = LinearGradient(
    colors: [Color(0xFFE6F0FF), Color(0xFFF8FAFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Prevent instantiation
  AppColors._();
}
