import 'package:flutter/material.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

/// Colores del mockup (convertidos de OKLCH a sRGB). Contraste verificado WCAG 2.2 AA
/// para texto normal sobre los fondos donde se usan (ver test/core/theme_contrast_test.dart).
abstract final class IcexColors {
  static const primary = Color(0xFFC50516); // rojo ICEX
  static const Color onPrimary = Colors.white;
  static const accent = Color(0xFFF8C20D); // amarillo ICEX
  static const onAccent = Color(0xFF221811);
  static const promoTag = Color(0xFFFDEDB6); // amarillo al 30 %
  static const foreground = Color(0xFF1A1413);
  static const mutedForeground = Color(0xFF635C59);
  static const muted = Color(0xFFF3EFED);
  static const border = Color(0xFFE7E4E1);
  static const page = Color(0xFFF9F6F4);
  static const Color card = Colors.white;
  static const secondary = Color(0xFFF8F4F2);
  static const destructive = Color(0xFFE7000B);

  static const phase0 = Color(0xFF8A7E75);
  static const phase1 = Color(0xFFE78B30);
  static const phase2 = Color(0xFFDA4620);
  static const Color phaseActive = primary;

  static Color phase(Fase f) => switch (f) {
    Fase.fase0 => phase0,
    Fase.fase1 => phase1,
    Fase.fase2 => phase2,
    Fase.activo => phaseActive,
  };

  /// Texto sobre el badge de fase (Fase I usa texto oscuro, como el mockup).
  static Color onPhase(Fase f) => f == Fase.fase1 ? onAccent : Colors.white;
}

abstract final class IcexTheme {
  static const radius = 12.0;
  static const display = 'Sora';
  static const body = 'DM Sans';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: IcexColors.primary,
      primary: IcexColors.primary,
      onPrimary: IcexColors.onPrimary,
      secondary: IcexColors.accent,
      onSecondary: IcexColors.onAccent,
      surface: IcexColors.card,
      onSurface: IcexColors.foreground,
      onSurfaceVariant: IcexColors.mutedForeground,
      outline: IcexColors.border,
      outlineVariant: IcexColors.border,
      error: IcexColors.destructive,
    );
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radius)));
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: body);
    return base.copyWith(
      scaffoldBackgroundColor: IcexColors.page,
      textTheme: base.textTheme
          .apply(bodyColor: IcexColors.foreground, displayColor: IcexColors.foreground)
          .copyWith(
            headlineLarge: const TextStyle(
              fontFamily: display,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            headlineMedium: const TextStyle(
              fontFamily: display,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
            headlineSmall: const TextStyle(
              fontFamily: display,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            titleLarge: const TextStyle(
              fontFamily: display,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            titleMedium: const TextStyle(
              fontFamily: display,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            titleSmall: const TextStyle(
              fontFamily: body,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(fontFamily: body, fontSize: 16, height: 1.5),
            bodyMedium: const TextStyle(fontFamily: body, fontSize: 14, height: 1.45),
            bodySmall: const TextStyle(
              fontFamily: body,
              fontSize: 12.5,
              color: IcexColors.mutedForeground,
            ),
            labelLarge: const TextStyle(
              fontFamily: body,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: IcexColors.card,
        foregroundColor: IcexColors.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: IcexColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          side: BorderSide(color: IcexColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: IcexColors.border, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: IcexColors.primary,
          foregroundColor: IcexColors.onPrimary,
          minimumSize: const Size(48, 44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: body, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IcexColors.foreground,
          minimumSize: const Size(48, 40),
          side: const BorderSide(color: IcexColors.border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: IcexColors.foreground,
          minimumSize: const Size(48, 44),
        ),
      ),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: IcexColors.border)),
        backgroundColor: IcexColors.card,
        selectedColor: IcexColors.foreground,
        labelStyle: TextStyle(fontFamily: body, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: TextStyle(color: Colors.white),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IcexColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: IcexColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: IcexColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: IcexColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: IcexColors.mutedForeground),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: IcexColors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: IcexColors.primary.withValues(alpha: 0.08),
        indicatorShape: shape,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: body,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? IcexColors.primary
                : IcexColors.mutedForeground,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? IcexColors.primary
                : IcexColors.mutedForeground,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
