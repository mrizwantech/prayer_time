import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AdhanSoundService {
  static final AdhanSoundService _instance = AdhanSoundService._internal();
  factory AdhanSoundService() => _instance;
  
  AdhanSoundService._internal() {
    // Listen for adhan player launch requests from native side
    platform.setMethodCallHandler(_handleNativeMethodCall);
    // On cold starts, pull any pending launch the native side buffered
    _checkForPendingAdhanLaunch();
  }

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _previewPlayer = AudioPlayer(); // Separate player for previews
  
  // Platform channel for native adhan service
  static const platform = MethodChannel('com.mrizwantech.azanify/adhan');
  
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'launchAdhanPlayer') {
      final prayerName = call.arguments['prayerName'] as String?;
      if (prayerName != null) {
        debugPrint('📱 Native requested adhan player launch for $prayerName');
        // Notify listeners or use a callback to launch the screen
        _launchAdhanPlayerCallback?.call(prayerName);
      }
    }
  }
  
  // Callback for launching adhan player screen
  Function(String)? _launchAdhanPlayerCallback;
  
  void setLaunchAdhanPlayerCallback(Function(String) callback) {
    _launchAdhanPlayerCallback = callback;
  }

  Future<void> _checkForPendingAdhanLaunch() async {
    try {
      final pending = await platform.invokeMethod<String>('consumePendingAdhanLaunch');
      if (pending != null && pending.isNotEmpty) {
        debugPrint('📲 Consumed pending adhan launch for $pending');
        _launchAdhanPlayerCallback?.call(pending);
      }
    } catch (e) {
      debugPrint('❌ Error checking pending adhan launch: $e');
    }
  }
  
  // Available audio files - users can add any MP3 file to assets/sounds/
  // The filename (without .mp3) will be the display name
  static const List<String> adhanOptions = [
    'Silent', // Special option for no sound
  ];
  
  // Cache for discovered audio files
  List<String> _availableAdhans = ['Silent'];
  bool _cacheValid = false;
  
  /// Clear the cache to force re-discovery (call after download/delete)
  void clearCache() {
    _cacheValid = false;
    _availableAdhans = ['Silent'];
  }
  
  /// List of bundled adhan files in android/app/src/main/res/raw/
  /// ADD YOUR NEW ADHAN FILES HERE (display name for UI)
  /// The actual file in res/raw should be lowercase with underscores (e.g., rabeh_azan.mp3)
  static const List<String> bundledAdhans = [
    'fajr',
    'Rabeh Ibn Darah Al Jazairi - Adan Al Jazaer',
    ' Adham Al Sharqawe - Adhan'
    // Add more adhans here as you add them to res/raw/
  ];
  
  /// Default adhan for non-Fajr prayers (should not be 'fajr')
  static String get defaultNonFajrAdhan {
    // Return first bundled adhan that isn't 'fajr'
    for (final adhan in bundledAdhans) {
      if (adhan.toLowerCase() != 'fajr') {
        return adhan;
      }
    }
    return 'Silent';
  }
  
  /// Discover available adhan audio files (bundled + downloaded)
  /// Set excludeFajr to true to get only adhans for non-Fajr prayers selection
  Future<List<String>> getAvailableAdhans({bool excludeFajr = false}) async {
    if (_cacheValid && _availableAdhans.length > 1) {
      if (excludeFajr) {
        return _availableAdhans.where((a) => a.toLowerCase() != 'fajr').toList();
      }
      return _availableAdhans; // Return cached list
    }
    
    final List<String> foundAdhans = ['Silent'];
    
    // Add all bundled adhans from the static list
    // Files are stored in android/app/src/main/res/raw/
    for (final name in bundledAdhans) {
      foundAdhans.add(name);
      debugPrint('✅ Bundled adhan: $name');
    }
    
    _availableAdhans = foundAdhans;
    _cacheValid = true;
    
    if (excludeFajr) {
      return foundAdhans.where((a) => a.toLowerCase() != 'fajr').toList();
    }
    return foundAdhans;
  }

  // Keys for SharedPreferences
  static const String _selectedAdhanKey = 'selected_adhan';
  static const String _adhanVolumeKey = 'flutter.adhan_volume';
  static const String _fajrSoundKey = 'fajr_sound_enabled';
  static const String _dhuhrSoundKey = 'dhuhr_sound_enabled';
  static const String _asrSoundKey = 'asr_sound_enabled';
  static const String _maghribSoundKey = 'maghrib_sound_enabled';
  static const String _ishaSoundKey = 'isha_sound_enabled';

  /// Get adhan volume (0.0 to 1.0)
  Future<double> getAdhanVolume() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrate from legacy key without prefix if present
    final legacy = prefs.getDouble('adhan_volume');
    if (legacy != null) {
      return legacy;
    }
    return prefs.getDouble(_adhanVolumeKey) ?? 1.0;
  }

  /// Set adhan volume (0.0 to 1.0)
  Future<void> setAdhanVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = volume.clamp(0.0, 1.0);
    await prefs.setDouble(_adhanVolumeKey, clamped);
    // Also write legacy key for backward compatibility
    await prefs.setDouble('adhan_volume', clamped);
    debugPrint('Adhan volume set to: ${(volume * 100).toInt()}%');
  }

  /// Get selected adhan for non-Fajr prayers
  /// (Fajr always uses 'fajr' adhan - handled in playAdhan)
  /// Falls back to first non-fajr bundled adhan
  Future<String> getSelectedAdhan() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_selectedAdhanKey);
    
    // If nothing stored or 'fajr' stored, use default non-fajr adhan
    if (stored == null || stored.isEmpty || stored.toLowerCase() == 'fajr') {
      return defaultNonFajrAdhan;
    }
    
    // If Silent, return as-is
    if (stored == 'Silent') {
      return stored;
    }
    
    // Validate the stored adhan exists in available adhans
    final available = await getAvailableAdhans();
    if (available.contains(stored)) {
      return stored;
    }
    
    // Check if it's a valid file with lowercase name
    final lowerStored = stored.toLowerCase();
    if (available.map((e) => e.toLowerCase()).contains(lowerStored)) {
      // Fix the stored value to match case
      final correctName = available.firstWhere((e) => e.toLowerCase() == lowerStored);
      await prefs.setString(_selectedAdhanKey, correctName);
      return correctName;
    }
    
    // Invalid stored value - reset to default non-fajr adhan
    final defaultAdhan = defaultNonFajrAdhan;
    debugPrint('⚠️ Invalid adhan "$stored" - resetting to $defaultAdhan');
    await prefs.setString(_selectedAdhanKey, defaultAdhan);
    return defaultAdhan;
  }

  /// Set selected adhan
  Future<void> setSelectedAdhan(String adhan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedAdhanKey, adhan);
    debugPrint('Selected adhan set to: $adhan');
  }

  /// Get sound enabled status for a prayer
  Future<bool> getSoundEnabled(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getSoundKey(prayerName);
    return prefs.getBool(key) ?? true; // Default: enabled
  }

  /// Set sound enabled status for a prayer
  Future<void> setSoundEnabled(String prayerName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getSoundKey(prayerName);
    await prefs.setBool(key, enabled);
    debugPrint('$prayerName sound: ${enabled ? "enabled" : "disabled"}');
  }

  /// Get all sound settings
  Future<Map<String, bool>> getAllSoundSettings() async {
    return {
      'Fajr': await getSoundEnabled('Fajr'),
      'Dhuhr': await getSoundEnabled('Dhuhr'),
      'Asr': await getSoundEnabled('Asr'),
      'Maghrib': await getSoundEnabled('Maghrib'),
      'Isha': await getSoundEnabled('Isha'),
    };
  }

  /// Play adhan for a prayer using native service (continues playing even when notification pulled down)
  Future<void> playAdhan(String prayerName) async {
    try {
      // Check if sound is enabled for this prayer
      final soundEnabled = await getSoundEnabled(prayerName);
      if (!soundEnabled) {
        debugPrint('🔇 Sound disabled for $prayerName - skipping adhan');
        return;
      }

      // For Fajr prayer, always use 'fajr' adhan if available
      String selectedAdhan;
      if (prayerName.toLowerCase() == 'fajr') {
        selectedAdhan = 'fajr';
        debugPrint('🌅 Fajr prayer - using fajr adhan');
      } else {
        selectedAdhan = await getSelectedAdhan();
      }
      
      if (selectedAdhan == 'Silent') {
        debugPrint('🔇 Silent mode - no adhan will play');
        return;
      }
      
      // Get adhan volume
      final volume = await getAdhanVolume();
      debugPrint('   Volume: ${(volume * 100).toInt()}%');
      
      // Use bundled asset adhan
      debugPrint('🔊 Starting native adhan service for $prayerName');
      debugPrint('   Selected adhan: $selectedAdhan');
      
      try {
        await platform.invokeMethod('playAdhan', {
          'prayerName': prayerName,
          'soundFile': selectedAdhan,
          'volume': volume,
        });
        debugPrint('✅ Native adhan service started');
      } catch (e) {
        debugPrint('❌ Error starting native service: $e');
      }
      
    } catch (e) {
      debugPrint('❌ Error playing adhan: $e');
    }
  }

  /// Stop currently playing adhan
  Future<void> stopAdhan() async {
    try {
      // Stop native service
      try {
        await platform.invokeMethod('stopAdhan');
        debugPrint('🛑 Native adhan service stopped');
      } catch (e) {
        debugPrint('Error stopping native service: $e');
      }
      
      // Also stop AudioPlayer fallback
      await _player.stop();
      debugPrint('🛑 Adhan stopped');
    } catch (e) {
      debugPrint('Error stopping adhan: $e');
    }
  }
  
  /// Pause currently playing adhan
  Future<void> pauseAdhan() async {
    try {
      await platform.invokeMethod('pauseAdhan');
      debugPrint('⏸️ Adhan paused');
    } catch (e) {
      debugPrint('Error pausing adhan: $e');
    }
  }
  
  /// Resume paused adhan
  Future<void> resumeAdhan() async {
    try {
      await platform.invokeMethod('resumeAdhan');
      debugPrint('▶️ Adhan resumed');
    } catch (e) {
      debugPrint('Error resuming adhan: $e');
    }
  }
  
  /// Preview an adhan (for testing before selection)
  Future<void> previewAdhan(String adhanName) async {
    try {
      if (adhanName == 'Silent') {
        debugPrint('🔇 Silent mode - no preview available');
        return;
      }
      
      // Set volume for preview
      final volume = await getAdhanVolume();
      await _previewPlayer.setVolume(volume);
      await _previewPlayer.stop();
      
      // Preview using native service (same as actual playback)
      debugPrint('🔊 Previewing adhan: $adhanName');
      try {
        await platform.invokeMethod('playAdhan', {
          'prayerName': 'Preview',
          'soundFile': adhanName,
          'volume': volume,
        });
      } catch (e) {
        debugPrint('❌ Error previewing adhan: $e');
        rethrow;
      }
      
    } catch (e) {
      debugPrint('❌ Error previewing adhan: $e');
      rethrow;
    }
  }
  
  /// Stop preview
  Future<void> stopPreview() async {
    try {
      await _previewPlayer.stop();
      debugPrint('🛑 Preview stopped');
    } catch (e) {
      debugPrint('Error stopping preview: $e');
    }
  }

  /// Dispose the players
  void dispose() {
    _player.dispose();
    _previewPlayer.dispose();
  }

  // Helper method to get the SharedPreferences key for a prayer
  String _getSoundKey(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return _fajrSoundKey;
      case 'dhuhr':
      case 'zuhr':
        return _dhuhrSoundKey;
      case 'asr':
        return _asrSoundKey;
      case 'maghrib':
        return _maghribSoundKey;
      case 'isha':
        return _ishaSoundKey;
      default:
        return '${prayerName.toLowerCase()}_sound_enabled';
    }
  }
}
