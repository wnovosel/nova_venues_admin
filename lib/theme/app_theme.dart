import 'package:flutter/material.dart';

abstract final class NovaColors {
  static const burgundy = Color(0xFF8E2434);
  static const burgundyDark = Color(0xFFB94A5B);
  static const lightCanvas = Color(0xFFF7F5F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF0EDE9);
  static const lightText = Color(0xFF201D1D);
  static const lightMuted = Color(0xFF716B68);
  static const lightBorder = Color(0xFFE2DEDA);
  static const darkCanvas = Color(0xFF171717);
  static const darkSurface = Color(0xFF202020);
  static const darkSurfaceSubtle = Color(0xFF292929);
  static const darkText = Color(0xFFF2F0EE);
  static const darkMuted = Color(0xFFAAA5A2);
  static const darkBorder = Color(0xFF383838);
  static const success = Color(0xFF2F7D5B);
  static const warning = Color(0xFFB66A16);
  static const critical = Color(0xFFB83A3A);
  static const information = Color(0xFF3977A8);
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
  static const control = 8.0;
  static const input = 12.0;
  static const card = 16.0;
  static const panel = 20.0;
  static const sheet = 24.0;
}

abstract final class NovaIconSize {
  static const sm = 16.0;
  static const md = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class NovaMotion {
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 200);
  static const emphasized = Duration(milliseconds: 240);
}

abstract final class NovaElevation {
  static const none = 0.0;
  static const raised = 2.0;
  static const overlay = 8.0;
  static const lightShadow = Color(0x12000000);
  static const darkShadow = Color(0x52000000);
}

abstract final class NovaTypography {
  static const family = 'Roboto';
  static const display = TextStyle(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );
  static const heading = TextStyle(
    fontSize: 18,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );
  static const label = TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
  static const data = TextStyle(
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildAdminTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final canvas = dark ? NovaColors.darkCanvas : NovaColors.lightCanvas;
  final surface = dark ? NovaColors.darkSurface : NovaColors.lightSurface;
  final subtle = dark
      ? NovaColors.darkSurfaceSubtle
      : NovaColors.lightSurfaceSubtle;
  final text = dark ? NovaColors.darkText : NovaColors.lightText;
  final muted = dark ? NovaColors.darkMuted : NovaColors.lightMuted;
  final border = dark ? NovaColors.darkBorder : NovaColors.lightBorder;
  final primary = dark ? NovaColors.burgundyDark : NovaColors.burgundy;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: Colors.white,
    secondary: primary,
    onSecondary: Colors.white,
    error: NovaColors.critical,
    onError: Colors.white,
    surface: surface,
    onSurface: text,
  );
  final baseText = TextTheme(
    displayMedium: NovaTypography.display.copyWith(color: text),
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
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: NovaElevation.none,
      titleTextStyle: NovaTypography.heading.copyWith(color: text),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: primary.withValues(alpha: .12),
      elevation: NovaElevation.overlay,
      labelTextStyle: WidgetStatePropertyAll(
        NovaTypography.label.copyWith(color: text),
      ),
      height: 72,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: NovaElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.card),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.md,
        vertical: NovaSpacing.sm,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.input),
        ),
        textStyle: NovaTypography.label.copyWith(fontSize: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: NovaElevation.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.input),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: subtle,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.control),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.sheet),
        ),
      ),
    ),
  );
}

// Compatibility aliases retained while feature screens migrate in later tasks.
const kPrimary = NovaColors.burgundy;
const kBackground = NovaColors.lightCanvas;
const kSurface = NovaColors.lightSurface;
const kTextDark = NovaColors.lightText;
const kTextMuted = NovaColors.lightMuted;
const kBorder = NovaColors.lightBorder;
const kSuccess = NovaColors.success;
const kWarning = NovaColors.warning;
const kError = NovaColors.critical;

BoxDecoration cardDecoration({double radius = NovaRadius.card}) =>
    BoxDecoration(
      color: kSurface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kBorder),
      boxShadow: const [
        BoxShadow(
          color: NovaElevation.lightShadow,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    );

BoxDecoration statCardDecoration(Color color) => BoxDecoration(
  color: color.withValues(alpha: .08),
  borderRadius: BorderRadius.circular(NovaRadius.card),
  border: Border.all(color: color.withValues(alpha: .2)),
);
