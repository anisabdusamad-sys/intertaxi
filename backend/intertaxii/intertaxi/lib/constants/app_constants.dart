import 'package:flutter/material.dart';

/// InterTaxi App Constants
/// Centralized configuration for app-wide values
class AppConstants {
  // Animation durations (optimized for performance)
  static const Duration splashAnimationDuration = Duration(milliseconds: 800);
  static const Duration logoFadeDuration = Duration(milliseconds: 600);
  static const Duration logoScaleDuration = Duration(milliseconds: 700);
  static const Duration loadingIndicatorDuration = Duration(milliseconds: 1200);
  static const Duration splashMinDisplayTime = Duration(milliseconds: 2000);
  static const Duration buttonPressAnimation = Duration(milliseconds: 150);
  static const Duration fieldFocusAnimation = Duration(milliseconds: 200);
  static const Duration cardSelectionAnimation = Duration(milliseconds: 300);

  // Animation curves (smooth but performant)
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve logoFadeCurve = Curves.easeIn;
  static const Curve logoScaleCurve = Curves.easeOutCubic;
  static const Curve loadingCurve = Curves.linear;
  static const Curve buttonCurve = Curves.easeInOut;
  static const Curve fieldFocusCurve = Curves.easeInOut;
  static const Curve cardSelectionCurve = Curves.easeInOut;

  // Splash screen configuration
  static const double logoSize = 120.0;
  static const double logoScaleStart = 0.8;
  static const double logoScaleEnd = 1.0;
  static const double loadingIndicatorSize = 24.0;
  static const double loadingStrokeWidth = 2.5;

  // Spacing
  static const double splashPadding = 32.0;
  static const double logoTextSpacing = 24.0;
  static const double loadingTopSpacing = 48.0;
  static const double screenPadding = 24.0;
  static const double fieldSpacing = 16.0;
  static const double buttonSpacing = 24.0;
  static const double titleSpacing = 32.0;
  static const double cardSpacing = 16.0;

  // Typography
  static const double logoFontSize = 32.0;
  static const double taglineFontSize = 14.0;
  static const double welcomeTitleSize = 28.0;
  static const double welcomeSubtitleSize = 16.0;
  static const double fieldLabelSize = 14.0;
  static const double fieldTextSize = 16.0;
  static const double buttonTextSize = 16.0;
  static const double roleTitleSize = 24.0;
  static const double roleCardTitleSize = 20.0;
  static const double roleCardDescriptionSize = 14.0;

  // Input field configuration
  static const double fieldHeight = 56.0;
  static const double fieldBorderRadius = 12.0;
  static const double fieldBorderWidth = 1.5;

  // Button configuration
  static const double buttonHeight = 56.0;
  static const double buttonBorderRadius = 12.0;

  // Role card configuration
  static const double roleCardHeight = 180.0;
  static const double roleCardBorderRadius = 16.0;
  static const double roleCardIconSize = 56.0;

  // Validation
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int minBirthYear = 1900;
  static const int maxBirthYear = 2100;
  static const int minPhoneLength = 9;
  static const int maxPhoneLength = 15;

  // Prevent instantiation
  AppConstants._();
}
