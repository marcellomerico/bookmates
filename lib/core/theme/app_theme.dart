import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

const _serifFamily = 'SourceSerif4';

// Bundled variable font (assets/fonts): the weight must also be set as an axis value.
TextStyle _serif({
  required Color color,
  required double fontSize,
  required FontWeight fontWeight,
  double? height,
}) {
  return TextStyle(
    fontFamily: _serifFamily,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontVariations: [FontVariation.weight(fontWeight.value.toDouble())],
    height: height,
  );
}

class AppColors {
  static const cream = Color(0xFFF7F2E8);
  static const parchment = Color(0xFFE9DDC8);
  static const burgundy = Color(0xFF7B3140);
  static const gold = Color(0xFFC7A64B);
  static const goldText = Color(0xFF85661A);
  static const inputBorder = Color(0xFFA39079);
  static const error = Color(0xFFB3261E);
  static const ink = Color(0xFF2B221B);
  static const muted = Color(0xFF6F5F53);
  static const line = Color(0xFFE5D8C8);
  static const card = Colors.white;
  static const success = Color(0xFF4E7A5D);
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0;
}

class AppRadius {
  AppRadius._();
  static const s = 8.0, m = 10.0, l = 12.0, xl = 16.0;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.burgundy,
        primary: AppColors.burgundy,
        secondary: AppColors.gold,
        surface: AppColors.card,
        error: AppColors.error,
        brightness: Brightness.light,
      ),
    );

    final serif = base.textTheme
        .apply(fontFamily: _serifFamily)
        .copyWith(
          displayLarge: _serif(
            color: AppColors.ink,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
          displayMedium: _serif(
            color: AppColors.ink,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          headlineLarge: _serif(
            color: AppColors.ink,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
          headlineMedium: _serif(
            color: AppColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
          headlineSmall: _serif(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          titleLarge: _serif(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          titleMedium: const TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          bodyLarge: const TextStyle(
            color: AppColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          bodyMedium: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          bodySmall: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
          labelLarge: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelMedium: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );

    return base.copyWith(
      textTheme: serif,
      scaffoldBackgroundColor: AppColors.cream,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      dividerColor: AppColors.line,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: serif.headlineSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.burgundy, width: 1.2),
        ),
      ),
      // One button language: 48 pt tall, 12 pt corners, semibold label.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.burgundy,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.burgundy,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.burgundy,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.burgundy,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.burgundy,
        disabledColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Selected chips sit on burgundy: white label, otherwise ink.
        // Chips resolve only the colour by state, so the colour carries it.
        labelStyle: TextStyle(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.ink,
          ),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        checkmarkColor: Colors.white,
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.burgundy : AppColors.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.burgundy : AppColors.muted,
            size: 24,
          );
        }),
      ),
    );
  }
}
