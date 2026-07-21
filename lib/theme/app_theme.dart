import 'dart:ui';

import 'package:flutter/material.dart';

abstract final class NovaColors {
  static const fallbackPrimary = Color(0xFF8E2434);
  static const lightCanvas = Color(0xFFF6F4F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF0ECE9);
  static const lightText = Color(0xFF211D1F);
  static const lightMuted = Color(0xFF746D70);
  static const lightBorder = Color(0xFFE5DFDC);
  static const darkCanvas = Color(0xFF111011);
  static const darkSurface = Color(0xFF1B191A);
  static const darkSurfaceSubtle = Color(0xFF272425);
  static const darkText = Color(0xFFF8F4F5);
  static const darkMuted = Color(0xFFB9B1B4);
  static const darkBorder = Color(0xFF3A3537);
  static const success = Color(0xFF2F8B67);
  static const warning = Color(0xFFD08022);
  static const critical = Color(0xFFC74747);
  static const information = Color(0xFF477EBA);
}

abstract final class NovaSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 40.0;
}

abstract final class NovaRadius {
  static const control = 12.0;
  static const input = 16.0;
  static const card = 22.0;
  static const panel = 28.0;
  static const sheet = 30.0;
}

abstract final class NovaIconSize {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class NovaMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const emphasized = Duration(milliseconds: 360);
}

abstract final class NovaElevation {
  static const none = 0.0;
  static const raised = 3.0;
  static const overlay = 12.0;
  static const lightShadow = Color(0x16000000);
  static const darkShadow = Color(0x66000000);
}

abstract final class NovaTypography {
  static const family = 'Roboto';
  static const display = TextStyle(fontSize: 32, height: 1.08, fontWeight: FontWeight.w800, letterSpacing: -0.8);
  static const heading = TextStyle(fontSize: 19, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.25);
  static const body = TextStyle(fontSize: 14, height: 1.45, fontWeight: FontWeight.w400);
  static const label = TextStyle(fontSize: 12, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: .15);
  static const data = TextStyle(fontSize: 26, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -.5, fontFeatures: [FontFeature.tabularFigures()]);
}

ThemeData buildAdminTheme({
  Brightness brightness = Brightness.light,
  Color primaryColor = NovaColors.fallbackPrimary,
  Color? secondaryColor,
}) {
  final dark = brightness == Brightness.dark;
  final canvas = dark ? NovaColors.darkCanvas : NovaColors.lightCanvas;
  final surface = dark ? NovaColors.darkSurface : NovaColors.lightSurface;
  final subtle = dark ? NovaColors.darkSurfaceSubtle : NovaColors.lightSurfaceSubtle;
  final text = dark ? NovaColors.darkText : NovaColors.lightText;
  final muted = dark ? NovaColors.darkMuted : NovaColors.lightMuted;
  final border = dark ? NovaColors.darkBorder : NovaColors.lightBorder;
  final primary = _accessibleBrand(primaryColor, dark);
  final secondary = _accessibleBrand(secondaryColor ?? primaryColor, dark);

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
    primary: primary,
    secondary: secondary,
    surface: surface,
    error: NovaColors.critical,
  ).copyWith(
    onSurface: text,
    surfaceContainerLowest: canvas,
    surfaceContainerLow: subtle,
    outline: border,
    outlineVariant: border.withValues(alpha: .7),
  );

  final baseText = TextTheme(
    displayMedium: NovaTypography.display.copyWith(color: text),
    headlineSmall: NovaTypography.display.copyWith(fontSize: 26, color: text),
    titleLarge: NovaTypography.heading.copyWith(color: text),
    titleMedium: NovaTypography.heading.copyWith(fontSize: 16, color: text),
    bodyLarge: NovaTypography.body.copyWith(fontSize: 15, color: text),
    bodyMedium: NovaTypography.body.copyWith(color: text),
    bodySmall: NovaTypography.label.copyWith(color: muted),
    labelLarge: NovaTypography.label.copyWith(fontSize: 14, color: text),
    labelMedium: NovaTypography.label.copyWith(color: muted),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(NovaRadius.input),
    borderSide: BorderSide(color: border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    fontFamily: NovaTypography.family,
    textTheme: baseText,
    dividerColor: border,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas.withValues(alpha: .88),
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: NovaTypography.heading.copyWith(color: text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface.withValues(alpha: .97),
      indicatorColor: primary.withValues(alpha: .14),
      elevation: NovaElevation.overlay,
      shadowColor: dark ? NovaElevation.darkShadow : NovaElevation.lightShadow,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => NovaTypography.label.copyWith(
        color: states.contains(WidgetState.selected) ? primary : muted,
        fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
      )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? primary : muted,
        size: states.contains(WidgetState.selected) ? 25 : 23,
      )),
      height: 76,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: NovaElevation.raised,
      shadowColor: dark ? NovaElevation.darkShadow : NovaElevation.lightShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.card),
        side: BorderSide(color: border.withValues(alpha: .75)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: primary, width: 1.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: NovaSpacing.md, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: primary,
        foregroundColor: _onBrand(primary),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NovaRadius.input)),
        textStyle: NovaTypography.label.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 50),
        backgroundColor: primary,
        foregroundColor: _onBrand(primary),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NovaRadius.input)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: subtle,
      selectedColor: primary.withValues(alpha: .14),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NovaRadius.control)),
      labelStyle: NovaTypography.label.copyWith(color: text),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    dividerTheme: DividerThemeData(color: border.withValues(alpha: .8), thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(NovaRadius.sheet))),
    ),
  );
}

Color _accessibleBrand(Color color, bool dark) {
  final hsl = HSLColor.fromColor(color);
  if (dark && hsl.lightness < .58) return hsl.withLightness(.62).toColor();
  if (!dark && hsl.lightness > .58) return hsl.withLightness(.48).toColor();
  return color;
}

Color _onBrand(Color color) => ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : const Color(0xFF171214);

const kPrimary = NovaColors.fallbackPrimary;
const kBackground = NovaColors.lightCanvas;
const kSurface = NovaColors.lightSurface;
const kTextDark = NovaColors.lightText;
const kTextMuted = NovaColors.lightMuted;
const kBorder = NovaColors.lightBorder;
const kSuccess = NovaColors.success;
const kWarning = NovaColors.warning;
const kError = NovaColors.critical;

BoxDecoration cardDecoration({double radius = NovaRadius.card}) => BoxDecoration(
  color: kSurface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: kBorder.withValues(alpha: .8)),
  boxShadow: const [BoxShadow(color: NovaElevation.lightShadow, blurRadius: 18, offset: Offset(0, 8))],
);

BoxDecoration statCardDecoration(Color color) => BoxDecoration(
  gradient: LinearGradient(colors: [color.withValues(alpha: .16), color.withValues(alpha: .07)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  borderRadius: BorderRadius.circular(NovaRadius.card),
  border: Border.all(color: color.withValues(alpha: .24)),
);
