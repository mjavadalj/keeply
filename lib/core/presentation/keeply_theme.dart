import 'package:flutter/material.dart';

class KeeplyTheme {
  static ColorScheme get lightScheme => ColorScheme.fromSeed(
        seedColor: const Color(0xff2f6b59),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xff286b58),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xffc9eadb),
        onPrimaryContainer: const Color(0xff09251b),
        secondary: const Color(0xff42666a),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xffc9e6e5),
        onSecondaryContainer: const Color(0xff102f31),
        tertiary: const Color(0xff9b5d3b),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xffffdcc8),
        onTertiaryContainer: const Color(0xff3a170a),
        surface: const Color(0xfff7faf7),
        onSurface: const Color(0xff17201c),
      );

  static ColorScheme get darkScheme => ColorScheme.fromSeed(
        seedColor: const Color(0xff9ed0b3),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xff9bd7bd),
        onPrimary: const Color(0xff07382a),
        primaryContainer: const Color(0xff15533f),
        onPrimaryContainer: const Color(0xffb8f1d5),
        secondary: const Color(0xffa7d0d0),
        onSecondary: const Color(0xff12383a),
        secondaryContainer: const Color(0xff2b4d4e),
        onSecondaryContainer: const Color(0xffc3ebeb),
        tertiary: const Color(0xffffb995),
        onTertiary: const Color(0xff59250f),
        tertiaryContainer: const Color(0xff783f25),
        onTertiaryContainer: const Color(0xffffdbc8),
        surface: const Color(0xff101815),
        onSurface: const Color(0xffe0e9e3),
      );

  static ThemeData light(ColorScheme scheme) =>
      _theme(scheme, Brightness.light);

  static ThemeData dark(ColorScheme scheme) => _theme(scheme, Brightness.dark);

  static ThemeData _theme(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return base.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
        ),
      ),
    );
  }
}
