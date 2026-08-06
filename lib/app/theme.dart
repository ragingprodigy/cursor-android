import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CursorTheme {
  const CursorTheme._();

  static ThemeData dark() {
    const background = Color(0xFF0B0D12);
    const surface = Color(0xFF121620);
    const elevated = Color(0xFF191F2B);
    const border = Color(0xFF273142);
    const primary = Color(0xFF68C7BD);
    const secondary = Color(0xFF7FA6D8);
    const onSurface = Color(0xFFE8EDF7);
    const muted = Color(0xFFA8B3C7);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primary,
          onPrimary: background,
          secondary: secondary,
          onSecondary: background,
          surface: surface,
          onSurface: onSurface,
          error: const Color(0xFFFFB4AB),
          onError: const Color(0xFF690005),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
    );

    final bodyText = GoogleFonts.ibmPlexSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: onSurface, displayColor: onSurface);
    final textTheme = bodyText.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        color: onSurface,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        color: onSurface,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        color: onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        color: onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: bodyText.bodyMedium?.copyWith(color: muted),
      bodySmall: bodyText.bodySmall?.copyWith(color: muted),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: const CardThemeData(
        color: elevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: background,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
    );
  }
}
