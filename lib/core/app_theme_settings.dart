import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  light,
  dark,
  system,
}

class AppThemeSettings extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  
  AppThemeMode _themeMode = AppThemeMode.dark; // Default to dark
  
  AppThemeMode get themeMode => _themeMode;
  
  // Get Flutter's ThemeMode from our AppThemeMode
  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
  
  // Theme colors
  static const Color accentColor = Color(0xFF00D9A5);
  
  // Dark theme colors
  static const Color darkBackground = Color(0xFF1a1d2e);
  static const Color darkSurface = Color(0xFF252836);
  static const Color darkCard = Color(0xFF252836);
  static const Color darkText = Colors.white;
  static const Color darkSubtitle = Color(0xFF8F92A1);
  
  // Light theme colors
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightText = Color(0xFF1a1d2e);
  static const Color lightSubtitle = Color(0xFF6B7280);
  
  // Get dark theme
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.dark(
      primary: accentColor,
      secondary: accentColor,
      surface: darkSurface,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardColor: darkCard,
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogBackgroundColor: darkSurface,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkSurface,
    ),
    dividerColor: Colors.white12,
    listTileTheme: ListTileThemeData(
      textColor: darkText,
      iconColor: accentColor,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accentColor;
        }
        return Colors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accentColor.withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accentColor,
      inactiveTrackColor: accentColor.withOpacity(0.2),
      thumbColor: accentColor,
      overlayColor: accentColor.withOpacity(0.2),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkText),
      bodyMedium: TextStyle(color: darkText),
      bodySmall: TextStyle(color: darkSubtitle),
      titleLarge: TextStyle(color: darkText),
      titleMedium: TextStyle(color: darkText),
      titleSmall: TextStyle(color: darkSubtitle),
    ),
    iconTheme: const IconThemeData(color: accentColor),
    useMaterial3: true,
  );
  
  // Get light theme
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.light(
      primary: accentColor,
      secondary: accentColor,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: lightText,
      elevation: 0,
    ),
    cardColor: lightCard,
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogBackgroundColor: lightSurface,
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightSurface,
    ),
    dividerColor: Colors.black12,
    listTileTheme: ListTileThemeData(
      textColor: lightText,
      iconColor: accentColor,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accentColor;
        }
        return Colors.grey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accentColor.withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.3);
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accentColor,
      inactiveTrackColor: accentColor.withOpacity(0.2),
      thumbColor: accentColor,
      overlayColor: accentColor.withOpacity(0.2),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightText),
      bodyMedium: TextStyle(color: lightText),
      bodySmall: TextStyle(color: lightSubtitle),
      titleLarge: TextStyle(color: lightText),
      titleMedium: TextStyle(color: lightText),
      titleSmall: TextStyle(color: lightSubtitle),
    ),
    iconTheme: const IconThemeData(color: accentColor),
    useMaterial3: true,
  );
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeKey);
    
    if (savedMode != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => AppThemeMode.dark,
      );
    }
    notifyListeners();
  }
  
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }
  
  String get themeModeDisplayName {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }
  
  IconData get themeModeIcon {
    switch (_themeMode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}
