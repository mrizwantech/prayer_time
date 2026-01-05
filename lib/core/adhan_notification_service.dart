import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';

class AdhanNotificationService {
  static final AdhanNotificationService _instance = AdhanNotificationService._internal();
  factory AdhanNotificationService() => _instance;
  AdhanNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const String _channelId = 'adhan_channel';
  static const String _channelName = 'Prayer Time Notifications';
  static const String _channelDescription = 'Notifications for prayer times';

  Future<void> initialize() async {
    debugPrint('=== Initializing Notification Service ===');
    tz.initializeTimeZones();

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
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('=== BACKGROUND NOTIFICATION TAPPED ===');
    debugPrint('Response ID: ${response.id}');
    debugPrint('Action ID: ${response.actionId}');
    debugPrint('Payload: ${response.payload}');
    
    // Handle snooze in background
    if (response.actionId == 'snooze') {
      debugPrint('Background snooze detected!');
      // Note: Background handler is static, so we need to handle it differently
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
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

    try {
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
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(
              'It\'s time to pray $prayerName',
              contentTitle: 'Time for $prayerName Prayer',
            ),
            actions: <AndroidNotificationAction>[
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
      debugPrint('Notification scheduled for $prayerName at $scheduledTime');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
      debugPrint('Note: Exact alarm permission may be required on Android 12+');
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
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('=== NOTIFICATION TAPPED ===');
    debugPrint('Response ID: ${response.id}');
    debugPrint('Action ID: ${response.actionId}');
    debugPrint('Payload: ${response.payload}');
    debugPrint('Input: ${response.input}');
    
    if (response.actionId == 'snooze') {
      debugPrint('SNOOZE action detected!');
      // Parse payload: prayerName|nextPrayerTime
      final parts = response.payload?.split('|');
      if (parts != null && parts.length == 2) {
        final prayerName = parts[0];
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
      cancelNotification(response.id ?? 0);
    } else {
      // If action ID is null but we have payload, auto-snooze
      debugPrint('No action ID - checking if we should auto-snooze from payload');
      if (response.payload != null && response.payload!.isNotEmpty) {
        final parts = response.payload!.split('|');
        if (parts.length == 2) {
          final prayerName = parts[0];
          final nextPrayerTime = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1]));
          
          debugPrint('Auto-snoozing for $prayerName (workaround for action button issue)');
          snoozeNotification(
            id: response.id ?? 0,
            prayerName: prayerName,
            nextPrayerTime: nextPrayerTime,
          );
        }
      } else {
        debugPrint('Notification tapped (no action, no payload)');
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
