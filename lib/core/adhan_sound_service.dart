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
  
  // Available audio files - users can add any MP3 file to assets/sounds/
  // The filename (without .mp3) will be the display name
  static const List<String> adhanOptions = [
    'Silent', // Special option for no sound
  ];
  
  // Cache for discovered audio files
  List<String> _availableAdhans = ['Silent'];
  
  /// Discover available adhan audio files in assets/sounds/
  Future<List<String>> getAvailableAdhans() async {
    if (_availableAdhans.length > 1) {
      return _availableAdhans; // Return cached list
    }
    
    final List<String> foundAdhans = ['Silent'];
    
    // Try to load common adhan file names
    final commonNames = [
      // Numbered adhans (checking up to 20)
      for (int i = 1; i <= 20; i++) 'adhan$i',
      for (int i = 1; i <= 20; i++) 'azan$i',
      // Common mosque names
      'makkah', 'madina', 'egypt', 'turkey', 'aqsa', 'quba',
      'al_aqsa', 'al_madina', 'al_makkah',
      // Common reciters/styles
      'sheikh_ali', 'sheikh_sudais', 'mishary', 'abdul_basit',
      'fajr_adhan', 'regular_adhan', 'beautiful_adhan',
      // Alternative spellings
      'mecca', 'medina', 'madinah', 'makkah_adhan', 'madina_adhan',
    ];
    
    for (final name in commonNames) {
      try {
        await rootBundle.load('assets/sounds/$name.mp3');
        foundAdhans.add(name);
        debugPrint('✅ Found adhan: $name.mp3');
      } catch (e) {
        // File doesn't exist, skip
      }
    }
    
    _availableAdhans = foundAdhans;
    return foundAdhans;
  }

  // Keys for SharedPreferences
  static const String _selectedAdhanKey = 'selected_adhan';
  static const String _fajrSoundKey = 'fajr_sound_enabled';
  static const String _dhuhrSoundKey = 'dhuhr_sound_enabled';
  static const String _asrSoundKey = 'asr_sound_enabled';
  static const String _maghribSoundKey = 'maghrib_sound_enabled';
  static const String _ishaSoundKey = 'isha_sound_enabled';

  /// Get selected adhan - validates stored value exists, falls back to azan1
  Future<String> getSelectedAdhan() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_selectedAdhanKey);
    
    // If nothing stored, use default
    if (stored == null || stored.isEmpty) {
      return 'azan1';
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
    
    // Invalid stored value - reset to default
    debugPrint('⚠️ Invalid adhan "$stored" - resetting to azan1');
    await prefs.setString(_selectedAdhanKey, 'azan1');
    return 'azan1';
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

      final selectedAdhan = await getSelectedAdhan();
      
      if (selectedAdhan == 'Silent') {
        debugPrint('🔇 Silent mode - no adhan will play');
        return;
      }

      debugPrint('🔊 Starting native adhan service for $prayerName');
      debugPrint('   Selected adhan: $selectedAdhan');
      
      // Use native service to play adhan (works even when app is killed)
      try {
        await platform.invokeMethod('playAdhan', {
          'prayerName': prayerName,
          'soundFile': selectedAdhan.toLowerCase(),
        });
        debugPrint('✅ Native adhan service started');
      } catch (e) {
        debugPrint('❌ Error starting native service: $e');
        debugPrint('   Falling back to AudioPlayer...');
        // Fallback to AudioPlayer if native service fails
        final audioPath = 'sounds/${selectedAdhan.toLowerCase()}.mp3';
        await _player.stop();
        await _player.play(AssetSource(audioPath));
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
      
      final audioPath = 'sounds/${adhanName.toLowerCase()}.mp3';
      debugPrint('🔊 Previewing: $audioPath');
      
      await _previewPlayer.stop();
      await _previewPlayer.play(AssetSource(audioPath));
      
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
