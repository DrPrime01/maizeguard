import 'package:flutter/material.dart';

import '../domain/models/disease_class.dart';

/// Visual identity. A single seeded Material 3 scheme keeps the app legible in
/// bright outdoor light, which is where it will actually be used.
abstract final class AppTheme {
  static const Color seed = Color(0xFF2E7D32);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    );
  }
}

/// One colour per class, used consistently by map pins, history rows, and the
/// result screen so a user learns the mapping once.
///
/// Chosen to stay distinguishable for the most common forms of colour-vision
/// deficiency: the four differ in lightness as well as hue, and every use is
/// paired with a text label rather than relying on colour alone.
extension DiseaseColour on DiseaseClass {
  Color get colour => switch (this) {
        DiseaseClass.msv => const Color(0xFFF9A825),         // amber
        DiseaseClass.commonRust => const Color(0xFFC62828),   // red
        DiseaseClass.greyLeafSpot => const Color(0xFF5E35B1), // deep purple
        DiseaseClass.healthy => const Color(0xFF2E7D32),      // green
      };

  /// Hue for a Google Maps default marker, matched to [colour].
  double get markerHue => switch (this) {
        DiseaseClass.msv => 45,          // BitmapDescriptor.hueOrange-ish
        DiseaseClass.commonRust => 0,    // hueRed
        DiseaseClass.greyLeafSpot => 270, // hueViolet
        DiseaseClass.healthy => 120,     // hueGreen
      };

  IconData get icon => switch (this) {
        DiseaseClass.msv => Icons.grass,
        DiseaseClass.commonRust => Icons.blur_on,
        DiseaseClass.greyLeafSpot => Icons.crop_square,
        DiseaseClass.healthy => Icons.check_circle_outline,
      };
}
