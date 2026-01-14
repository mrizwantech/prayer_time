import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Service to handle Firebase Analytics throughout the app
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(analytics: _analytics);

  /// Log app open event
  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      debugPrint('📊 Analytics: App opened');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log screen view
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      debugPrint('📊 Analytics: Screen view - $screenName');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log prayer time viewed
  Future<void> logPrayerTimeViewed(String prayerName) async {
    try {
      await _analytics.logEvent(
        name: 'prayer_time_viewed',
        parameters: {'prayer_name': prayerName},
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log adhan played
  Future<void> logAdhanPlayed(String prayerName, {String? adhanType}) async {
    try {
      await _analytics.logEvent(
        name: 'adhan_played',
        parameters: {
          'prayer_name': prayerName,
          if (adhanType != null) 'adhan_type': adhanType,
        },
      );
      debugPrint('📊 Analytics: Adhan played - $prayerName');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log Qibla compass used
  Future<void> logQiblaCompassUsed() async {
    try {
      await _analytics.logEvent(name: 'qibla_compass_used');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log Quran read
  Future<void> logQuranRead({String? surahName, int? surahNumber}) async {
    try {
      await _analytics.logEvent(
        name: 'quran_read',
        parameters: {
          if (surahName != null) 'surah_name': surahName,
          if (surahNumber != null) 'surah_number': surahNumber,
        },
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log Tasbeeh counter used
  Future<void> logTasbeehUsed({int? count, String? dhikr}) async {
    try {
      await _analytics.logEvent(
        name: 'tasbeeh_used',
        parameters: {
          if (count != null) 'count': count,
          if (dhikr != null) 'dhikr': dhikr,
        },
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log Rakah counter used
  Future<void> logRakahCounterUsed({String? prayerType}) async {
    try {
      await _analytics.logEvent(
        name: 'rakah_counter_used',
        parameters: {
          if (prayerType != null) 'prayer_type': prayerType,
        },
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log Islamic post created
  Future<void> logIslamicPostCreated({String? postType}) async {
    try {
      await _analytics.logEvent(
        name: 'islamic_post_created',
        parameters: {
          if (postType != null) 'post_type': postType,
        },
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log calculation method changed
  Future<void> logCalculationMethodChanged(String method) async {
    try {
      await _analytics.logEvent(
        name: 'calculation_method_changed',
        parameters: {'method': method},
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log notification settings changed
  Future<void> logNotificationSettingsChanged({
    String? prayerName,
    bool? enabled,
    bool? soundEnabled,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'notification_settings_changed',
        parameters: {
          if (prayerName != null) 'prayer_name': prayerName,
          if (enabled != null) 'enabled': enabled ? 1 : 0,
          if (soundEnabled != null) 'sound_enabled': soundEnabled ? 1 : 0,
        },
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log share action
  Future<void> logShare({required String contentType, String? itemId}) async {
    try {
      await _analytics.logShare(
        contentType: contentType,
        itemId: itemId ?? '',
        method: 'app',
      );
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Set user property
  Future<void> setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }

  /// Log custom event
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      debugPrint('📊 Analytics: $name');
    } catch (e) {
      debugPrint('❌ Analytics error: $e');
    }
  }
}
