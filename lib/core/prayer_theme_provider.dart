import 'package:flutter/material.dart';

class PrayerTheme {
  final List<Color> backgroundGradient;
  final Color primaryColor;
  final Color secondaryColor;
  final Color textColor;
  final Color cardColor;
  final String prayerName;

  const PrayerTheme({
    required this.backgroundGradient,
    required this.primaryColor,
    required this.secondaryColor,
    required this.textColor,
    required this.cardColor,
    required this.prayerName,
  });
}

class PrayerThemeProvider extends ChangeNotifier {
  static const fajrTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF4A148C), Color(0xFF7E57C2), Color(0xFFFF6F00)],
    primaryColor: Color(0xFFCE93D8),
    secondaryColor: Color(0xFFFFB74D),
    textColor: Colors.white,
    cardColor: Color(0xFF6A1B9A),
    prayerName: 'Fajr',
  );

  static const dhuhrTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF0288D1), Color(0xFF29B6F6), Color(0xFFFFEB3B)],
    primaryColor: Color(0xFFFFC107),
    secondaryColor: Color(0xFF03A9F4),
    textColor: Color(0xFF01579B),
    cardColor: Color(0xFF4FC3F7),
    prayerName: 'Dhuhr',
  );

  static const asrTheme = PrayerTheme(
    backgroundGradient: [Color(0xFFFF6F00), Color(0xFFFFB74D), Color(0xFFFFE0B2)],
    primaryColor: Color(0xFFFF9800),
    secondaryColor: Color(0xFFFFD54F),
    textColor: Color(0xFF4E342E),
    cardColor: Color(0xFFFFB74D),
    prayerName: 'Asr',
  );

  static const maghribTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF880E4F), Color(0xFFD81B60), Color(0xFFFF6F00), Color(0xFFFFB74D)],
    primaryColor: Color(0xFFEC407A),
    secondaryColor: Color(0xFFFF9800),
    textColor: Colors.white,
    cardColor: Color(0xFFC2185B),
    prayerName: 'Maghrib',
  );

  static const ishaTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF0a0e27), Color(0xFF1a1d3a), Color(0xFF2d3561)],
    primaryColor: Color(0xFFB0BEC5),
    secondaryColor: Color(0xFF7986CB),
    textColor: Color(0xFFE3F2FD),
    cardColor: Color(0xFF1a237e),
    prayerName: 'Isha',
  );

  static const tahajjudTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF000000), Color(0xFF0a0e27), Color(0xFF1a1a2e)],
    primaryColor: Color(0xFF7E57C2),
    secondaryColor: Color(0xFF9575CD),
    textColor: Color(0xFFE1BEE7),
    cardColor: Color(0xFF311B92),
    prayerName: 'Tahajjud',
  );

  PrayerTheme getCurrentTheme(String currentPrayer) {
    switch (currentPrayer.toLowerCase()) {
      case 'fajr':
        return fajrTheme;
      case 'dhuhr':
        return dhuhrTheme;
      case 'asr':
        return asrTheme;
      case 'maghrib':
        return maghribTheme;
      case 'isha':
        return ishaTheme;
      case 'tahajjud (qiyam-u-lail)':
      case 'tahajjud':
        return tahajjudTheme;
      default:
        return ishaTheme;
    }
  }
}
