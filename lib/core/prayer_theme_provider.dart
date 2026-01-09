import 'package:flutter/material.dart';
import 'package:hijri_date/hijri_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _ramadanPreviewKey = 'ramadanPreviewEnabled';
  bool _ramadanPreviewEnabled = false;

  static const PrayerTheme _defaultTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF123D3A), Color(0xFF0E4B3A), Color(0xFF0F5132)],
    primaryColor: Color(0xFF34D399),
    secondaryColor: Color(0xFFF5D047),
    textColor: Color(0xFFE7F8F1),
    cardColor: Color(0xFF0C3B2F),
    prayerName: 'Default',
  );

  static const PrayerTheme _ramadanTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF0B3B2E), Color(0xFF0E4B3A), Color(0xFF0F5132)],
    primaryColor: Color(0xFF34D399),
    secondaryColor: Color(0xFFF5D047),
    textColor: Color(0xFFE7F8F1),
    cardColor: Color(0xFF0C3B2F),
    prayerName: 'Ramadan',
  );

  bool get ramadanPreviewEnabled => _ramadanPreviewEnabled;

  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _ramadanPreviewEnabled = prefs.getBool(_ramadanPreviewKey) ?? false;
    notifyListeners();
  }

  Future<void> setRamadanPreview(bool enabled) async {
    _ramadanPreviewEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ramadanPreviewKey, enabled);
    notifyListeners();
  }

  static const fajrTheme = PrayerTheme(
    backgroundGradient: [Color(0xFF0A5B4A), Color(0xFF0E7A66), Color(0xFF1FA37D)], // deeper greens for contrast
    primaryColor: Color(0xFF0F8A68),
    secondaryColor: Color(0xFFF4E04D),
    textColor: Colors.white,
    cardColor: Color(0xFF0A4738),
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
    if (_ramadanPreviewEnabled) return true;
    final todayHijri = HijriDate.fromDate(DateTime.now());
    return todayHijri.hMonth == 9;
  }

  PrayerTheme getCurrentTheme(String currentPrayer) {
    if (isRamadan) return _ramadanTheme;
    return _defaultTheme;
  }
}
