import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'adhan_notification_service.dart';

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  /// Request all app permissions at once on first launch
  /// Returns true if all required permissions are granted
  Future<bool> requestAllPermissions() async {
    debugPrint('=== Requesting All Permissions ===');
    
    bool allGranted = true;

    // 1. Request Location Permission
    debugPrint('Requesting location permission...');
    final locationGranted = await _requestLocationPermission();
    debugPrint('Location permission: ${locationGranted ? "GRANTED" : "DENIED"}');
    allGranted = allGranted && locationGranted;

    // 2. Request Notification Permissions
    debugPrint('Requesting notification permissions...');
    final notificationGranted = await _requestNotificationPermissions();
    debugPrint('Notification permission: ${notificationGranted ? "GRANTED" : "DENIED"}');
    allGranted = allGranted && notificationGranted;

    debugPrint('=== All Permissions ${allGranted ? "GRANTED" : "INCOMPLETE"} ===');
    return allGranted;
  }

  Future<bool> _requestLocationPermission() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        return false;
      }

      // Permission granted (either while in use or always)
      return true;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  Future<bool> _requestNotificationPermissions() async {
    try {
      final notificationService = AdhanNotificationService();
      return await notificationService.requestPermissions();
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      return false;
    }
  }

  /// Check if notification permissions are granted
  Future<bool> hasNotificationPermissions() async {
    // This would need to check the actual permission status
    // For now, we'll assume if we requested it once, it's set
    return true;
  }
}
