import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:islamic_prayer_times/core/prayer_tracking_service.dart';

void main() {
  late PrayerTrackingService service;

  setUp(() {
    service = PrayerTrackingService();
  });

  group('Prayer Completion Tests', () {
    test('Mark prayer as complete saves correctly', () async {
      SharedPreferences.setMockInitialValues({});
      
      final today = DateTime.now();
      await service.markPrayerComplete('Fajr', today);
      
      final completions = await service.getPrayerCompletions(today);
      expect(completions['Fajr'], true);
      expect(completions['Dhuhr'], false);
    });

    test('Unmark prayer removes completion', () async {
      SharedPreferences.setMockInitialValues({});
      
      final today = DateTime.now();
      await service.markPrayerComplete('Fajr', today);
      await service.unmarkPrayerComplete('Fajr', today);
      
      final completions = await service.getPrayerCompletions(today);
      expect(completions['Fajr'], false);
    });

    test('Get completions for new day returns all false', () async {
      SharedPreferences.setMockInitialValues({});
      
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final completions = await service.getPrayerCompletions(tomorrow);
      
      expect(completions.length, 5);
      expect(completions.values.every((v) => v == false), true);
    });
  });

  group('Streak Calculation Tests', () {
    test('Empty data returns 0 streak', () async {
      SharedPreferences.setMockInitialValues({});
      
      final streak = await service.getCurrentStreak();
      expect(streak, 0);
    });

    test('Single complete day returns streak of 1', () async {
      SharedPreferences.setMockInitialValues({});
      
      final today = DateTime.now();
      await service.markPrayerComplete('Fajr', today);
      await service.markPrayerComplete('Dhuhr', today);
      await service.markPrayerComplete('Asr', today);
      await service.markPrayerComplete('Maghrib', today);
      await service.markPrayerComplete('Isha', today);
      
      final streak = await service.getCurrentStreak();
      expect(streak, 1);
    });

    test('Incomplete day breaks streak', () async {
      SharedPreferences.setMockInitialValues({});
      
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      
      // Complete yesterday
      await service.markPrayerComplete('Fajr', yesterday);
      await service.markPrayerComplete('Dhuhr', yesterday);
      await service.markPrayerComplete('Asr', yesterday);
      await service.markPrayerComplete('Maghrib', yesterday);
      await service.markPrayerComplete('Isha', yesterday);
      
      // Partially complete today (breaks streak)
      await service.markPrayerComplete('Fajr', today);
      await service.markPrayerComplete('Dhuhr', today);
      
      final streak = await service.getCurrentStreak();
      expect(streak, 0);
    });
  });

  group('Badge Unlock Tests', () {
    test('7-day streak unlocks Week Warrior badge', () async {
      SharedPreferences.setMockInitialValues({});
      
      // Complete prayers for 7 consecutive days
      for (int i = 0; i < 7; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        await service.markPrayerComplete('Fajr', date);
        await service.markPrayerComplete('Dhuhr', date);
        await service.markPrayerComplete('Asr', date);
        await service.markPrayerComplete('Maghrib', date);
        await service.markPrayerComplete('Isha', date);
      }
      
      final badges = await service.getUnlockedBadges();
      expect(badges.contains('7_day_streak'), true);
    });

    test('30-day streak unlocks Monthly Master badge', () async {
      SharedPreferences.setMockInitialValues({});
      
      // Complete prayers for 30 consecutive days
      for (int i = 0; i < 30; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        await service.markPrayerComplete('Fajr', date);
        await service.markPrayerComplete('Dhuhr', date);
        await service.markPrayerComplete('Asr', date);
        await service.markPrayerComplete('Maghrib', date);
        await service.markPrayerComplete('Isha', date);
      }
      
      final badges = await service.getUnlockedBadges();
      expect(badges.contains('7_day_streak'), true);
      expect(badges.contains('30_day_streak'), true);
    });

    test('Badges persist after app restart', () async {
      SharedPreferences.setMockInitialValues({
        'unlocked_badges': ['7_day_streak', '30_day_streak'],
      });
      
      final badges = await service.getUnlockedBadges();
      expect(badges.length, 2);
      expect(badges.contains('7_day_streak'), true);
      expect(badges.contains('30_day_streak'), true);
    });
  });

  group('Monthly Completion Tests', () {
    test('No completions returns 0%', () async {
      SharedPreferences.setMockInitialValues({});
      
      final percentage = await service.getMonthlyCompletionPercentage();
      expect(percentage, 0.0);
    });

    test('All prayers completed returns 100%', () async {
      SharedPreferences.setMockInitialValues({});
      
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      
      // Complete all prayers for every day up to today
      for (int day = 1; day <= now.day; day++) {
        final date = DateTime(now.year, now.month, day);
        await service.markPrayerComplete('Fajr', date);
        await service.markPrayerComplete('Dhuhr', date);
        await service.markPrayerComplete('Asr', date);
        await service.markPrayerComplete('Maghrib', date);
        await service.markPrayerComplete('Isha', date);
      }
      
      final percentage = await service.getMonthlyCompletionPercentage();
      expect(percentage, 100.0);
    });

    test('Partial completions return correct percentage', () async {
      SharedPreferences.setMockInitialValues({});
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Complete 3 out of 5 prayers for 4 days
      for (int day = 1; day <= 4; day++) {
        final date = DateTime(now.year, now.month, day);
        await service.markPrayerComplete('Fajr', date);
        await service.markPrayerComplete('Dhuhr', date);
        await service.markPrayerComplete('Asr', date);
      }
      
      final percentage = await service.getMonthlyCompletionPercentage();
      // 4 days * 3 completed = 12 completed out of 4 days * 5 prayers = 20 total
      // 12/20 = 60%
      expect(percentage, 60.0);
    });
  });

  group('Data Persistence Tests', () {
    test('Prayer completions persist across sessions', () async {
      SharedPreferences.setMockInitialValues({});
      
      final today = DateTime.now();
      await service.markPrayerComplete('Fajr', today);
      await service.markPrayerComplete('Dhuhr', today);
      
      // Create new service instance (simulating app restart)
      final newService = PrayerTrackingService();
      final completions = await newService.getPrayerCompletions(today);
      
      expect(completions['Fajr'], true);
      expect(completions['Dhuhr'], true);
      expect(completions['Asr'], false);
    });
  });
}
