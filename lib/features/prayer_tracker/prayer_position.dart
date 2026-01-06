/// Prayer positions that can be detected during Salah
enum PrayerPosition {
  standing,    // Qiyam
  bowing,      // Ruku
  prostration, // Sajda
  sitting,     // Jalsa/Tashahhud
  transitioning, // Moving between positions
  unknown
}

/// Extension to get readable names
extension PrayerPositionName on PrayerPosition {
  String get displayName {
    switch (this) {
      case PrayerPosition.standing:
        return 'Standing (Qiyam)';
      case PrayerPosition.bowing:
        return 'Bowing (Ruku)';
      case PrayerPosition.prostration:
        return 'Prostration (Sajda)';
      case PrayerPosition.sitting:
        return 'Sitting';
      case PrayerPosition.transitioning:
        return 'Transitioning';
      case PrayerPosition.unknown:
        return 'Unknown';
    }
  }

  String get shortName {
    switch (this) {
      case PrayerPosition.standing:
        return 'Qiyam';
      case PrayerPosition.bowing:
        return 'Ruku';
      case PrayerPosition.prostration:
        return 'Sajda';
      case PrayerPosition.sitting:
        return 'Sitting';
      case PrayerPosition.transitioning:
        return 'Moving';
      case PrayerPosition.unknown:
        return 'Unknown';
    }
  }
}
