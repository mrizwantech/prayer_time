import 'package:flutter/material.dart';
import 'package:hijri_date/hijri_date.dart';

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
    backgroundGradient: [Color(0xFF0BA360), Color(0xFF3CBA92), Color(0xFF7EE8FA)], // dawn greens
    primaryColor: Color(0xFF2ECC71),
    secondaryColor: Color(0xFFA0F0C0),
    textColor: Colors.white,
    cardColor: Color(0xFF12784E),
    prayerName: 'Fajr',
  );

  static const dhuhrTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFFFACC15)], // mid-day green to sun
    primaryColor: Color(0xFF34D399),
    secondaryColor: Color(0xFFFDE68A),
    textColor: Color(0xFF0F172A),
    cardColor: Color(0xFFE2F6E9),
    prayerName: 'Dhuhr',
  );

  static const asrTheme = PrayerTheme(
    backgroundGradient: [Color(0xFFF59E0B), Color(0xFFF97316), Color(0xFFFFC078)], // warm afternoon
    primaryColor: Color(0xFFF59E0B),
    secondaryColor: Color(0xFFFFD8A8),
    textColor: Color(0xFF3F2D20),
    cardColor: Color(0xFFFFEDD5),
    prayerName: 'Asr',
  );

  static const maghribTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF0EA5E9), Color(0xFF2563EB), Color(0xFFFB7185)], // cool sky into coral
    primaryColor: Color(0xFFFB7185),
    secondaryColor: Color(0xFF7DD3FC),
    textColor: Colors.white,
    cardColor: Color(0xFF1E3A8A),
    prayerName: 'Maghrib',
  );

  static const ishaTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF0F172A), Color(0xFF111827), Color(0xFF1E293B)], // deep navy
    primaryColor: Color(0xFF38BDF8),
    secondaryColor: Color(0xFFA5F3FC),
    textColor: Color(0xFFE2E8F0),
    cardColor: Color(0xFF1E293B),
    prayerName: 'Isha',
  );

  static const tahajjudTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF0B1224), Color(0xFF111827), Color(0xFF1F2937)], // midnight blue
    primaryColor: Color(0xFF8B5CF6),
    secondaryColor: Color(0xFFC4B5FD),
    textColor: Color(0xFFEDE9FE),
    cardColor: Color(0xFF312E81),
    prayerName: 'Tahajjud',
  );

  bool get isRamadan {
    final now = HijriDate.now();
    return now.hMonth == 9;
  }

  PrayerTheme getCurrentTheme(String currentPrayer) {
    if (isRamadan) {
      return const PrayerTheme(
        backgroundGradient: [Color(0xFF0B3B2E), Color(0xFF0E4B3A), Color(0xFF0F5132)],
        primaryColor: Color(0xFF34D399),
        secondaryColor: Color(0xFFF5D047),
        textColor: Color(0xFFE7F8F1),
        cardColor: Color(0xFF0C3B2F),
        prayerName: 'Ramadan',
      );
    }
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
