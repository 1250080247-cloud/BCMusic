import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.raised,
    required this.border,
    required this.text,
    required this.muted,
    required this.action,
    required this.onAction,
    required this.selection,
    required this.pink,
  });

  final Color background,
      surface,
      raised,
      border,
      text,
      muted,
      action,
      onAction;
  final Color selection, pink;

  static const dark = AppPalette(
    background: Color(0xff0b0d14),
    surface: Color(0xff141822),
    raised: Color(0xff1d2330),
    border: Color(0xff2c3240),
    text: Color(0xfff4f5fa),
    muted: Color(0xffa3adbf),
    action: Color(0xfff4f5fa),
    onAction: Color(0xff1d2330),
    selection: Color(0xff1d2330),
    pink: Color(0xffa3adbf),
  );
  static const light = AppPalette(
    background: Color(0xfff6f7fb),
    surface: Colors.white,
    raised: Color(0xffedf0f7),
    border: Color(0xffd8dee8),
    text: Color(0xff172033),
    muted: Color(0xff58677e),
    action: Color(0xff172033),
    onAction: Colors.white,
    selection: Color(0xffe9edf2),
    pink: Color(0xff172033),
  );
}

extension BCMusicPalette on BuildContext {
  AppPalette get palette => Theme.of(this).brightness == Brightness.light
      ? AppPalette.light
      : AppPalette.dark;
}

ButtonStyle playButtonStyle(BuildContext context) {
  final palette = context.palette;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? null : palette.text,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled) ? null : palette.background,
    ),
  );
}

ThemeData bcmusicTheme({bool light = false}) {
  final colors = light ? AppPalette.light : AppPalette.dark;
  final brightness = light ? Brightness.light : Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: colors.pink,
          brightness: brightness,
        ).copyWith(
          primary: colors.action,
          onPrimary: colors.onAction,
          surface: colors.surface,
          onSurface: colors.text,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.background,
      showDragHandle: true,
    ),
    dividerColor: colors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.raised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.raised,
      selectedColor: colors.action,
      side: BorderSide(color: colors.border),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(
        color: colors.onAction,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: colors.onAction,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.background,
      indicatorColor: colors.selection,
      height: 72,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
