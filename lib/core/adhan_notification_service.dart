import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Future<void> _darwinScheduleTail = Future.value();

  bool get isAdhanPlayerActive => _isAdhanPlayerActive;
  bool get hasPendingAdhanLaunch => _pendingAdhanLaunch != null;
  
  static const platform = MethodChannel('com.mrizwantech.azanify/adhan_alarm');
  static const _iosAlarmChannel = MethodChannel('com.mrizwantech.azanify/ios_alarm');

  /// True when AlarmKit (iOS 26+) is available and the user allowed alarms.
  Future<bool> _iosAlarmsAuthorized() async {
    if (!Platform.isIOS) return false;
    try {
      return await _iosAlarmChannel.invokeMethod<bool>('isAuthorized') ?? false;
    } catch (e) {
      debugPrint('AlarmKit unavailable: $e');
      return false;
    }
  }

  /// Schedules a full-screen AlarmKit alarm. Returns false so callers can fall
  /// back to a regular notification.
  Future<bool> _scheduleIosAlarm(String prayerName, String title, DateTime at, String? sound) async {
    try {
      await _iosAlarmChannel.invokeMethod('schedule', {
        'prayerName': prayerName,
        'title': title,
        'time': at.millisecondsSinceEpoch,
        'sound': sound,
      });
      return true;
    } catch (e) {
      debugPrint('⚠️ AlarmKit schedule failed for $prayerName: $e');
      return false;
    }
  }
  
  static const String _channelId = 'adhan_channel_v2';
  static const String _channelName = 'Prayer Time Notifications';
  static const String _channelDescription = 'Notifications for prayer times';

  Future<void> initialize() async {
    debugPrint('=== Initializing Notification Service ===');
    tz.initializeTimeZones();
    
    // Set the local timezone
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    // FlutterTimezone 5.x returns TimezoneInfo object, get the identifier
    final timeZoneName = timezoneInfo.identifier;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Local timezone set to: $timeZoneName');
    } catch (e) {
      debugPrint('Error setting timezone $timeZoneName: $e');
      // Fallback to UTC if timezone not found
      tz.setLocalLocation(tz.UTC);
      debugPrint('Falling back to UTC timezone');
    }

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
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped);

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
    if (payload != null && payload.length >= 3 && payload[2] != 'adhan') {
      return;
    }
    final prayerName = payload != null && payload.isNotEmpty ? payload[0] : null;
    if (prayerName != null) {
      final soundService = AdhanSoundService();
      soundService.playAdhan(prayerName);
    }

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
    
    final iosImpl = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      debugPrint('iOS notification permission granted: $granted');
      try {
        if (await _iosAlarmChannel.invokeMethod<bool>('isAvailable') ?? false) {
          final alarms = await _iosAlarmChannel.invokeMethod<bool>('requestAuthorization');
          debugPrint('iOS AlarmKit permission granted: $alarms');
        }
      } catch (e) {
        debugPrint('AlarmKit authorization error: $e');
      }
      return granted ?? false;
    }

    return true;
  }

  Future<void> schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
    required DateTime nextPrayerTime,
  }) async {
    final now = DateTime.now();
    final timeUntilPrayer = prayerTime.difference(now);
    
    debugPrint('📅 Checking $prayerName: prayerTime=$prayerTime, now=$now, diff=${timeUntilPrayer.inMinutes} min');
    
    if (timeUntilPrayer.isNegative) {
      debugPrint('⏭️ Skipping $prayerName - prayer time already passed');
      return;
    }

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
      // Schedule Android alarm. For test buttons (Test or specific prayer tests), schedule at the provided time.
      // For normal prayers during regular scheduling, rely on native single-next chaining for reliability.
      if (shouldPlaySound && Platform.isAndroid) {
        try {
          final selectedAdhan = await _soundService.getSelectedAdhan();
          // Use direct alarm scheduling for test prayers OR if this is an Isha test (id 997)
          // Regular prayers use scheduleNextPrayer for chaining
          final isTestAlarm = prayerName.toLowerCase() == 'test' || id == 997 || id == 998;
          if (isTestAlarm) {
            // Use Fajr adhan for Fajr, selected adhan for others
            final soundFile = prayerName.toLowerCase() == 'fajr' ? 'fajr' : selectedAdhan;
            await platform.invokeMethod('scheduleAdhanAlarm', {
              'prayerName': prayerName,
              'soundFile': soundFile,
              'triggerTime': scheduledTime.millisecondsSinceEpoch,
              'requestCode': id,
            });
            debugPrint('✅ Android native TEST alarm scheduled for $prayerName at $scheduledTime');
          } else {
            await platform.invokeMethod('scheduleNextPrayer');
            debugPrint('✅ Requested native scheduleNextPrayer for $prayerName');
          }
          // Don't schedule Flutter notification - native service handles everything
          return;
        } catch (e) {
          debugPrint('⚠️ Error requesting native alarm: $e - falling back to Flutter notification');
        }
      }
      
      final iosSound = Platform.isAndroid ? null : await _darwinAdhanSound(prayerName);

      if (iosSound != null && iosSound != '' &&
          await _iosAlarmsAuthorized() &&
          await _scheduleIosAlarm(prayerName, 'Time for $prayerName Prayer', prayerTime, iosSound)) {
        debugPrint('✅ AlarmKit alarm scheduled for $prayerName at $prayerTime');
        return;
      }

      // Fall back to Flutter notification only if native alarm fails or sound is disabled
      await _notifications.zonedSchedule(
        id: id,
        title: 'Time for $prayerName Prayer',
        body: 'It\'s time to pray $prayerName',
        scheduledDate: scheduledTime,
        notificationDetails: NotificationDetails(
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
          iOS: _darwinPrayerDetails(iosSound),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$prayerName|${nextPrayerTime.millisecondsSinceEpoch}'
            '${Platform.isIOS ? '|${_soundPayload(iosSound)}' : ''}');
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

  /// Schedule a silent Tahajjud reminder (no adhan) before Fajr.
  Future<void> scheduleTahajjudNotification({
    required DateTime ishaTime,
    required DateTime fajrTime,
    bool isRamadan = false,
    Duration offset = const Duration(minutes: 90),
  }) async {
    // During Ramadan, nudge closer to Fajr as a suhoor ending reminder
    final effectiveOffset = isRamadan ? const Duration(minutes: 45) : offset;
    // Place reminder offset minutes before Fajr, but after Isha, and only if still future.
    var target = fajrTime.subtract(effectiveOffset);
    if (target.isBefore(ishaTime)) {
      target = ishaTime.add(const Duration(minutes: 5));
    }

    final now = DateTime.now();
    if (!target.isAfter(now)) {
      debugPrint('⏭️ Skipping Tahajjud reminder - time already passed ($target)');
      return;
    }

    final scheduledTime = tz.TZDateTime.from(target, tz.local);
    debugPrint('🕐 Scheduling Tahajjud reminder at $scheduledTime (offset: ${effectiveOffset.inMinutes}m before Fajr)');

    final title = isRamadan ? 'Suhoor ending soon' : 'Tahajjud Reminder';
    final body = isRamadan
        ? 'Wrap up suhoor before Fajr.'
        : 'Time for night prayer (no adhan).';

    await _notifications.zonedSchedule(
      id: 910, title: // dedicated id for Tahajjud
      title,
      body: body,
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: true,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'Tahajjud');
  }

  /// Schedule repeating Suhoor reminders (adhan sound) from start window until Fajr.
  Future<void> scheduleSuhoorRepeatingReminders({
    required DateTime fajrTime,
    required int startMinutesBeforeFajr,
    required int intervalMinutes,
  }) async {
    final start = fajrTime.subtract(Duration(minutes: startMinutesBeforeFajr));
    final now = DateTime.now();
    var cursor = start.isBefore(now) ? now : start;

    // Align cursor to nearest interval step from start
    final elapsedFromStart = cursor.difference(start).inMinutes;
    final remainder = elapsedFromStart % intervalMinutes;
    if (remainder != 0) {
      cursor = cursor.add(Duration(minutes: intervalMinutes - remainder));
    }

    final reminders = <DateTime>[];
    while (cursor.isBefore(fajrTime)) {
      reminders.add(cursor);
      cursor = cursor.add(Duration(minutes: intervalMinutes));
    }

    if (reminders.isEmpty) {
      debugPrint('⏭️ No suhoor reminders to schedule (window passed)');
      return;
    }

    debugPrint('🕐 Scheduling ${reminders.length} suhoor reminders (interval $intervalMinutes m)');
    int id = 930; // id range for suhoor repeats
    for (final time in reminders) {
      final scheduledTime = tz.TZDateTime.from(time, tz.local);
      await _notifications.zonedSchedule(
        id: id,
        title: 'Suhoor reminder',
        body: 'Wrap up suhoor before Fajr.',
        scheduledDate: scheduledTime,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            autoCancel: true,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'Suhoor');
      id++;
    }
  }

  /// Schedule a single Iftar alert before Maghrib.
  Future<void> scheduleIftarReminder({
    required DateTime maghribTime,
    required int minutesBeforeMaghrib,
  }) async {
    final target = maghribTime.subtract(Duration(minutes: minutesBeforeMaghrib));
    if (!target.isAfter(DateTime.now())) {
      debugPrint('⏭️ Skipping Iftar reminder - time passed');
      return;
    }

    final scheduledTime = tz.TZDateTime.from(target, tz.local);
    debugPrint('🕐 Scheduling Iftar reminder at $scheduledTime');

    await _notifications.zonedSchedule(
      id: 940, title: // dedicated id for iftar alert
      'Iftar dua',
      body: 'Allahumma inni laka sumtu wa bika aamantu wa alayka tawakkaltu wa ala rizqika aftartu.',
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'Iftar');
  }

  /// Single Suhoor dua reminder 5 minutes before Fajr.
  Future<void> scheduleSuhoorDuaReminder({
    required DateTime fajrTime,
  }) async {
    final target = fajrTime.subtract(const Duration(minutes: 5));
    if (!target.isAfter(DateTime.now())) {
      debugPrint('⏭️ Skipping Suhoor dua reminder - time passed');
      return;
    }

    final scheduledTime = tz.TZDateTime.from(target, tz.local);
    debugPrint('🕐 Scheduling Suhoor dua reminder at $scheduledTime');

    await _notifications.zonedSchedule(
      id: 941, title: // dedicated id for suhoor dua
      'Suhoor dua',
      body: 'Wa bisawmi ghadin nawaitu min shahri Ramadan.',
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          autoCancel: true,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'SuhoorDua');
  }

  /// Schedule Taraweeh reminder after Isha during Ramadan (silent).
  Future<void> scheduleTaraweehReminder({
    required DateTime ishaTime,
    Duration offset = const Duration(minutes: 10),
  }) async {
    final now = DateTime.now();
    var target = ishaTime.add(offset);
    if (!target.isAfter(now)) {
      debugPrint('⏭️ Skipping Taraweeh reminder - time already passed ($target)');
      return;
    }

    final scheduledTime = tz.TZDateTime.from(target, tz.local);
    debugPrint('🕐 Scheduling Taraweeh reminder at $scheduledTime');

    await _notifications.zonedSchedule(
      id: 911, title: // dedicated id for Taraweeh
      'Taraweeh time',
      body: 'Let\'s begin Taraweeh after Isha.',
      scheduledDate: scheduledTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: true,
          fullScreenIntent: false,
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'Taraweeh');
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
        id: id,
        title: '🌅 Sunrise',
        body: 'The sun has risen. Have a blessed day!',
        scheduledDate: scheduledTime,
        notificationDetails: NotificationDetails(
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
        payload: 'Sunrise');
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
        id: id + 1000, title: // Different ID for snoozed notification
        'Last Call for $prayerName Prayer',
        body: 'Only 5 minutes left to pray $prayerName',
        scheduledDate: scheduledTime,
        notificationDetails: NotificationDetails(
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
        payload: '$prayerName|${nextPrayerTime.millisecondsSinceEpoch}');
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
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
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
      payload: payload);
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    // Also cancel native alarms
    try {
      await platform.invokeMethod('cancelAllAlarms');
    } catch (e) {
      debugPrint('Error cancelling native alarms: $e');
    }
  }
  
  /// Get list of pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
  
  /// Debug method to print all scheduled notifications
  Future<void> debugPrintPendingNotifications() async {
    final pending = await getPendingNotifications();
    debugPrint('=== PENDING NOTIFICATIONS (${pending.length}) ===');
    for (var notification in pending) {
      debugPrint('  ID: ${notification.id}, Title: ${notification.title}, Payload: ${notification.payload}');
    }
    if (pending.isEmpty) {
      debugPrint('  (No pending notifications scheduled)');
    }
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
      if (parts != null && parts.length >= 2 && prayerName != null) {
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
      if (prayerName != null && (parts == null || parts.length < 3 || parts[2] == 'adhan')) {
        debugPrint('📱 Launching adhan player screen for $prayerName (notification interaction)');
        _launchAdhanPlayerScreen(prayerName);
      }
    }
  }

  Duration getTimeRemainingForPrayer(DateTime nextPrayerTime) {
    return nextPrayerTime.difference(DateTime.now());
  }

  /// Get calculation parameters from saved preferences
  Future<CalculationParameters> _getCalculationParams() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMethod = prefs.getString('calculation_method');
    
    if (savedMethod != null) {
      switch (savedMethod) {
        case 'muslimWorldLeague':
          return CalculationMethod.muslim_world_league.getParameters();
        case 'isna':
          return CalculationMethod.north_america.getParameters();
        case 'egyptian':
          return CalculationMethod.egyptian.getParameters();
        case 'ummAlQura':
          return CalculationMethod.umm_al_qura.getParameters();
        case 'dubai':
          return CalculationMethod.dubai.getParameters();
        case 'qatar':
          return CalculationMethod.qatar.getParameters();
        case 'kuwait':
          return CalculationMethod.kuwait.getParameters();
        case 'singapore':
          return CalculationMethod.singapore.getParameters();
        case 'karachi':
          return CalculationMethod.karachi.getParameters();
        case 'tehran':
          return CalculationMethod.tehran.getParameters();
        case 'turkey':
          return CalculationMethod.turkey.getParameters();
      }
    }
    
    // Default to ISNA for North America
    return CalculationMethod.north_america.getParameters();
  }

  /// Schedule all prayer notifications for today using user's location
  /// If coordinates are provided, use them instead of fetching location again
  Future<void> scheduleAllPrayersForToday({double? latitude, double? longitude}) async {
    try {
      debugPrint('=== Scheduling next prayer (single) ===');
      
      double lat;
      double lng;
      
      // Use provided coordinates or fetch location
      if (latitude != null && longitude != null) {
        lat = latitude;
        lng = longitude;
        debugPrint('Using provided location: $lat, $lng');
      } else {
        // Try last known first, then current with lowest accuracy
        Position? position = await Geolocator.getLastKnownPosition();
        position ??= await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.lowest,
              timeLimit: Duration(seconds: 5),
            ),
          );
        lat = position.latitude;
        lng = position.longitude;
        debugPrint('Fetched location: $lat, $lng');
      }

      // Persist coords for native alarm scheduler (Flutter stores doubles as raw long bits).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latitude', lat);
      await prefs.setDouble('longitude', lng);
      debugPrint('Saved coords to SharedPreferences for native scheduling: $lat, $lng');

      // The native alarm scheduler only exists on Android.
      if (!Platform.isAndroid) {
        await rescheduleIosPrayerNotifications(latitude: lat, longitude: lng);
        return;
      }

      // Instead of scheduling all, ask native to schedule the single next alarm
      // Native uses stored prefs (lat/lng/method) to compute next prayer.
      try {
        await platform.invokeMethod('scheduleNextPrayer');
        debugPrint('✅ Requested native scheduleNextPrayer');
      } catch (e) {
        debugPrint('❌ Error requesting native scheduleNextPrayer: $e');
      }

      debugPrint('Requested scheduling of next prayer (single alarm)');
    } catch (e) {
      debugPrint('Error scheduling all prayers: $e');
    }
  }

  Future<void> rescheduleIosPrayerNotifications({
    required double latitude,
    required double longitude,
  }) async {
    final pending = _darwinScheduleTail.then(
      (_) => _scheduleDarwinPrayerNotifications(latitude, longitude),
    );
    _darwinScheduleTail = pending.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        debugPrint('Error rescheduling iOS prayer notifications: $error');
      },
    );
    await pending;
  }

  /// Returns the bundled iOS notification sound (ios/Runner/*.caf, max 30s)
  /// for the user's selected adhan. Null means the default system sound,
  /// and an empty string means silent.
  Future<String?> _darwinAdhanSound(String prayerName) async {
    if (!await _soundService.getSoundEnabled(prayerName)) return '';
    switch (await _soundService.getPrayerSoundMode(prayerName)) {
      case PrayerSoundMode.defaultTone:
        return null;
      case PrayerSoundMode.silent:
        return '';
      case PrayerSoundMode.adhan:
        final selected = await _soundService.getSelectedAdhan();
        final adhan = selected == 'Silent'
            ? AdhanSoundService.defaultNonFajrAdhan
            : selected;
        final clip = _soundService.darwinAdhanClip(adhan);
        if (clip == null) {
          throw StateError('No iOS notification sound for $adhan');
        }
        return clip;
    }
  }

  DarwinNotificationDetails _darwinPrayerDetails(String? sound) => DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentList: true,
        presentBadge: true,
        presentSound: sound != '',
        sound: (sound == null || sound.isEmpty) ? null : sound,
      );

  String _soundPayload(String? sound) =>
      sound == null ? 'defaultTone' : (sound.isEmpty ? 'silent' : 'adhan');

  static const int _darwinPrayerIdBase = 2000;
  static const int _darwinScheduleDays = 7;
  static const List<String> _darwinPrayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  /// Schedules the upcoming week of prayer notifications. iOS caps pending
  /// notifications at 64, so this stays at 35 to leave room for reminders.
  Future<void> _scheduleDarwinPrayerNotifications(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final params = await _getCalculationParams();
    final coordinates = Coordinates(lat, lng);
    final now = DateTime.now();

    for (var day = 0; day < _darwinScheduleDays; day++) {
      for (var i = 0; i < _darwinPrayerNames.length; i++) {
        await _notifications.cancel(id: _darwinPrayerIdBase + day * 10 + i);
      }
    }

    final useAlarms = await _iosAlarmsAuthorized();
    if (useAlarms) {
      await _iosAlarmChannel.invokeMethod('cancelAll');
    }

    // One extra day so the last Isha has a following prayer for the snooze payload.
    final upcoming = <({int day, int index, DateTime time})>[];
    for (var day = 0; day <= _darwinScheduleDays; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      final times = PrayerTimes(coordinates, DateComponents.from(date), params);
      final prayerTimes = [times.fajr, times.dhuhr, times.asr, times.maghrib, times.isha];
      for (var i = 0; i < prayerTimes.length; i++) {
        upcoming.add((day: day, index: i, time: prayerTimes[i].toLocal()));
      }
    }

    var scheduledCount = 0;
    var alarmCount = 0;
    String? nextAlertLabel;
    for (var n = 0; n < upcoming.length - 1; n++) {
      final entry = upcoming[n];
      if (entry.day >= _darwinScheduleDays) break;

      final name = _darwinPrayerNames[entry.index];
      if (!(prefs.getBool('prayer_enabled_$name') ?? true)) continue;

      final days = prefs.getStringList('prayer_days_$name');
      if (days != null && days.length == 7 && days[entry.time.weekday % 7] != 'true') {
        continue;
      }

      final offset = prefs.getInt('prayer_offset_$name') ?? 0;
      final notifyAt = entry.time.subtract(Duration(minutes: offset));
      if (!notifyAt.isAfter(now)) continue;

      final title = 'Time for $name Prayer';
      final body = offset > 0
          ? '$name prayer begins in $offset minutes'
          : 'It\'s time to pray $name';
      final sound = await _darwinAdhanSound(name);

      if (useAlarms && sound != null && sound != '' &&
          await _scheduleIosAlarm(name, offset > 0 ? body : title, notifyAt, sound)) {
        alarmCount++;
        nextAlertLabel ??= '$name (alarm) at $notifyAt';
        continue;
      }

      await _notifications.zonedSchedule(
        id: _darwinPrayerIdBase + entry.day * 10 + entry.index,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(notifyAt, tz.local),
        notificationDetails: NotificationDetails(iOS: _darwinPrayerDetails(sound)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '$name|${upcoming[n + 1].time.millisecondsSinceEpoch}|${_soundPayload(sound)}');
      scheduledCount++;
      nextAlertLabel ??= '$name (notification) at $notifyAt';
    }

    debugPrint('✅ Scheduled $alarmCount iOS alarms and $scheduledCount iOS prayer notifications');
    debugPrint('⏰ Next iOS prayer alert: ${nextAlertLabel ?? 'none scheduled'}');
    await debugPrintPendingNotifications();
  }
}
