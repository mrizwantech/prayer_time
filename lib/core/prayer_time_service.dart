import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'calculation_method_settings.dart';
import 'adhan_notification_service.dart';

/// Single source of truth for prayer times, location, and scheduling
/// All screens should consume from this service
class PrayerTimeService extends ChangeNotifier {
  // Location data
  String? _city;
  String? _state;
  double? _latitude;
  double? _longitude;
  
  // Prayer times data
  PrayerTimes? _prayerTimes;
  DateTime? _sunrise;
  DateTime? _sunset;
  
  // State
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchDate;
  DateTime? _lastScheduledDate;
  
  // Dependencies
  CalculationMethodSettings? _calculationMethodSettings;
  String? _currentCalculationMethod;
  
  // Getters
  String? get city => _city;
  String? get state => _state;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _latitude != null && _longitude != null;
  bool get hasPrayerTimes => _prayerTimes != null;
  
  // Prayer time getters
  DateTime? get fajr => _prayerTimes?.fajr;
  DateTime? get sunrise => _sunrise;
  DateTime? get dhuhr => _prayerTimes?.dhuhr;
  DateTime? get asr => _prayerTimes?.asr;
  DateTime? get maghrib => _prayerTimes?.maghrib;
  DateTime? get isha => _prayerTimes?.isha;
  DateTime? get sunset => _sunset;
  PrayerTimes? get prayerTimes => _prayerTimes;
  
  /// Get formatted prayer times list for UI consumption
  List<Map<String, dynamic>> get prayersList {
    if (_prayerTimes == null) return [];
    
    String formatTime(DateTime dt) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    
    return [
      {'name': 'Fajr', 'time': formatTime(_prayerTimes!.fajr), 'dateTime': _prayerTimes!.fajr},
      {'name': 'Dhuhr', 'time': formatTime(_prayerTimes!.dhuhr), 'dateTime': _prayerTimes!.dhuhr},
      {'name': 'Asr', 'time': formatTime(_prayerTimes!.asr), 'dateTime': _prayerTimes!.asr},
      {'name': 'Maghrib', 'time': formatTime(_prayerTimes!.maghrib), 'dateTime': _prayerTimes!.maghrib},
      {'name': 'Isha', 'time': formatTime(_prayerTimes!.isha), 'dateTime': _prayerTimes!.isha},
    ];
  }
  
  /// Initialize the service with calculation method settings
  void setCalculationMethodSettings(CalculationMethodSettings settings) {
    // Remove old listener if exists
    _calculationMethodSettings?.removeListener(_onCalculationMethodChanged);
    
    _calculationMethodSettings = settings;
    _currentCalculationMethod = settings.selectedMethod?.name;
    
    // Listen for changes
    _calculationMethodSettings?.addListener(_onCalculationMethodChanged);
  }
  
  void _onCalculationMethodChanged() {
    final newMethod = _calculationMethodSettings?.selectedMethod?.name;
    if (newMethod != null && newMethod != _currentCalculationMethod) {
      debugPrint('🔄 PrayerTimeService: Calculation method changed to: $newMethod');
      _currentCalculationMethod = newMethod;
      // Method changed - this will trigger a full reload via the app
    }
  }
  
  /// Check if calculation method has changed since last load
  bool hasCalculationMethodChanged() {
    final currentMethod = _calculationMethodSettings?.selectedMethod?.name;
    return currentMethod != null && currentMethod != _currentCalculationMethod;
  }
  
  /// Full initialization - get location, prayer times, and schedule notifications
  Future<void> initialize() async {
    debugPrint('🕌 PrayerTimeService: Initializing...');
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Step 1: Get location
      await _fetchLocation();
      
      if (_latitude == null || _longitude == null) {
        throw Exception('Could not get location');
      }
      
      // Step 2: Calculate prayer times
      await _calculatePrayerTimes();
      
      // Step 3: Schedule notifications
      await _scheduleNotifications();
      
      _lastFetchDate = DateTime.now();
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ PrayerTimeService: Initialization complete');
    } catch (e) {
      debugPrint('❌ PrayerTimeService: Error during initialization: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Refresh everything - clear cache and reload
  Future<void> refresh() async {
    debugPrint('🔄 PrayerTimeService: Refreshing...');
    _lastFetchDate = null;
    _lastScheduledDate = null;
    await initialize();
  }
  
  /// Clear all cached data (call before full reload)
  void clearCache() {
    debugPrint('🗑️ PrayerTimeService: Clearing cache');
    _prayerTimes = null;
    _sunrise = null;
    _sunset = null;
    _lastFetchDate = null;
    _lastScheduledDate = null;
    _currentCalculationMethod = _calculationMethodSettings?.selectedMethod?.name;
  }
  
  Future<void> _fetchLocation() async {
    debugPrint('📍 PrayerTimeService: Fetching location...');
    
    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }
    
    // Try last known position first for instant load
    Position? position = await Geolocator.getLastKnownPosition();
    debugPrint('📍 Last known: ${position?.latitude}, ${position?.longitude}');
    
    if (position == null) {
      debugPrint('📍 Getting current position...');
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.lowest,
          timeLimit: Duration(seconds: 5),
        ),
      );
    }
    
    _latitude = position.latitude;
    _longitude = position.longitude;
    debugPrint('📍 Got location: $_latitude, $_longitude');
    
    // Save location to SharedPreferences for native rescheduling
    await _saveLocationToPrefs();
    
    // Fetch city/state in background (don't block)
    _fetchCityState();
  }
  
  /// Save location to SharedPreferences for native Android rescheduling service
  Future<void> _saveLocationToPrefs() async {
    if (_latitude == null || _longitude == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latitude', _latitude!);
      await prefs.setDouble('longitude', _longitude!);
      debugPrint('💾 Location saved to SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error saving location to prefs: $e');
    }
  }
  
  Future<void> _fetchCityState() async {
    if (_latitude == null || _longitude == null) return;
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(_latitude!, _longitude!);
      if (placemarks.isNotEmpty) {
        final mark = placemarks.first;
        _city = mark.locality ?? mark.subAdministrativeArea;
        _state = mark.administrativeArea;
        debugPrint('📍 Location: $_city, $_state');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
    }
  }
  
  Future<void> _calculatePrayerTimes() async {
    if (_latitude == null || _longitude == null) {
      throw Exception('Location not available');
    }
    
    debugPrint('🕌 PrayerTimeService: Calculating prayer times...');
    
    // Get calculation parameters
    final params = _calculationMethodSettings?.getParameters() 
        ?? CalculationMethod.north_america.getParameters();
    
    // Calculate prayer times
    final coordinates = Coordinates(_latitude!, _longitude!);
    final dateComponents = DateComponents.from(DateTime.now());
    _prayerTimes = PrayerTimes(coordinates, dateComponents, params);
    
    // Get sunrise/sunset
    final sunnahTimes = SunnahTimes(_prayerTimes!);
    _sunrise = _prayerTimes!.sunrise;
    _sunset = _prayerTimes!.maghrib;
    
    debugPrint('🕌 Fajr: ${_prayerTimes!.fajr}');
    debugPrint('🕌 Dhuhr: ${_prayerTimes!.dhuhr}');
    debugPrint('🕌 Asr: ${_prayerTimes!.asr}');
    debugPrint('🕌 Maghrib: ${_prayerTimes!.maghrib}');
    debugPrint('🕌 Isha: ${_prayerTimes!.isha}');
  }
  
  Future<void> _scheduleNotifications() async {
    if (_latitude == null || _longitude == null) return;
    
    final now = DateTime.now();
    // Check if already scheduled today
    if (_lastScheduledDate != null &&
        _lastScheduledDate!.year == now.year &&
        _lastScheduledDate!.month == now.month &&
        _lastScheduledDate!.day == now.day) {
      debugPrint('📅 Notifications already scheduled today');
      return;
    }
    
    debugPrint('📅 PrayerTimeService: Scheduling notifications...');
    final notificationService = AdhanNotificationService();
    
    // Cancel old and schedule fresh
    await notificationService.cancelAllNotifications();
    await notificationService.scheduleAllPrayersForToday(
      latitude: _latitude,
      longitude: _longitude,
    );
    
    _lastScheduledDate = now;
    debugPrint('✅ Notifications scheduled');
  }
  
  /// Check if we need to reschedule notifications (new day detected)
  bool needsReschedule() {
    if (_lastScheduledDate == null) return false;
    
    final now = DateTime.now();
    // Check if it's a new day since last scheduled
    final isNewDay = _lastScheduledDate!.year != now.year ||
        _lastScheduledDate!.month != now.month ||
        _lastScheduledDate!.day != now.day;
    
    if (isNewDay) {
      debugPrint('📅 New day detected - last scheduled: ${_lastScheduledDate!.toIso8601String()}, now: ${now.toIso8601String()}');
    }
    
    return isNewDay;
  }
  
  /// Reschedule notifications for new day if needed
  Future<void> rescheduleIfNeeded() async {
    if (!needsReschedule()) return;
    
    debugPrint('🔄 PrayerTimeService: Rescheduling for new day...');
    
    // Recalculate prayer times for today
    await _calculatePrayerTimes();
    notifyListeners();
    
    // Force reschedule by clearing last scheduled date
    _lastScheduledDate = null;
    await _scheduleNotifications();
    
    debugPrint('✅ Rescheduled for new day');
  }
  
  /// Get current prayer name based on time
  String getCurrentPrayerName() {
    if (_prayerTimes == null) return 'Fajr';
    
    final now = DateTime.now();
    if (now.isBefore(_prayerTimes!.fajr)) return 'Isha'; // Before Fajr = still Isha time
    if (now.isBefore(_prayerTimes!.dhuhr)) return 'Fajr';
    if (now.isBefore(_prayerTimes!.asr)) return 'Dhuhr';
    if (now.isBefore(_prayerTimes!.maghrib)) return 'Asr';
    if (now.isBefore(_prayerTimes!.isha)) return 'Maghrib';
    return 'Isha';
  }
  
  /// Get next prayer name and time
  Map<String, dynamic>? getNextPrayer() {
    if (_prayerTimes == null) return null;
    
    final now = DateTime.now();
    final prayers = [
      {'name': 'Fajr', 'time': _prayerTimes!.fajr},
      {'name': 'Dhuhr', 'time': _prayerTimes!.dhuhr},
      {'name': 'Asr', 'time': _prayerTimes!.asr},
      {'name': 'Maghrib', 'time': _prayerTimes!.maghrib},
      {'name': 'Isha', 'time': _prayerTimes!.isha},
    ];
    
    for (final prayer in prayers) {
      if (now.isBefore(prayer['time'] as DateTime)) {
        return prayer;
      }
    }
    
    // All prayers passed, next is tomorrow's Fajr
    return {
      'name': 'Fajr',
      'time': _prayerTimes!.fajr.add(const Duration(days: 1)),
    };
  }
  
  @override
  void dispose() {
    _calculationMethodSettings?.removeListener(_onCalculationMethodChanged);
    super.dispose();
  }
}
