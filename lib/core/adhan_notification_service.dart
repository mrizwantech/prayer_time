import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
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

  bool get isAdhanPlayerActive => _isAdhanPlayerActive;
  bool get hasPendingAdhanLaunch => _pendingAdhanLaunch != null;
  
  static const platform = MethodChannel('com.mrizwantech.azanify/adhan_alarm');
  
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
    
    // For iOS, permissions are requested during initialization
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
      // Schedule Android alarm. For test button (prayerName == 'Test'), schedule at the provided time.
      // For normal prayers, rely on native single-next chaining for reliability.
      if (shouldPlaySound) {
        try {
          final selectedAdhan = await _soundService.getSelectedAdhan();
          if (prayerName.toLowerCase() == 'test') {
            await platform.invokeMethod('scheduleAdhanAlarm', {
              'prayerName': prayerName,
              'soundFile': selectedAdhan,
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
      910, // dedicated id for Tahajjud
      title,
      body,
      scheduledTime,
      NotificationDetails(
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
      payload: 'Tahajjud',
    );
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
        id,
        'Suhoor reminder',
        'Wrap up suhoor before Fajr.',
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
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'Suhoor',
      );
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
      940, // dedicated id for iftar alert
      'Iftar dua',
      'Allahumma inni laka sumtu wa bika aamantu wa alayka tawakkaltu wa ala rizqika aftartu.',
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
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'Iftar',
    );
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
      941, // dedicated id for suhoor dua
      'Suhoor dua',
      'Wa bisawmi ghadin nawaitu min shahri Ramadan.',
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
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'SuhoorDua',
    );
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
      911, // dedicated id for Taraweeh
      'Taraweeh time',
      'Let\'s begin Taraweeh after Isha.',
      scheduledTime,
      NotificationDetails(
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
      payload: 'Taraweeh',
    );
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
        if (position == null) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.lowest,
              timeLimit: Duration(seconds: 5),
            ),
          );
        }
        lat = position.latitude;
        lng = position.longitude;
        debugPrint('Fetched location: $lat, $lng');
      }

      // Persist coords for native alarm scheduler (Flutter stores doubles as raw long bits).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('latitude', lat);
      await prefs.setDouble('longitude', lng);
      debugPrint('Saved coords to SharedPreferences for native scheduling: $lat, $lng');

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
}
