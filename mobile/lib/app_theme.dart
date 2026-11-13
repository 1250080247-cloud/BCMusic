import 'dart:ui';
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

  // Chuẩn bảng màu từ index.css (.app, .glass, .primary-button, .chip.selected)
  static const dark = AppPalette(
    background: Color(0xff0b0d14),
    surface: Color(0xff161a25),
    raised: Color(0xff202231),
    border: Color(0x28c1c7ed),
    text: Color(0xfff4f5fa),
    muted: Color(0xff8e849e),
    action: Color(0xffd6cafa),
    onAction: Color(0xff211a31),
    selection: Color(0x2ba58bb3),
    pink: Color(0xffc2abf3),
  );

  static const light = AppPalette(
    background: Color(0xfff6f7fb),
    surface: Colors.white,
    raised: Color(0xffedf0f7),
    border: Color(0xffd8dee8),
    text: Color(0xff172033),
    muted: Color(0xff58677e),
    action: Color(0xff6f4ca8),
    onAction: Colors.white,
    selection: Color(0xffece6f8),
    pink: Color(0xff6f4ca8),
  );
}

extension BCMusicPalette on BuildContext {
  AppPalette get palette => Theme.of(this).brightness == Brightness.light
      ? AppPalette.light
      : AppPalette.dark;
}

ButtonStyle playButtonStyle(BuildContext context) {
  final isLight = Theme.of(context).brightness == Brightness.light;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      return isLight ? const Color(0xff211a31) : const Color(0xffd9ccf6);
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      return isLight ? Colors.white : const Color(0xff211a31);
    }),
    overlayColor: const WidgetStatePropertyAll(Color(0x24ffffff)),
    elevation: const WidgetStatePropertyAll(0),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
  );
}

ThemeData bcmusicTheme({bool light = false}) {
  final colors = light ? AppPalette.light : AppPalette.dark;
  final brightness = light ? Brightness.light : Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'BeVietnamPro',
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.pink,
      brightness: brightness,
    ).copyWith(
      primary: colors.pink,
      onPrimary: colors.onAction,
      surface: colors.surface,
      onSurface: colors.text,
      onSurfaceVariant: colors.muted,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: colors.text,
    ),
    cardTheme: CardThemeData(
      color: colors.surface.withValues(alpha: 0.72),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: const Color(0xff171b27),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
    ),
    dividerColor: colors.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.raised.withValues(alpha: 0.65),
      hintStyle: TextStyle(color: colors.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0x88c2abf3), width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xffd9ccf6),
        foregroundColor: const Color(0xff211a31),
        minimumSize: const Size(48, 46),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'BeVietnamPro',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xa1191c27),
      selectedColor: const Color(0x38a58bb3),
      side: BorderSide(color: colors.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: 'BeVietnamPro',
        color: colors.muted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: 'BeVietnamPro',
        color: colors.text,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      checkmarkColor: colors.pink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: const Color(0x33c1a4e0),
      height: 70,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Tái tạo class `.glass` trong index.css
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.margin,
    this.blur = 28,
    this.gradient,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Ink(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: gradient ??
                      const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x99292a3b),
                          Color(0xcc161a25),
                          Color(0xd91c1f2a),
                        ],
                      ),
                  border: Border.all(
                    color: borderColor ?? const Color(0x24c1c7ed),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
    return box;
  }
}

/// Biểu tượng sóng nhạc Equalizer giống `<Eq />` trong App.tsx
class EqualizerBars extends StatelessWidget {
  const EqualizerBars({
    super.key,
    this.active = true,
    this.color = const Color(0xffc5b3e9),
    this.size = 18,
  });

  final bool active;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    const heights = [0.4, 0.85, 1.0, 0.55, 0.78];
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final h in heights)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 2.2,
              height: size * (active ? h : 0.35),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}