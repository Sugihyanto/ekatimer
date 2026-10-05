import 'package:flutter/material.dart';

/// Meditation Timer Design System
/// A quiet dawn palette — cool, ethereal, breathable.
class AppColors {
  // ── Primary: Dew-Drop Blue ──
  static const Color primary = Color(0xFF356668);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFA8DADC);
  static const Color onPrimaryContainer = Color(0xFF306163);
  static const Color primaryFixed = Color(0xFFB9ECEE);
  static const Color primaryFixedDim = Color(0xFF9ECFD1);
  static const Color onPrimaryFixed = Color(0xFF002021);
  static const Color onPrimaryFixedVariant = Color(0xFF1A4E50);

  // ── Secondary: Mist Silver ──
  static const Color secondary = Color(0xFF535E77);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD4DFFD);
  static const Color onSecondaryContainer = Color(0xFF58637C);
  static const Color secondaryFixed = Color(0xFFD8E2FF);
  static const Color secondaryFixedDim = Color(0xFFBBC6E3);
  static const Color onSecondaryFixed = Color(0xFF101B31);
  static const Color onSecondaryFixedVariant = Color(0xFF3C475F);

  // ── Tertiary: Soft Lavender ──
  static const Color tertiary = Color(0xFF65587A);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFDBCAF2);
  static const Color onTertiaryContainer = Color(0xFF605375);
  static const Color tertiaryFixed = Color(0xFFECDCFF);
  static const Color tertiaryFixedDim = Color(0xFFD0C0E7);
  static const Color onTertiaryFixed = Color(0xFF211633);
  static const Color onTertiaryFixedVariant = Color(0xFF4D4161);

  // ── Surfaces (Light) — Morning Mist ──
  static const Color surfaceLight = Color(0xFFF8FAFB);
  static const Color onSurfaceLight = Color(0xFF191C1D);
  static const Color surfaceDim = Color(0xFFD8DADB);
  static const Color surfaceBright = Color(0xFFF8FAFB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F5);
  static const Color surfaceContainer = Color(0xFFECEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE6E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  static const Color surfaceVariant = Color(0xFFE1E3E4);
  static const Color onSurfaceVariant = Color(0xFF404848);

  // ── Outlines ──
  static const Color outline = Color(0xFF707979);
  static const Color outlineVariant = Color(0xFFC0C8C8);

  // ── Inverse ──
  static const Color inverseSurface = Color(0xFF2E3132);
  static const Color inverseOnSurface = Color(0xFFEFF1F2);
  static const Color inversePrimary = Color(0xFF9ECFD1);

  // ── Semantic ──
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF2E7D6F);
  static const Color warning = Color(0xFFE07B3A);

  // ═══════════════════════════════════════
  //  Dark Mode
  // ═══════════════════════════════════════

  // ── Primary (Dark) ──
  static const Color primaryDark = Color(0xFF9ECFD1);
  static const Color onPrimaryDark = Color(0xFF002021);
  static const Color primaryContainerDark = Color(0xFF1A4E50);
  static const Color onPrimaryContainerDark = Color(0xFFB9ECEE);

  // ── Secondary (Dark) ──
  static const Color secondaryDark = Color(0xFFBBC6E3);
  static const Color onSecondaryDark = Color(0xFF101B31);
  static const Color secondaryContainerDark = Color(0xFF3C475F);
  static const Color onSecondaryContainerDark = Color(0xFFD8E2FF);

  // ── Tertiary (Dark) ──
  static const Color tertiaryDark = Color(0xFFD0C0E7);
  static const Color onTertiaryDark = Color(0xFF211633);
  static const Color tertiaryContainerDark = Color(0xFF4D4161);
  static const Color onTertiaryContainerDark = Color(0xFFECDCFF);

  // ── Surfaces (Dark) ──
  static const Color surfaceDark = Color(0xFF1A1C1D);
  static const Color onSurfaceDark = Color(0xFFE1E3E4);
  static const Color surfaceDimDark = Color(0xFF141617);
  static const Color surfaceBrightDark = Color(0xFF2E3132);
  static const Color surfaceContainerLowestDark = Color(0xFF111314);
  static const Color surfaceContainerLowDark = Color(0xFF1C1E1F);
  static const Color surfaceContainerDark = Color(0xFF202223);
  static const Color surfaceContainerHighDark = Color(0xFF2B2D2E);
  static const Color surfaceContainerHighestDark = Color(0xFF353738);
  static const Color surfaceVariantDark = Color(0xFF404848);
  static const Color onSurfaceVariantDark = Color(0xFFC0C8C8);

  // ── Semantic (Dark) ──
  static const Color errorDark = Color(0xFFFFDAD6);
  static const Color onErrorDark = Color(0xFF93000A);
  static const Color errorContainerDark = Color(0xFF93000A);
  static const Color onErrorContainerDark = Color(0xFFFFDAD6);

  // ── Outlines (Dark) ──
  static const Color outlineDark = Color(0xFF8A9393);
  static const Color outlineVariantDark = Color(0xFF404848);

  // ═══════════════════════════════════════
  //  Backward-compatible aliases
  // ═══════════════════════════════════════

  static const Color primaryLight = primaryContainer;
  static const Color accent = onPrimaryFixedVariant;
  static const Color accentLight = tertiaryFixedDim;
  static const Color accentDark = onTertiaryFixed;
  static const Color backgroundLight = surfaceBright;
  static const Color textPrimaryLight = onSurfaceLight;
  static const Color textSecondaryLight = onSurfaceVariant;

  static const Color backgroundDark = surfaceDark;
  static const Color cardDark = surfaceContainerHighDark;
  static const Color textPrimaryDark = onSurfaceDark;
  static const Color textSecondaryDark = onSurfaceVariantDark;

  // ═══════════════════════════════════════
  //  Gradients
  // ═══════════════════════════════════════

  // Light mode gradients
  static const List<Color> gradientSunrise = [
    Color(0xFFB9ECEE),
    Color(0xFFDBCAF2),
  ];

  static const List<Color> gradientSunset = [
    Color(0xFFDBCAF2),
    Color(0xFFFFDAD6),
  ];

  static const List<Color> gradientOcean = [
    Color(0xFFA8DADC),
    Color(0xFFD4DFFD),
  ];

  static const List<Color> gradientForest = [
    Color(0xFFA8DADC),
    Color(0xFFC8E6E0),
  ];

  static const List<Color> gradientNight = [
    Color(0xFF191C1D),
    Color(0xFF2E3132),
  ];

  static const List<Color> gradientCalm = [
    Color(0xFFF2F4F5),
    Color(0xFFE1E3E4),
  ];

  // Dark mode gradients
  static const List<Color> gradientSunriseDark = [
    Color(0xFF1A4E50),
    Color(0xFF4D4161),
  ];

  static const List<Color> gradientSunsetDark = [
    Color(0xFF4D4161),
    Color(0xFF7A2E3A),
  ];

  static const List<Color> gradientOceanDark = [
    Color(0xFF306163),
    Color(0xFF3C475F),
  ];

  static const List<Color> gradientNightDark = [
    Color(0xFF0A0C0D),
    Color(0xFF141617),
    Color(0xFF1A1C1D),
  ];
}
