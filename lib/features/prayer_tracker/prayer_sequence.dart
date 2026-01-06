import 'prayer_position.dart';

/// Represents one step in a prayer sequence
class PrayerStep {
  final PrayerPosition position;
  final Duration minDuration; // Minimum time to hold position
  final String description;

  const PrayerStep({
    required this.position,
    this.minDuration = const Duration(seconds: 2),
    this.description = '',
  });
}

/// Complete prayer sequence for each Salah
class PrayerSequence {
  final String prayerName;
  final int rakats;
  final List<PrayerStep> steps;

  const PrayerSequence({
    required this.prayerName,
    required this.rakats,
    required this.steps,
  });

  /// Get expected position at a given step index
  PrayerPosition getExpectedPosition(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= steps.length) {
      return PrayerPosition.unknown;
    }
    return steps[stepIndex].position;
  }

  /// Check if a step is a critical one (Sajda)
  bool isCriticalStep(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= steps.length) return false;
    return steps[stepIndex].position == PrayerPosition.prostration;
  }
}

/// Predefined prayer sequences
class PrayerSequences {
  /// Fajr - 2 Rakats
  static const fajr = PrayerSequence(
    prayerName: 'Fajr',
    rakats: 2,
    steps: [
      // Rakat 1
      PrayerStep(position: PrayerPosition.standing, description: 'Takbeer & Qiyam'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 1'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 1'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 1'),
      
      // Rakat 2
      PrayerStep(position: PrayerPosition.standing, description: 'Qiyam 2'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 2'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 2'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 2'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Final Tashahhud'),
    ],
  );

  /// Dhuhr - 4 Rakats
  static const dhuhr = PrayerSequence(
    prayerName: 'Dhuhr',
    rakats: 4,
    steps: [
      // Rakat 1
      PrayerStep(position: PrayerPosition.standing, description: 'Takbeer & Qiyam'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 1'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 1'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 1'),
      
      // Rakat 2
      PrayerStep(position: PrayerPosition.standing, description: 'Qiyam 2'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 2'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 2'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 2'),
      PrayerStep(position: PrayerPosition.sitting, description: 'First Tashahhud'),
      
      // Rakat 3
      PrayerStep(position: PrayerPosition.standing, description: 'Qiyam 3'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 3'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 3'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 3'),
      
      // Rakat 4
      PrayerStep(position: PrayerPosition.standing, description: 'Qiyam 4'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 4'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 4'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 4'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Final Tashahhud'),
    ],
  );

  /// Asr - 4 Rakats (same as Dhuhr)
  static final asr = PrayerSequence(
    prayerName: 'Asr',
    rakats: 4,
    steps: dhuhr.steps,
  );

  /// Maghrib - 3 Rakats
  static const maghrib = PrayerSequence(
    prayerName: 'Maghrib',
    rakats: 3,
    steps: [
      // Rakat 1
      PrayerStep(position: PrayerPosition.standing, description: 'Takbeer & Qiyam'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 1'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 1'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 1'),
      
      // Rakat 2
      PrayerStep(position: PrayerPosition.standing, description: 'Qiyam 2'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 2'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 2'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 2'),
      PrayerStep(position: PrayerPosition.sitting, description: 'First Tashahhud'),
      
      // Rakat 3
      PrayerStep(position: PrayerPosition.standing, description: 'Qiyam 3'),
      PrayerStep(position: PrayerPosition.bowing, description: 'Ruku 3'),
      PrayerStep(position: PrayerPosition.standing, description: 'Rise from Ruku'),
      PrayerStep(position: PrayerPosition.prostration, description: 'First Sajda 3'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Jalsa'),
      PrayerStep(position: PrayerPosition.prostration, description: 'Second Sajda 3'),
      PrayerStep(position: PrayerPosition.sitting, description: 'Final Tashahhud'),
    ],
  );

  /// Isha - 4 Rakats (same as Dhuhr/Asr)
  static final isha = PrayerSequence(
    prayerName: 'Isha',
    rakats: 4,
    steps: dhuhr.steps,
  );

  /// Get sequence for a prayer name
  static PrayerSequence? getSequence(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return fajr;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isha':
        return isha;
      default:
        return null;
    }
  }
}
