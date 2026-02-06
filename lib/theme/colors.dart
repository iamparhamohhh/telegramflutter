import 'package:flutter/material.dart';

// ─── Color Constants (kept for backward compat) ─────────────────────────
const Color primary = Color(0xFF0088CC);
const Color bgColor = Color(0xFF010101);
const Color white = Color(0xFFFFFFFF);
const Color black = Color(0xFF000000);
const Color textfieldColor = Color(0xFF1c1d1f);
const Color greyColor = Color(0xFF161616);
const Color chatBoxOther = Color(0xFF3d3d3f);
const Color chatBoxMe = Color(0xFF066162);

// ─── App Theme Manager ──────────────────────────────────────────────────
class AppTheme extends ChangeNotifier {
  static final AppTheme _instance = AppTheme._internal();
  factory AppTheme() => _instance;
  AppTheme._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // ── Dark Theme ──
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF37AEE2),
      secondary: Color(0xFF0088CC),
      surface: Color(0xFF161616),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF010101),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF161616),
      foregroundColor: Colors.white,
      elevation: 0.5,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF161616),
      selectedItemColor: Color(0xFF0088CC),
      unselectedItemColor: Colors.white54,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF161616),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF161616),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(color: Colors.white10, thickness: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1c1d1f),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF37AEE2),
      foregroundColor: Colors.white,
    ),
  );

  // ── Light Theme ──
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0088CC),
      secondary: Color(0xFF37AEE2),
      surface: Colors.white,
      onSurface: Color(0xFF1A1A1A),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F0F0),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF517DA2),
      foregroundColor: Colors.white,
      elevation: 0.5,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF0088CC),
      unselectedItemColor: Colors.grey,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1A1A),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(color: Colors.black12, thickness: 0.5),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFE8E8E8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF0088CC),
      foregroundColor: Colors.white,
    ),
  );
}

// ── Theme-aware color helpers for existing pages ──
extension ThemeColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? bgColor : const Color(0xFFF0F0F0);
  Color get surface => isDark ? greyColor : Colors.white;
  Color get onSurface => isDark ? white : const Color(0xFF1A1A1A);
  Color get onSurfaceSecondary => isDark ? Colors.white60 : Colors.black54;
  Color get accent => const Color(0xFF37AEE2);
  Color get fieldColor => isDark ? textfieldColor : const Color(0xFFE8E8E8);
  Color get bubbleMe =>
      isDark ? const Color(0xFF2B5278) : const Color(0xFFEEFFDE);
  Color get bubbleOther => isDark ? greyColor : Colors.white;
  Color get bubbleTextMe => isDark ? white : const Color(0xFF1A1A1A);
  Color get bubbleTextOther => isDark ? white : const Color(0xFF1A1A1A);
  Color get appBarBg => isDark ? greyColor : const Color(0xFF517DA2);
  Color get appBarText => Colors.white;
  Color get dividerLine => isDark ? Colors.white10 : Colors.black12;
  Color get unreadBadge => const Color(0xFF37AEE2);
}
