import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'adhan_sound_service.dart';
import '../main.dart' show navigatorKey;

@pragma('vm:entry-point')
class AdhanNotificationService {
  static final AdhanNotificationService _instance = AdhanNotificationService._internal();
  factory AdhanNotificationService() => _instance;
  AdhanNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final _soundService = AdhanSoundService();
  bool _isAdhanPlayerActive = false; // Prevent multiple launches
  String? _pendingAdhanLaunch; // Queue for pending adhan player launch
  
  static const platform = MethodChannel('com.mrizwantech.azanify/adhan_alarm');
  
  static const String _channelId = 'adhan_channel_v2';
  static const String _channelName = 'Prayer Time Notifications';
  static const String _channelDescription = 'Notifications for prayer times';

  Future<void> initialize() async {
    debugPrint('=== Initializing Notification Service ===');
    tz.initializeTimeZones();
    
    // Set the local timezone
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    final timeZoneName = timezoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    debugPrint('Local timezone set to: $timeZoneName');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    debugPrint('Notification plugin initialized: $initialized');
    debugPrint('Callback registered: ${_onNotificationTapped != null}');

    await _createNotificationChannel();
    debugPrint('Notification channel created');
    
    // Set up callback for native adhan player launch
    _soundService.setLaunchAdhanPlayerCallback((prayerName) {
      debugPrint('📱 Callback received to launch adhan player for $prayerName');
      _launchAdhanPlayerScreen(prayerName);
    });
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('=== BACKGROUND NOTIFICATION TAPPED ===');
    debugPrint('Response ID: ${response.id}');
    debugPrint('Action ID: ${response.actionId}');
    debugPrint('Payload: ${response.payload}');
    
    // Handle stop adhan action
    if (response.actionId == 'stop_adhan') {
      debugPrint('🛑 Background stop adhan detected');
      final soundService = AdhanSoundService();
      soundService.stopAdhan();
      return;
    }
    
    // Play adhan sound for notification
    final payload = response.payload?.split('|');
    if (payload != null && payload.isNotEmpty) {
      final prayerName = payload[0];
      final soundService = AdhanSoundService();
      soundService.playAdhan(prayerName);
    }
    
    // Handle snooze in background
    if (response.actionId == 'snooze') {
      debugPrint('Background snooze detected!');
      final soundService = AdhanSoundService();
      soundService.stopAdhan();
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true, // Enable sound for adhan playback
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Get notification app launch details
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    return await _notifications.getNotificationAppLaunchDetails();
  }

  /// Request notification permissions from the user
  /// Returns true if permissions are granted
  Future<bool> requestPermissions() async {
    // Request Android 13+ notification permission
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl != null) {
      // Request notification permission
      final notificationGranted = await androidImpl.requestNotificationsPermission();
      debugPrint('Notification permission granted: $notificationGranted');
      
      // Request exact alarm permission
      try {
        final exactAlarmGranted = await androidImpl.requestExactAlarmsPermission();
        debugPrint('Exact alarm permission granted: $exactAlarmGranted');
        return notificationGranted == true && exactAlarmGranted == true;
      } catch (e) {
        debugPrint('Error requesting exact alarm permission: $e');
        return notificationGranted == true;
      }
    }
    
    // For iOS, permissions are requested during initialization
    return true;
  }

  Future<void> schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    required DateTime nextPrayerTime,
  }) async {
    final timeUntilPrayer = prayerTime.difference(DateTime.now());
    
    if (timeUntilPrayer.isNegative) return;

    final scheduledTime = tz.TZDateTime.from(prayerTime, tz.local);
    
    debugPrint('📅 Scheduling notification:');
    debugPrint('   Prayer: $prayerName');
    debugPrint('   Input time: $prayerTime');
    debugPrint('   TZ scheduled time: $scheduledTime');
    debugPrint('   Timezone: ${tz.local.name}');
    debugPrint('   Current time: ${DateTime.now()}');
    debugPrint('   Seconds until: ${scheduledTime.difference(DateTime.now()).inSeconds}');

    // Check if sound should play for this prayer
    final shouldPlaySound = await _soundService.getSoundEnabled(prayerName);
    debugPrint('   Sound enabled for $prayerName: $shouldPlaySound');

    try {
      // Schedule Android alarm to auto-launch adhan player and play sound
      // This also shows the notification via the native foreground service
      if (shouldPlaySound) {
        try {
          final selectedAdhan = await _soundService.getSelectedAdhan();
          await platform.invokeMethod('scheduleAdhanAlarm', {
            'prayerName': prayerName,
            'soundFile': selectedAdhan,
            'triggerTime': scheduledTime.millisecondsSinceEpoch,
            'requestCode': id,
          });
          debugPrint('✅ Android native alarm scheduled for $prayerName');
          // Don't schedule Flutter notification - native service handles everything
          return;
        } catch (e) {
          debugPrint('⚠️ Error scheduling Android alarm: $e - falling back to Flutter notification');
        }
      }
      
      // Fall back to Flutter notification only if native alarm fails or sound is disabled
      await _notifications.zonedSchedule(
        id,
        'Time for $prayerName Prayer',
        'It\'s time to pray $prayerName',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.max,
            playSound: false,
            enableVibration: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            ongoing: false,
            autoCancel: true,
            styleInformation: BigTextStyleInformation(
              'It\'s time to pray $prayerName',
              contentTitle: 'Time for $prayerName Prayer',
            ),
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'stop_adhan',
                'STOP ADHAN',
                showsUserInterface: false,
              ),
              const AndroidNotificationAction(
                'snooze',
                'SNOOZE',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'dismiss',
                'DISMISS',
                showsUserInterface: true,
              ),
            ],
            // Add tag to identify this is a prayer notification
            tag: 'prayer_$prayerName',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$prayerName|${nextPrayerTime.millisecondsSinceEpoch}',
      );
      final localTime = scheduledTime.toLocal();
      final now = DateTime.now();
      final secondsUntil = scheduledTime.difference(now).inSeconds;
      debugPrint('✅ Flutter notification scheduled for $prayerName (fallback)');
      debugPrint('   Scheduled time: $localTime (in $secondsUntil seconds)');
      debugPrint('   Current time: $now');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      debugPrint('Note: Exact alarm permission may be required on Android 12+');
    }
  }

  /// Schedule a simple notification for Sunrise (no adhan sound)
  Future<void> scheduleSunriseNotification({
    required int id,
    required DateTime sunriseTime,
  }) async {
    final timeUntilSunrise = sunriseTime.difference(DateTime.now());
    
    if (timeUntilSunrise.isNegative) return;

    final scheduledTime = tz.TZDateTime.from(sunriseTime, tz.local);
    
    debugPrint('📅 Scheduling Sunrise notification:');
    debugPrint('   Sunrise time: $sunriseTime');
    debugPrint('   TZ scheduled time: $scheduledTime');

    try {
      await _notifications.zonedSchedule(
        id,
        '🌅 Sunrise',
        'The sun has risen. Have a blessed day!',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            autoCancel: true,
            icon: '@mipmap/ic_launcher',
            styleInformation: const BigTextStyleInformation(
              'The sun has risen. Have a blessed day!',
              contentTitle: '🌅 Sunrise',
            ),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'Sunrise',
      );
      debugPrint('✅ Sunrise notification scheduled');
    } catch (e) {
      debugPrint('Error scheduling Sunrise notification: $e');
    }
  }

  Future<void> snoozeNotification({
    required int id,
    required String prayerName,
    required DateTime nextPrayerTime,
  }) async {
    debugPrint('=== SNOOZE TRIGGERED ===');
    debugPrint('Prayer: $prayerName');
    debugPrint('Next Prayer Time: $nextPrayerTime');
    
    // Cancel the original notification first
    await cancelNotification(id);
    debugPrint('Original notification cancelled');
    
    // Calculate snooze time: 5 minutes before next prayer
    final snoozeTime = nextPrayerTime.subtract(const Duration(minutes: 5));
    final now = DateTime.now();
    final timeUntilSnooze = snoozeTime.difference(now);
    
    debugPrint('Snooze scheduled for: $snoozeTime');
    debugPrint('Current time: $now');

    if (snoozeTime.isBefore(now)) {
      debugPrint('Snooze time already passed, showing immediate notification');
      // If less than 5 minutes left, notify immediately
      await showImmediateNotification(
        id: id,
        title: 'Last Call for $prayerName Prayer',
        body: 'Prayer time is ending soon!',
      );
      return;
    }

    // Show immediate feedback that snooze was activated
    final minutesUntilSnooze = timeUntilSnooze.inMinutes;
    await showImmediateNotification(
      id: id + 500, // Different ID for snooze confirmation
      title: '⏰ Snoozed - $prayerName Prayer',
      body: 'You will be reminded in $minutesUntilSnooze minutes (5 min before prayer ends)',
    );
    debugPrint('Snooze confirmation shown');

    try {
      final scheduledTime = tz.TZDateTime.from(snoozeTime, tz.local);

      await _notifications.zonedSchedule(
        id + 1000, // Different ID for snoozed notification
        'Last Call for $prayerName Prayer',
        'Only 5 minutes left to pray $prayerName',
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.max,
            ongoing: true,
            autoCancel: false,
            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'stop_adhan',
                'STOP ADHAN',
                showsUserInterface: false,
              ),
              const AndroidNotificationAction(
                'dismiss',
                'DISMISS',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$prayerName|${nextPrayerTime.millisecondsSinceEpoch}',
      );
      debugPrint('Snooze notification scheduled successfully for $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling snooze notification: $e');
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool includeActions = false,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.max,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
          actions: includeActions ? <AndroidNotificationAction>[
            AndroidNotificationAction(
              'snooze',
              'SNOOZE',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'dismiss',
              'DISMISS',
              showsUserInterface: true,
            ),
          ] : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
  
  /// Schedule adhan playback to happen at notification time
  void _scheduleAdhanPlayback(String prayerName, tz.TZDateTime notificationTime) {
    final delay = notificationTime.difference(DateTime.now());
    
    if (delay.isNegative || delay.inSeconds < 1) {
      // Play immediately if time has passed or very soon
      debugPrint('🔊 Playing adhan immediately for $prayerName');
      _playAdhanWithControls(prayerName);
      return;
    }
    
    debugPrint('🕐 Scheduling adhan playback for $prayerName in ${delay.inSeconds} seconds');
    Future.delayed(delay, () {
      debugPrint('🔊 Auto-playing adhan for $prayerName (scheduled time reached)');
      _playAdhanWithControls(prayerName);
    });
  }
  
  /// Play adhan and launch adhan player screen
  Future<void> _playAdhanWithControls(String prayerName) async {
    // Launch the adhan player screen which will handle playback
    _launchAdhanPlayerScreen(prayerName);
  }
  
  /// Launch the adhan player screen
  void _launchAdhanPlayerScreen(String prayerName) {
    if (_isAdhanPlayerActive) {
      debugPrint('⚠️ Adhan player already active, skipping launch');
      return;
    }
    
    debugPrint('📱 Launching adhan player screen for $prayerName');
    
    // Check if navigator is available
    if (navigatorKey.currentState != null) {
      _performAdhanPlayerNavigation(prayerName);
    } else {
      // Navigator not ready yet - queue the launch and retry
      debugPrint('⏳ Navigator not ready, queuing launch for $prayerName');
      _pendingAdhanLaunch = prayerName;
      _waitForNavigatorAndLaunch();
    }
  }
  
  void _waitForNavigatorAndLaunch() {
    // Use a post-frame callback to check when navigator becomes available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingAdhanLaunch != null) {
        if (navigatorKey.currentState != null) {
          debugPrint('✅ Navigator now ready, launching adhan player');
          final prayerName = _pendingAdhanLaunch!;
          _pendingAdhanLaunch = null;
          _performAdhanPlayerNavigation(prayerName);
        } else {
          // Still not ready, try again
          debugPrint('⏳ Still waiting for navigator...');
          Future.delayed(const Duration(milliseconds: 100), () {
            _waitForNavigatorAndLaunch();
          });
        }
      }
    });
  }
  
  void _performAdhanPlayerNavigation(String prayerName) {
    if (_isAdhanPlayerActive) {
      debugPrint('⚠️ Adhan player already active, skipping navigation');
      return;
    }
    
    _isAdhanPlayerActive = true;
    debugPrint('🚀 Navigating to adhan player screen for $prayerName');
    
    navigatorKey.currentState!.pushNamed(
      '/adhan-player',
      arguments: {'prayerName': prayerName},
    ).then((_) {
      // Reset flag when screen is closed
      _isAdhanPlayerActive = false;
      debugPrint('🚪 Adhan player screen closed');
    });
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('=== NOTIFICATION TAPPED ===');
    debugPrint('Response ID: ${response.id}');
    debugPrint('Action ID: ${response.actionId}');
    debugPrint('Payload: ${response.payload}');
    debugPrint('Input: ${response.input}');
    
    // Handle stop adhan action
    if (response.actionId == 'stop_adhan') {
      debugPrint('🛑 Stop adhan action detected');
      _soundService.stopAdhan();
      return;
    }
    
    // Parse payload to get prayer name
    final parts = response.payload?.split('|');
    final prayerName = parts != null && parts.isNotEmpty ? parts[0] : null;
    
    if (response.actionId == 'snooze') {
      debugPrint('SNOOZE action detected!');
      // Stop adhan when snoozed
      _soundService.stopAdhan();
      
      // Parse payload: prayerName|nextPrayerTime
      if (parts != null && parts.length == 2 && prayerName != null) {
        final nextPrayerTime = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
        
        debugPrint('Calling snoozeNotification for $prayerName');
        snoozeNotification(
          id: response.id ?? 0,
          prayerName: prayerName,
          nextPrayerTime: nextPrayerTime,
        );
      } else {
        debugPrint('ERROR: Invalid payload format: ${response.payload}');
      }
    } else if (response.actionId == 'dismiss') {
      debugPrint('DISMISS action detected - notification dismissed');
      _soundService.stopAdhan();
      cancelNotification(response.id ?? 0);
    } else {
      // Notification body tapped or app opened from notification - launch adhan player screen
      if (prayerName != null) {
        debugPrint('📱 Launching adhan player screen for $prayerName (notification interaction)');
        _launchAdhanPlayerScreen(prayerName);
      }
    }
  }

  Duration getTimeRemainingForPrayer(DateTime nextPrayerTime) {
    return nextPrayerTime.difference(DateTime.now());
  }

  /// Schedule all prayer notifications for today using user's location
  Future<void> scheduleAllPrayersForToday() async {
    try {
      debugPrint('=== Scheduling all prayers for today ===');
      
      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint('Location: ${position.latitude}, ${position.longitude}');

      // Calculate prayer times using adhan package
      final coordinates = Coordinates(position.latitude, position.longitude);
      final params = CalculationMethod.muslim_world_league.getParameters();
      final dateComponents = DateComponents.from(DateTime.now());
      final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

      // Map prayer names to their times
      final prayers = {
        'Fajr': prayerTimes.fajr,
        'Dhuhr': prayerTimes.dhuhr,
        'Asr': prayerTimes.asr,
        'Maghrib': prayerTimes.maghrib,
        'Isha': prayerTimes.isha,
      };

      // Schedule Sunrise notification (simple notification, no adhan)
      await scheduleSunriseNotification(
        id: 99, // Use ID 99 for Sunrise
        sunriseTime: prayerTimes.sunrise,
      );
      debugPrint('Scheduled Sunrise at ${prayerTimes.sunrise}');

      // Schedule notifications for each prayer
      int id = 100; // Starting ID for prayer notifications
      for (var entry in prayers.entries) {
        final prayerName = entry.key;
        final prayerTime = entry.value;
        
        // Find next prayer time for snooze calculation
        DateTime nextPrayerTime;
        if (prayerName == 'Isha') {
          // After Isha, next is tomorrow's Fajr
          final tomorrowComponents = DateComponents.from(DateTime.now().add(const Duration(days: 1)));
          final tomorrowTimes = PrayerTimes(coordinates, tomorrowComponents, params);
          nextPrayerTime = tomorrowTimes.fajr;
        } else {
          // Get next prayer in sequence
          final prayersList = prayers.values.toList();
          final currentIndex = prayersList.indexOf(prayerTime);
          nextPrayerTime = prayersList[currentIndex + 1];
        }

        await schedulePrayerNotification(
          id: id++,
          prayerName: prayerName,
          prayerTime: prayerTime,
          nextPrayerTime: nextPrayerTime,
        );
        debugPrint('Scheduled $prayerName at $prayerTime');
      }

      debugPrint('All prayer notifications scheduled successfully');
    } catch (e) {
      debugPrint('Error scheduling all prayers: $e');
    }
  }
}
