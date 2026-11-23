import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_prayer_times/core/adhan_notification_service.dart';
import 'package:islamic_prayer_times/core/adhan_sound_service.dart';
import 'package:islamic_prayer_times/core/prayer_time_service.dart';
import 'package:islamic_prayer_times/screens/adhan_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Fajr is visible and its notification setting is saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PrayerTimeService(),
        child: MaterialApp(
          home: AdhanSettingsScreen(
            prayerTimes: {'Fajr': DateTime(2026, 1, 1, 5)},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fajr'), findsOneWidget);
    final fajrCard = find
        .ancestor(of: find.text('Fajr'), matching: find.byType(Row))
        .last;
    await tester.tap(
      find
          .descendant(of: fajrCard, matching: find.byType(GestureDetector))
          .last,
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('prayer_enabled_Fajr'), isFalse);
  });

  testWidgets('sound choices are saved separately for each prayer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PrayerTimeService(),
        child: MaterialApp(
          home: AdhanSettingsScreen(
            prayerTimes: {
              'Fajr': DateTime(2026, 1, 1, 5),
              'Dhuhr': DateTime(2026, 1, 1, 12),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sound_mode_Fajr')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silent').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('prayer_sound_mode_Fajr'), 'silent');
    expect(prefs.getString('prayer_sound_mode_Dhuhr'), 'adhan');
  });

  test('legacy silent selection is preserved per prayer', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({'selected_adhan': 'Silent'});
    final service = AdhanSoundService();
    expect(await service.getPrayerSoundMode('Fajr'), PrayerSoundMode.adhan);
    expect(await service.getPrayerSoundMode('Dhuhr'), PrayerSoundMode.silent);
    await service.setPrayerSoundMode('Fajr', PrayerSoundMode.defaultTone);
    expect(
      await service.getPrayerSoundMode('Fajr'),
      PrayerSoundMode.defaultTone,
    );
  });

  test(
    'adhan volume is saved and constrained to the supported range',
    () async {
      SharedPreferences.setMockInitialValues({});
      final service = AdhanSoundService();
      await service.setAdhanVolume(0.35);
      expect(await service.getAdhanVolume(), 0.35);
      await service.setAdhanVolume(-0.5);
      expect(await service.getAdhanVolume(), 0);
      await service.setAdhanVolume(2);
      expect(await service.getAdhanVolume(), 1);
    },
  );

  test(
    'iOS scheduling respects Fajr enabled state and selected days',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      IOSFlutterLocalNotificationsPlugin.registerWith();
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.UTC);
      SharedPreferences.setMockInitialValues({'prayer_enabled_Fajr': false});

      final scheduled = <Map<Object?, Object?>>[];
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'zonedSchedule') {
          scheduled.add(Map<Object?, Object?>.from(call.arguments as Map));
        }
        if (call.method == 'pendingNotificationRequests') return <Object>[];
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final service = AdhanNotificationService();
      Future<void> schedule() => service.scheduleAllPrayersForToday(
        latitude: 40.7128,
        longitude: -74.0060,
      );
      bool isFajr(Map<Object?, Object?> item) =>
          item['title'] == 'Time for Fajr Prayer';

      await schedule();
      expect(scheduled.where(isFajr), isEmpty);
      expect(scheduled, isNotEmpty);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prayer_enabled_Fajr', true);
      await prefs.setStringList('prayer_days_Fajr', List.filled(7, 'false'));
      scheduled.clear();
      await schedule();
      expect(scheduled.where(isFajr), isEmpty);

      await prefs.setStringList('prayer_days_Fajr', List.filled(7, 'true'));
      scheduled.clear();
      await schedule();
      final baseline = {
        for (final item in scheduled.where(isFajr))
          item['id']: DateTime.parse(item['scheduledDateTime'] as String),
      };
      expect(baseline, isNotEmpty);

      await prefs.setInt('prayer_offset_Fajr', 15);
      scheduled.clear();
      await schedule();
      final fajr = scheduled.where(isFajr);
      expect(fajr, isNotEmpty);
      expect(
        fajr.every(
          (item) => item['body'] == 'Fajr prayer begins in 15 minutes',
        ),
        isTrue,
      );
      final comparable = fajr.where((item) => baseline.containsKey(item['id']));
      expect(comparable, isNotEmpty);
      for (final item in comparable) {
        expect(
          baseline[item['id']]!.difference(
            DateTime.parse(item['scheduledDateTime'] as String),
          ),
          const Duration(minutes: 15),
        );
      }

      await prefs.setString('prayer_sound_mode_Fajr', 'adhan');
      await prefs.setString('prayer_sound_mode_Dhuhr', 'defaultTone');
      await prefs.setString('prayer_sound_mode_Asr', 'silent');
      scheduled.clear();
      await schedule();
      Map<Object?, Object?> detailsFor(String name) {
        final item = scheduled.firstWhere(
          (item) => item['title'] == 'Time for $name Prayer',
        );
        return Map<Object?, Object?>.from(item['platformSpecifics'] as Map);
      }

      expect(detailsFor('Fajr')['sound'], 'adhan_rabeh.caf');
      expect(detailsFor('Fajr')['presentSound'], isTrue);
      expect(detailsFor('Dhuhr')['sound'], isNull);
      expect(detailsFor('Dhuhr')['presentSound'], isTrue);
      expect(detailsFor('Asr')['presentSound'], isFalse);
      expect(scheduled.firstWhere(isFajr)['payload'], endsWith('|adhan'));
      expect(
        scheduled.firstWhere(
          (item) => item['title'] == 'Time for Asr Prayer',
        )['payload'],
        endsWith('|silent'),
      );
    },
  );
}
