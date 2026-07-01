import 'package:flutter/material.dart';

// Nova Venues brand colors
const kPrimary    = Color(0xFF9B1B2B); // wine red
const kBackground = Color(0xFFF5F3F0); // cream
const kSurface    = Color(0xFFFFFFFF);
const kTextDark   = Color(0xFF1A1714);
const kTextMuted  = Color(0xFF8A8078);
const kBorder     = Color(0xFFE8E4E0);
const kSuccess    = Color(0xFF2D6A4F);
const kWarning    = Color(0xFFB45309);
const kError      = Color(0xFF9B1B2B);

ThemeData buildAdminTheme() {
  return ThemeData(
    useMaterial3: false,
    colorScheme: const ColorScheme.light(
      primary:    kPrimary,
      secondary:  kPrimary,
      surface:    kSurface,
      background: kBackground,
      onPrimary:  Colors.white,
      onSurface:  kTextDark,
    ),
    scaffoldBackgroundColor: kBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kTextDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kTextDark,
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
      iconTheme: IconThemeData(color: kTextDark),
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: kSurface,
      selectedItemColor: kPrimary,
      unselectedItemColor: kTextMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 12,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 11),
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    dividerTheme: const DividerThemeData(color: kBorder, thickness: 1),
    textTheme: const TextTheme(
      displayMedium: TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 26),
      titleLarge:   TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium:  TextStyle(color: kTextDark, fontWeight: FontWeight.w600, fontSize: 16),
      bodyLarge:    TextStyle(color: kTextDark, fontSize: 15),
      bodyMedium:   TextStyle(color: kTextMuted, fontSize: 13),
      labelSmall:   TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

// Shared decorations
BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
  color: kSurface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: kBorder),
  boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
);

BoxDecoration statCardDecoration(Color color) => BoxDecoration(
  color: color.withOpacity(0.08),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: color.withOpacity(0.2)),
);
