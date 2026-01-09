import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/prayer_tracking_service.dart';
import '../../core/achievements.dart';
import '../../core/prayer_theme_provider.dart';
import 'package:provider/provider.dart';

class StreakTrackerWidget extends StatefulWidget {
  const StreakTrackerWidget({Key? key}) : super(key: key);

  @override
  State<StreakTrackerWidget> createState() => _StreakTrackerWidgetState();
}

class _StreakTrackerWidgetState extends State<StreakTrackerWidget> {
  final _trackingService = PrayerTrackingService();
  int _currentStreak = 0;
  double _monthlyCompletion = 0;
  List<String> _unlockedBadges = [];
  Map<String, bool> _todayPrayers = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _loadData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final streak = await _trackingService.getCurrentStreak();
    final monthly = await _trackingService.getMonthlyCompletionPercentage();
    final badges = await _trackingService.getUnlockedBadges();
    final today = await _trackingService.getPrayerCompletions(DateTime.now());

    if (mounted) {
      setState(() {
        _currentStreak = streak;
        _monthlyCompletion = monthly;
        _unlockedBadges = badges;
        _todayPrayers = today;
      });
    }
  }

  Future<void> _togglePrayer(String prayerName, bool isCompleted) async {
    if (isCompleted) {
      await _trackingService.unmarkPrayerComplete(prayerName, DateTime.now());
    } else {
      await _trackingService.markPrayerComplete(prayerName, DateTime.now());
    }
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<PrayerThemeProvider>(context);
    final currentTheme = themeProvider.getCurrentTheme('Fajr'); // Default theme

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: currentTheme.backgroundGradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 60,
                    color: _currentStreak > 0 ? Colors.orange : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_currentStreak Day Streak',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: currentTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep going! 🌟',
                    style: TextStyle(
                      fontSize: 16,
                      color: currentTheme.textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monthly Completion
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'This Month',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: currentTheme.textColor,
                        ),
                      ),
                      Text(
                        '${_monthlyCompletion.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: currentTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _monthlyCompletion / 100,
                      minHeight: 12,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation(currentTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Today's Prayers
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Prayers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: currentTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._todayPrayers.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Checkbox(
                            value: entry.value,
                            onChanged: (bool? value) {
                              _togglePrayer(entry.key, entry.value);
                            },
                            activeColor: currentTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 16,
                              color: currentTheme.textColor,
                              decoration: entry.value ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Achievements
            Text(
              'Achievements',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: currentTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: Achievements.all.map((achievement) {
                final isUnlocked = _unlockedBadges.contains(achievement.id);
                return Container(
                  width: 100,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? achievement.color.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUnlocked ? achievement.color : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        achievement.icon,
                        size: 40,
                        color: isUnlocked ? achievement.color : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? currentTheme.textColor : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${achievement.requiredStreak} days',
                        style: TextStyle(
                          fontSize: 10,
                          color: isUnlocked
                              ? currentTheme.textColor.withOpacity(0.7)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
