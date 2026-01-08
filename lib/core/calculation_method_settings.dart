import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';

/// Available calculation methods with display names and descriptions
enum CalculationMethodOption {
  muslimWorldLeague('Muslim World League', 'Fajr: 18°, Isha: 17°', CalculationMethod.muslim_world_league),
  isna('ISNA (North America)', 'Fajr: 15°, Isha: 15°', CalculationMethod.north_america),
  egyptian('Egyptian General Authority', 'Fajr: 19.5°, Isha: 17.5°', CalculationMethod.egyptian),
  ummAlQura('Umm Al-Qura (Makkah)', 'Fajr: 18.5°, Isha: 90min after Maghrib', CalculationMethod.umm_al_qura),
  dubai('Dubai', 'Fajr: 18.2°, Isha: 18.2°', CalculationMethod.dubai),
  qatar('Qatar', 'Fajr: 18°, Isha: 90min after Maghrib', CalculationMethod.qatar),
  kuwait('Kuwait', 'Fajr: 18°, Isha: 17.5°', CalculationMethod.kuwait),
  singapore('Singapore', 'Fajr: 20°, Isha: 18°', CalculationMethod.singapore),
  karachi('Karachi', 'Fajr: 18°, Isha: 18°', CalculationMethod.karachi),
  tehran('Tehran', 'Fajr: 17.7°, Isha: 14°', CalculationMethod.tehran),
  turkey('Turkey (Diyanet)', 'Fajr: 18°, Isha: 17°', CalculationMethod.turkey);

  final String displayName;
  final String description;
  final CalculationMethod method;

  const CalculationMethodOption(this.displayName, this.description, this.method);
}

class CalculationMethodSettings extends ChangeNotifier {
  static const String _prefsKey = 'calculation_method';
  CalculationMethodOption? _selectedMethod;
  bool _isInitialized = false;

  CalculationMethodOption? get selectedMethod => _selectedMethod;
  bool get isInitialized => _isInitialized;
  bool get hasSelectedMethod => _selectedMethod != null;

  /// Get calculation parameters for the selected method
  CalculationParameters getParameters() {
    if (_selectedMethod == null) {
      // Default to ISNA if no method selected (shouldn't happen after initialization)
      return CalculationMethod.north_america.getParameters();
    }
    return _selectedMethod!.method.getParameters();
  }

  /// Initialize and load saved preference
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final savedMethod = prefs.getString(_prefsKey);
    
    if (savedMethod != null) {
      try {
        _selectedMethod = CalculationMethodOption.values.firstWhere(
          (m) => m.name == savedMethod,
        );
      } catch (e) {
        // If saved value is invalid, keep it null to force selection
        _selectedMethod = null;
      }
    }
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Set the calculation method and save to SharedPreferences
  Future<void> setMethod(CalculationMethodOption method) async {
    _selectedMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, method.name);
    notifyListeners();
  }

  /// Check if this is the first time (no method selected yet)
  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return !prefs.containsKey(_prefsKey);
  }
}
