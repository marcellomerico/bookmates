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
  static const ink = Color(0xFF2B221B);
  static const muted = Color(0xFF8A796C);
  static const line = Color(0xFFE5D8C8);
  static const card = Colors.white;
  static const success = Color(0xFF4E7A5D);
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
        brightness: Brightness.light,
      ),
    );

    final serif = base.textTheme.apply(fontFamily: _serifFamily).copyWith(
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
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.burgundy, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.burgundy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(44),
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.burgundy,
        disabledColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: const TextStyle(color: AppColors.ink, fontSize: 12),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
