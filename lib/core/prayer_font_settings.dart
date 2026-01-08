import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerFontSettings extends ChangeNotifier {
  static const String _key = 'prayerFontScale';
  static const double _defaultScale = 1.0;
  static const double minScale = 0.9;
  static const double maxScale = 1.6;

  double _scale = _defaultScale;
  bool _loaded = false;

  double get scale => _scale;
  bool get isLoaded => _loaded;

  PrayerFontSettings() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _scale = prefs.getDouble(_key) ?? _defaultScale;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setScale(double value) async {
    _scale = value.clamp(minScale, maxScale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, _scale);
    notifyListeners();
  }
}
