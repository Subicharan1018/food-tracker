import 'package:flutter/material.dart';

/// Kinetik "Scoreboard" design system.
///
/// AMOLED black, one hot accent, and three typefaces with fixed jobs:
///  • Big Shoulders Display — the scoreboard: big numbers and condensed caps labels.
///  • IBM Plex Mono         — data: every quantity that gets compared.
///  • Instrument Sans       — prose: names, notes, explanations.
/// Structure comes from heavy rules and hairlines, not from boxes and tints.

class AppFonts {
  static const display = 'BigShoulders';
  static const mono = 'PlexMono';
  static const body = 'InstrumentSans';
}

class AppColors {
  // Ground and layers. Pure black with near-black planes for sheets/fields.
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color card = Color(0xFF0A0A0A);
  static const Color surfaceElevated = Color(0xFF161616);
  static const Color cardElevated = Color(0xFF161616);

  /// Hairlines between rows.
  static const Color border = Color(0xFF262626);
  static const Color borderSubtle = Color(0xFF171717);

  /// The heavy rule that opens every board.
  static const Color rule = Color(0xFFF2EFE8);

  /// Kinetik orange: navigation, the one primary action, and "you" in a chart.
  static const Color brandPrimary = Color(0xFFFF7A3D);

  // Warm off-white text scale.
  static const Color textPrimary = Color(0xFFF2EFE8);
  static const Color textSecondary = Color(0xFFA8A296);
  static const Color textMuted = Color(0xFF6E6A62);
  static const Color textInverse = Color(0xFF000000);

  // Verdicts only — never decoration, never a button fill.
  static const Color positive = Color(0xFF3DDC84);
  static const Color attention = Color(0xFFF5A524);

  /// Delete glyphs and destructive confirmations only.
  static const Color destructive = Color(0xFFFF5A4E);
}

/// Variable-font weight: Flutter maps `fontWeight` poorly onto a `wght` axis,
/// so every display/body style sets both.
List<FontVariation> _wght(double w) => [FontVariation('wght', w)];

class AppTypography {
  // ── Scoreboard (Big Shoulders Display) ─────────────────────────────
  /// The one number a screen is about (calories left, weight, sleep).
  static final TextStyle hero = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 76,
    height: 0.9,
    fontWeight: FontWeight.w800,
    fontVariations: _wght(800),
    letterSpacing: -1,
    color: AppColors.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final TextStyle displayLarge = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 48,
    height: 0.95,
    fontWeight: FontWeight.w800,
    fontVariations: _wght(800),
    color: AppColors.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static final TextStyle displayMedium = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 34,
    height: 1,
    fontWeight: FontWeight.w800,
    fontVariations: _wght(800),
    color: AppColors.textPrimary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Screen and sheet titles: condensed caps.
  static final TextStyle titleLarge = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 26,
    height: 1.05,
    fontWeight: FontWeight.w800,
    fontVariations: _wght(800),
    letterSpacing: 0.4,
    color: AppColors.textPrimary,
  );

  /// Board labels: small condensed caps, tracked out like stadium signage.
  static final TextStyle label = TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 14,
    height: 1.1,
    fontWeight: FontWeight.w700,
    fontVariations: _wght(700),
    letterSpacing: 1.6,
    color: AppColors.textSecondary,
  );

  // ── Prose (Instrument Sans) ────────────────────────────────────────
  static final TextStyle titleMedium = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    fontVariations: _wght(600),
    color: AppColors.textPrimary,
  );

  static final TextStyle bodyLarge = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    fontVariations: _wght(400),
    color: AppColors.textPrimary,
  );

  static final TextStyle bodyMedium = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    fontVariations: _wght(400),
    color: AppColors.textSecondary,
  );

  static final TextStyle labelSmall = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    fontVariations: _wght(500),
    color: AppColors.textMuted,
  );

  // ── Data (IBM Plex Mono) ───────────────────────────────────────────
  static const TextStyle data = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle dataSmall = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle statNum = TextStyle(
    fontFamily: AppFonts.mono,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Scoreboard geometry: nearly square. Rounded pills read as generic.
class AppShapes {
  static final BorderRadius information = BorderRadius.circular(4);
  static final BorderRadius action = BorderRadius.circular(4);
  static const double ruleHeavy = 2;
  static const double gutter = 20;
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, fontFamily: AppFonts.body);
    final square = RoundedRectangleBorder(borderRadius: AppShapes.action);
    final labelButton = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 17,
      fontWeight: FontWeight.w800,
      fontVariations: _wght(800),
      letterSpacing: 1.2,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.brandPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brandPrimary,
        onPrimary: AppColors.textInverse,
        secondary: AppColors.brandPrimary,
        onSecondary: AppColors.textInverse,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceElevated,
        outline: AppColors.border,
        outlineVariant: AppColors.borderSubtle,
        error: AppColors.destructive,
      ),
      textTheme: base.textTheme
          .apply(fontFamily: AppFonts.body, bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary)
          .copyWith(
            displayLarge: AppTypography.displayLarge,
            displayMedium: AppTypography.displayMedium,
            titleLarge: AppTypography.titleLarge,
            titleMedium: AppTypography.titleMedium,
            bodyLarge: AppTypography.bodyLarge,
            bodyMedium: AppTypography.bodyMedium,
            labelLarge: labelButton,
            labelSmall: AppTypography.labelSmall,
          ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppShapes.information,
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.textInverse,
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: labelButton,
          shape: square,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandPrimary,
          foregroundColor: AppColors.textInverse,
          minimumSize: const Size(64, 52),
          textStyle: labelButton,
          shape: square,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
          minimumSize: const Size(64, 48),
          textStyle: labelButton.copyWith(fontSize: 15),
          shape: square,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandPrimary,
          minimumSize: const Size(48, 44),
          textStyle: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontVariations: _wght(600),
          ),
          shape: square,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary, minimumSize: const Size(48, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.textInverse,
        elevation: 0,
        shape: square,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.label.copyWith(
            fontSize: 13,
            color: selected ? AppColors.brandPrimary : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected) ? AppColors.brandPrimary : AppColors.textMuted,
            )),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.textMuted,
        dragHandleSize: Size(36, 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: square,
        titleTextStyle: AppTypography.titleLarge,
        contentTextStyle: AppTypography.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textInverse),
        actionTextColor: AppColors.textInverse,
        behavior: SnackBarBehavior.floating,
        shape: square,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: square,
        labelStyle: AppTypography.label.copyWith(fontSize: 13),
        secondaryLabelStyle: AppTypography.label.copyWith(fontSize: 13, color: AppColors.textInverse),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        titleTextStyle: AppTypography.bodyLarge,
        subtitleTextStyle: AppTypography.dataSmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandPrimary,
        linearTrackColor: AppColors.surfaceElevated,
        linearMinHeight: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.brandPrimary, width: 2)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.attention)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.attention, width: 2)),
        labelStyle: AppTypography.label,
        floatingLabelStyle: AppTypography.label.copyWith(color: AppColors.brandPrimary),
        errorStyle: AppTypography.labelSmall.copyWith(color: AppColors.attention),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.textInverse : AppColors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.brandPrimary : AppColors.surfaceElevated),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.textPrimary : Colors.transparent),
        checkColor: WidgetStateProperty.all(AppColors.textInverse),
        side: const BorderSide(color: AppColors.textMuted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.brandPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.border,
        labelStyle: AppTypography.label.copyWith(fontSize: 16),
        unselectedLabelStyle: AppTypography.label.copyWith(fontSize: 16),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(2)),
        textStyle: AppTypography.labelSmall.copyWith(color: AppColors.textInverse),
      ),
    );
  }
}
