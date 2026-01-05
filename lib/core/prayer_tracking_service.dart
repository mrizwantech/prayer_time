import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/prayer_completion_model.dart';

class PrayerTrackingService {
  static const String _keyPrefix = 'prayer_completions_';
  static const String _streakKey = 'current_streak';
  static const String _badgesKey = 'unlocked_badges';

  Future<void> markPrayerComplete(String prayerName, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getDateKey(date);
    
    // Get existing data for the day
    final existing = await getPrayerCompletions(date);
    existing[prayerName] = true;
    
    // Save updated data
    final model = PrayerCompletionModel(
      dateString: dateKey,
      prayers: existing,
    );
    await prefs.setString('$_keyPrefix$dateKey', jsonEncode(model.toJson()));
    
    // Update streak
    await _updateStreak();
  }

  Future<void> unmarkPrayerComplete(String prayerName, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getDateKey(date);
    
    final existing = await getPrayerCompletions(date);
    existing[prayerName] = false;
    
    final model = PrayerCompletionModel(
      dateString: dateKey,
      prayers: existing,
    );
    await prefs.setString('$_keyPrefix$dateKey', jsonEncode(model.toJson()));
    
    await _updateStreak();
  }

  Future<Map<String, bool>> getPrayerCompletions(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = _getDateKey(date);
    final data = prefs.getString('$_keyPrefix$dateKey');
    
    if (data == null) {
      return {
        'Fajr': false,
        'Dhuhr': false,
        'Asr': false,
        'Maghrib': false,
        'Isha': false,
      };
    }
    
    final model = PrayerCompletionModel.fromJson(jsonDecode(data));
    return model.prayers;
  }

  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }

  Future<List<String>> getUnlockedBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_badgesKey);
    return data ?? [];
  }

  Future<void> _unlockBadge(String badgeName) async {
    final prefs = await SharedPreferences.getInstance();
    final badges = await getUnlockedBadges();
    if (!badges.contains(badgeName)) {
      badges.add(badgeName);
      await prefs.setStringList(_badgesKey, badges);
    }
  }

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    int streak = 0;
    
    // Count backwards from today
    for (int i = 0; i < 365; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final completions = await getPrayerCompletions(checkDate);
      final isComplete = completions.values.every((v) => v);
      
      if (isComplete) {
        streak++;
      } else {
        break;
      }
    }
    
    await prefs.setInt(_streakKey, streak);
    
    // Check for badge unlocks
    if (streak >= 7) await _unlockBadge('7_day_streak');
    if (streak >= 30) await _unlockBadge('30_day_streak');
    if (streak >= 100) await _unlockBadge('100_day_streak');
  }

  Future<double> getMonthlyCompletionPercentage() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    int totalPrayers = 0;
    int completedPrayers = 0;
    
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final date = DateTime(now.year, now.month, day);
      if (date.isAfter(now)) break;
      
      final completions = await getPrayerCompletions(date);
      totalPrayers += 5; // 5 prayers per day
      completedPrayers += completions.values.where((v) => v).length;
    }
    
    return totalPrayers > 0 ? (completedPrayers / totalPrayers) * 100 : 0;
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
