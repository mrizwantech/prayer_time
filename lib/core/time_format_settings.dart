import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimeFormatSettings extends ChangeNotifier {
  static const String _key = 'is24HourFormat';
  bool _is24Hour = false; // Default to 12-hour format
  bool _isLoaded = false;
  
  bool get is24Hour => _is24Hour;
  bool get isLoaded => _isLoaded;

  TimeFormatSettings() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _is24Hour = prefs.getBool(_key) ?? false; // Default to 12-hour (false)
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> toggleFormat() async {
    _is24Hour = !_is24Hour;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> setFormat(bool is24) async {
    _is24Hour = is24;
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _is24Hour);
  }
}
