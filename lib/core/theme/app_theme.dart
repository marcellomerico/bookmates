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

/// Brand palette, warm in both modes. Widgets read it via `context.palette`;
/// the dark set is a reading-lamp brown, never black.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.cream,
    required this.parchment,
    required this.burgundy,
    required this.onBurgundy,
    required this.gold,
    required this.goldText,
    required this.inputBorder,
    required this.error,
    required this.ink,
    required this.muted,
    required this.line,
    required this.card,
    required this.success,
    required this.shelfWood,
    required this.shelfBack,
  });

  /// Page background.
  final Color cream;

  /// Soft fill: avatars, chips, empty tracks.
  final Color parchment;

  /// Accent for actions and highlights.
  final Color burgundy;

  /// Text and icons on [burgundy].
  final Color onBurgundy;
  final Color gold;
  final Color goldText;
  final Color inputBorder;
  final Color error;
  final Color ink;
  final Color muted;
  final Color line;

  /// Raised surfaces: cards, sheets, inputs.
  final Color card;
  final Color success;
  final Color shelfWood;
  final Color shelfBack;

  static const light = Palette(
    cream: Color(0xFFF7F2E8),
    parchment: Color(0xFFE9DDC8),
    burgundy: Color(0xFF7B3140),
    onBurgundy: Colors.white,
    gold: Color(0xFFC7A64B),
    goldText: Color(0xFF85661A),
    inputBorder: Color(0xFFA39079),
    error: Color(0xFFB3261E),
    ink: Color(0xFF2B221B),
    muted: Color(0xFF6F5F53),
    line: Color(0xFFE5D8C8),
    card: Colors.white,
    success: Color(0xFF4E7A5D),
    shelfWood: Color(0xFFC9A877),
    shelfBack: Color(0xFFEFE4D2),
  );

  static const dark = Palette(
    cream: Color(0xFF201A16),
    parchment: Color(0xFF3A2F28),
    burgundy: Color(0xFFCC7F8B),
    onBurgundy: Color(0xFF2A1418),
    gold: Color(0xFFD9B45A),
    goldText: Color(0xFFD9B45A),
    inputBorder: Color(0xFF7A685A),
    error: Color(0xFFF2B8B5),
    ink: Color(0xFFF3EBDD),
    muted: Color(0xFFBFAF9C),
    line: Color(0xFF3A2F28),
    card: Color(0xFF2B231E),
    success: Color(0xFF8DBF9C),
    shelfWood: Color(0xFF6B4E33),
    shelfBack: Color(0xFF2E2620),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      cream: l(cream, other.cream),
      parchment: l(parchment, other.parchment),
      burgundy: l(burgundy, other.burgundy),
      onBurgundy: l(onBurgundy, other.onBurgundy),
      gold: l(gold, other.gold),
      goldText: l(goldText, other.goldText),
      inputBorder: l(inputBorder, other.inputBorder),
      error: l(error, other.error),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      card: l(card, other.card),
      success: l(success, other.success),
      shelfWood: l(shelfWood, other.shelfWood),
      shelfBack: l(shelfBack, other.shelfBack),
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>() ?? Palette.light;
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
  static ThemeData get light => _build(Palette.light, Brightness.light);
  static ThemeData get dark => _build(Palette.dark, Brightness.dark);

  static ThemeData _build(Palette c, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.burgundy,
        primary: c.burgundy,
        secondary: c.gold,
        surface: c.card,
        error: c.error,
        brightness: brightness,
      ).copyWith(onPrimary: c.onBurgundy, onSurface: c.ink),
    );

    final serif = base.textTheme
        .apply(fontFamily: _serifFamily)
        .copyWith(
          displayLarge: _serif(
            color: c.ink,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
          displayMedium: _serif(
            color: c.ink,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          headlineLarge: _serif(
            color: c.ink,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
          headlineMedium: _serif(
            color: c.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
          headlineSmall: _serif(
            color: c.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          titleLarge: _serif(
            color: c.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          titleMedium: TextStyle(
            color: c.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          bodyLarge: TextStyle(
            color: c.ink,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            color: c.ink,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          bodySmall: TextStyle(
            color: c.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
          labelLarge: TextStyle(
            color: c.onBurgundy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          labelMedium: TextStyle(
            color: c.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );

    return base.copyWith(
      textTheme: serif,
      scaffoldBackgroundColor: c.cream,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      dividerColor: c.line,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.cream,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: serif.headlineSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        hintStyle: TextStyle(color: c.muted, fontSize: 14),
        labelStyle: TextStyle(color: c.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.m),
          borderSide: BorderSide(color: c.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.burgundy, width: 1.2),
        ),
      ),
      // One button language: 48 pt tall, 12 pt corners, semibold label.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.burgundy,
          foregroundColor: c.onBurgundy,
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
          backgroundColor: c.burgundy,
          foregroundColor: c.onBurgundy,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          backgroundColor: c.card,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          side: BorderSide(color: c.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.burgundy,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.burgundy,
        foregroundColor: c.onBurgundy,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.burgundy,
        disabledColor: c.card,
        side: BorderSide(color: c.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Selected chips sit on burgundy: white label, otherwise ink.
        // Chips resolve only the colour by state, so the colour carries it.
        labelStyle: TextStyle(
          color: WidgetStateColor.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? c.onBurgundy : c.ink,
          ),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        checkmarkColor: c.onBurgundy,
        secondaryLabelStyle: TextStyle(color: c.onBurgundy, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? c.burgundy : c.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? c.burgundy : c.muted,
            size: 24,
          );
        }),
      ),
    );
  }
}
