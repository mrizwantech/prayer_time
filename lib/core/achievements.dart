import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int requiredStreak;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.requiredStreak,
  });
}

class Achievements {
  static const List<Achievement> all = [
    Achievement(
      id: '7_day_streak',
      title: 'Week Warrior',
      description: 'Complete all prayers for 7 consecutive days',
      icon: Icons.star,
      color: Color(0xFFFFD700), // Gold
      requiredStreak: 7,
    ),
    Achievement(
      id: '30_day_streak',
      title: 'Monthly Master',
      description: 'Complete all prayers for 30 consecutive days',
      icon: Icons.emoji_events,
      color: Color(0xFFC0C0C0), // Silver
      requiredStreak: 30,
    ),
    Achievement(
      id: '100_day_streak',
      title: 'Century Champion',
      description: 'Complete all prayers for 100 consecutive days',
      icon: Icons.military_tech,
      color: Color(0xFFCD7F32), // Bronze
      requiredStreak: 100,
    ),
  ];

  static Achievement? getById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }
}
