
import 'package:flutter/cupertino.dart';

// --- Semantic Colors (Light / Dark) ---
class AppColors {
  // Backgrounds
  static const bgPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF0F2F5), // Refined off-white
    darkColor: Color(0xFF000000), // Pure black for OLED
  );
  static const bgSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF1C1C1E),
  );
  static const bgTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF2C2C2E),
  );

  // Text
  static const textPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF1D1D1F),
    darkColor: Color(0xFFFFFFFF),
  );
  static const textSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF86868B),
    darkColor: Color(0xFF98989D),
  );
  static const textTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD1D1D6),
    darkColor: Color(0xFF48484A),
  );

  // Separators & Borders
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC6C6C8),
    darkColor: Color(0xFF38383A),
  );
  
  // Functional Colors
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF007AFF),
    darkColor: Color(0xFF0A84FF),
  );
  static const success = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF34C759),
    darkColor: Color(0xFF30D158),
  );
  static const warning = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF9500),
    darkColor: Color(0xFFFF9F0A),
  );
  static const danger = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF3B30),
    darkColor: Color(0xFFFF453A),
  );
  static const heart = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF2D55),
    darkColor: Color(0xFFFF375F),
  );

  // Glass Enhancements
  static const glassBorder = CupertinoDynamicColor.withBrightness(
    color: Color(0x33FFFFFF),
    darkColor: Color(0x1FFFFFFF),
  );
}

// --- Typography (San Francisco -ish) ---
class AppTypography {
  static const largeTitle = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Display',
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.37,
    height: 1.2,
    color: CupertinoColors.label,
  );
  
  static const title1 = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Display',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.36,
    height: 1.2,
    color: CupertinoColors.label,
  );

  static const title2 = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Display',
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.35,
    height: 1.27,
    color: CupertinoColors.label,
  );

  static const headline = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Text',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.3,
    color: CupertinoColors.label,
  );

  static const body = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Text',
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.3,
    color: CupertinoColors.label,
  );

  static const subheadline = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Text',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.3,
    color: CupertinoColors.secondaryLabel,
  );

  static const footnote = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Text',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.3,
    color: CupertinoColors.secondaryLabel,
  );
  
  static const caption = TextStyle(
    inherit: false,
    fontFamily: '.SF Pro Text',
    fontSize: 12.5, // Increased from 11 for readability
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.3,
    color: CupertinoColors.tertiaryLabel,
  );
}

// --- Layout & Spacing ---
class AppSpacing {
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  
  static const double cardPadding = 20.0;
  static const double screenPadding = 16.0;
}

// --- Radius ---
class AppRadius {
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
}

// --- Glass Styles ---
class GlassStyle {
  static const double blurAmount = 20.0;
  static const double opacityLight = 0.7;
  static const double opacityDark = 0.6;
}
