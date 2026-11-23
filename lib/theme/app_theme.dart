import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const emerald = Color(0xFF12685B);
  static const emeraldDark = Color(0xFF0B4F45);
  static const background = Color(0xFFF4F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceTint = Color(0xFFEAF3EF);
  static const border = Color(0xFFDCE7E1);
  static const text = Color(0xFF18312B);
  static const secondaryText = Color(0xFF5B7169);
  static const success = Color(0xFF24734D);
  static const warning = Color(0xFF9A5B12);
  static const danger = Color(0xFF9D3E3E);
  static const info = Color(0xFF376B9A);
}

abstract final class AppRadii {
  static const card = 20.0;
  static const control = 14.0;
  static const badge = 999.0;
}

abstract final class AppSpacing {
  static const page = 20.0;
  static const section = 20.0;
  static const content = 14.0;
  static const tight = 8.0;
}

abstract final class AqsaaTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.emerald,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppPalette.emerald,
          onPrimary: Colors.white,
          surface: AppPalette.surface,
          onSurface: AppPalette.text,
          outline: AppPalette.border,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.text,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.surface,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppPalette.emerald, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          side: const BorderSide(color: AppPalette.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.surfaceTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.border,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
