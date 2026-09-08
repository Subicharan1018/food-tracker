import 'package:flutter/material.dart';

class AppColors {
  // Neutral Scale (carries ~95% of the UI)
  static const Color background = Color(0xFF0B0D10);
  static const Color surface = Color(0xFF151A21);
  static const Color card = Color(0xFF151A21);
  static const Color surfaceElevated = Color(0xFF1E2632);
  static const Color cardElevated = Color(0xFF1E2632);
  static const Color border = Color(0xFF262E38);
  static const Color borderSubtle = Color(0xFF1E2632);

  // Text Neutral Scale
  static const Color textPrimary = Color(0xFFF2F4F7);
  static const Color textSecondary = Color(0xFF8B95A3);
  static const Color textMuted = Color(0xFF5B6472);
  static const Color textInverse = Color(0xFF0B0D10);

  // The only two status verdict colors — never decorative
  /// Positive Green (#22C55E): Goal met / on-track / active streak (a real verdict)
  static const Color positive = Color(0xFF22C55E);

  /// Attention Amber (#F59E0B): Exceeded limit / plateau attention (a real verdict)
  static const Color attention = Color(0xFFF59E0B);

  // Destructive icon-only affordance exception (e.g. trash/delete glyphs)
  /// Destructive Red (#EF4444): Restricted to delete icons/dialogs only; never button fills or cards.
  static const Color destructive = Color(0xFFEF4444);
}

class AppTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const TextStyle statNum = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.textPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.textPrimary,
        secondary: AppColors.textSecondary,
        surface: AppColors.surface,
        error: AppColors.textSecondary,
        onPrimary: AppColors.textInverse,
        onSurface: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.textInverse,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.textInverse,
        elevation: 2,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.textPrimary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.textSecondary, width: 1.5),
        ),
        errorStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.surfaceElevated;
          }
          return AppColors.surface;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary.withValues(alpha: 0.5);
          }
          return AppColors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.textPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textInverse),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
