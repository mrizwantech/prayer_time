import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Shared location state provider for the entire app
class LocationProvider extends ChangeNotifier {
  String? _city;
  String? _state;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchDate;

  // Getters
  String? get city => _city;
  String? get state => _state;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _city != null || _state != null;

  /// Initialize location on app start
  Future<void> initializeLocation() async {
    // Check if we already have data from today
    final now = DateTime.now();
    if (_lastFetchDate != null &&
        _lastFetchDate!.year == now.year &&
        _lastFetchDate!.month == now.month &&
        _lastFetchDate!.day == now.day &&
        _latitude != null) {
      // Already have today's location, no need to refetch
      return;
    }

    await fetchLocation();
  }

  /// Fetch current location
  Future<void> fetchLocation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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

      // Try last known position first for faster load
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);

      _latitude = position.latitude;
      _longitude = position.longitude;
      _lastFetchDate = DateTime.now();

      // Fetch city/state in parallel
      await _fetchCityState(position.latitude, position.longitude);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh location (clear cache and fetch fresh)
  Future<void> refreshLocation() async {
    _lastFetchDate = null;
    await fetchLocation();
  }

  Future<void> _fetchCityState(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      debugPrint('🌍 Geocoding results: ${placemarks.length} placemarks found');
      if (placemarks.isNotEmpty) {
        final mark = placemarks.first;
        debugPrint('📍 City: ${mark.locality}, State: ${mark.administrativeArea}');
        _city = mark.locality ?? mark.subAdministrativeArea;
        _state = mark.administrativeArea;
      }
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
    }
  }
}
