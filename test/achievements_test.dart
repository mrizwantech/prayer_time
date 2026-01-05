import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_prayer_times/core/achievements.dart';
import 'package:flutter/material.dart';

void main() {
  group('Achievement Tests', () {
    test('All achievements are defined', () {
      expect(Achievements.all.length, 3);
    });

    test('Week Warrior achievement has correct properties', () {
      final weekWarrior = Achievements.all[0];
      
      expect(weekWarrior.id, '7_day_streak');
      expect(weekWarrior.title, 'Week Warrior');
      expect(weekWarrior.requiredStreak, 7);
      expect(weekWarrior.icon, Icons.star);
      expect(weekWarrior.color, const Color(0xFFFFD700));
    });

    test('Monthly Master achievement has correct properties', () {
      final monthlyMaster = Achievements.all[1];
      
      expect(monthlyMaster.id, '30_day_streak');
      expect(monthlyMaster.title, 'Monthly Master');
      expect(monthlyMaster.requiredStreak, 30);
      expect(monthlyMaster.icon, Icons.emoji_events);
    });

    test('Century Champion achievement has correct properties', () {
      final centuryChampion = Achievements.all[2];
      
      expect(centuryChampion.id, '100_day_streak');
      expect(centuryChampion.title, 'Century Champion');
      expect(centuryChampion.requiredStreak, 100);
      expect(centuryChampion.icon, Icons.military_tech);
    });

    test('Get achievement by ID returns correct achievement', () {
      final achievement = Achievements.getById('7_day_streak');
      
      expect(achievement, isNotNull);
      expect(achievement!.title, 'Week Warrior');
    });

    test('Get achievement by invalid ID returns null', () {
      final achievement = Achievements.getById('invalid_id');
      
      expect(achievement, isNull);
    });

    test('All achievements have unique IDs', () {
      final ids = Achievements.all.map((a) => a.id).toList();
      final uniqueIds = ids.toSet();
      
      expect(ids.length, uniqueIds.length);
    });

    test('Achievements are ordered by difficulty', () {
      expect(Achievements.all[0].requiredStreak, 7);
      expect(Achievements.all[1].requiredStreak, 30);
      expect(Achievements.all[2].requiredStreak, 100);
      
      // Verify ascending order
      for (int i = 0; i < Achievements.all.length - 1; i++) {
        expect(
          Achievements.all[i].requiredStreak < Achievements.all[i + 1].requiredStreak,
          true,
        );
      }
    });
  });
}
