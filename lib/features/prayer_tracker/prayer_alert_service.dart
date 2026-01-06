import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Alert types for prayer tracking
enum AlertType {
  missedPosition,    // Skipped a required position
  wrongSequence,     // Did positions out of order
  incompleteSajda,   // Only did 1 Sajda instead of 2
  prayerComplete,    // Successfully completed prayer
  sajdaSahwNeeded,   // Prostration of forgetfulness needed
}

/// Prayer tracking alert with vibration and optional sound
class PrayerTrackerAlert {
  final AlertType type;
  final String message;
  final String? details;

  const PrayerTrackerAlert({
    required this.type,
    required this.message,
    this.details,
  });
}

/// Service for triggering prayer tracking alerts
class PrayerAlertService {
  static final PrayerAlertService _instance = PrayerAlertService._internal();
  factory PrayerAlertService() => _instance;
  PrayerAlertService._internal();

  bool _isEnabled = true;
  bool _vibrationsEnabled = true;
  bool _soundEnabled = true;

  /// Enable/disable all alerts
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Enable/disable vibrations
  void setVibrationsEnabled(bool enabled) {
    _vibrationsEnabled = enabled;
  }

  /// Enable/disable sound
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  /// Trigger an alert
  Future<void> triggerAlert(PrayerTrackerAlert alert) async {
    if (!_isEnabled) return;

    print('🔔 ALERT: ${alert.type.name} - ${alert.message}');
    if (alert.details != null) {
      print('   Details: ${alert.details}');
    }

    // Trigger vibration based on alert type
    if (_vibrationsEnabled) {
      await _vibrate(alert.type);
    }

    // Play sound (if needed - can add later)
    if (_soundEnabled) {
      await _playSound(alert.type);
    }
  }

  /// Vibration patterns for different alert types
  Future<void> _vibrate(AlertType type) async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) return;

      switch (type) {
        case AlertType.missedPosition:
        case AlertType.incompleteSajda:
          // Double short vibration for missed positions
          await Vibration.vibrate(duration: 200);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 200);
          break;

        case AlertType.wrongSequence:
          // Triple short vibration for wrong sequence
          await Vibration.vibrate(duration: 150);
          await Future.delayed(const Duration(milliseconds: 80));
          await Vibration.vibrate(duration: 150);
          await Future.delayed(const Duration(milliseconds: 80));
          await Vibration.vibrate(duration: 150);
          break;

        case AlertType.sajdaSahwNeeded:
          // Long vibration for Sajda Sahw reminder
          await Vibration.vibrate(duration: 500);
          break;

        case AlertType.prayerComplete:
          // Single gentle vibration for completion
          await Vibration.vibrate(duration: 300);
          break;
      }
    } catch (e) {
      print('Vibration error: $e');
    }
  }

  /// Play sound for alerts (placeholder for future implementation)
  Future<void> _playSound(AlertType type) async {
    // Can implement with audioplayers package later
    // For now, use system sound
    try {
      if (type == AlertType.missedPosition || 
          type == AlertType.incompleteSajda ||
          type == AlertType.wrongSequence) {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (e) {
      print('Sound error: $e');
    }
  }

  /// Create alert for missed Sajda
  static PrayerTrackerAlert missedSajda(int rakatNumber, int sajdaNumber) {
    return PrayerTrackerAlert(
      type: AlertType.missedPosition,
      message: '⚠️ Sajda Missed',
      details: 'Rakat $rakatNumber, Sajda $sajdaNumber was skipped',
    );
  }

  /// Create alert for missed Ruku
  static PrayerTrackerAlert missedRuku(int rakatNumber) {
    return PrayerTrackerAlert(
      type: AlertType.missedPosition,
      message: '⚠️ Ruku Missed',
      details: 'Rakat $rakatNumber Ruku was skipped',
    );
  }

  /// Create alert for wrong sequence
  static PrayerTrackerAlert wrongSequence(String expected, String actual) {
    return PrayerTrackerAlert(
      type: AlertType.wrongSequence,
      message: '⚠️ Wrong Sequence',
      details: 'Expected: $expected, Got: $actual',
    );
  }

  /// Create alert for incomplete Sajda (only did 1 instead of 2)
  static PrayerTrackerAlert incompleteSajda(int rakatNumber) {
    return PrayerTrackerAlert(
      type: AlertType.incompleteSajda,
      message: '⚠️ Second Sajda Needed',
      details: 'Rakat $rakatNumber needs second Sajda',
    );
  }

  /// Create alert for Sajda Sahw needed
  static PrayerTrackerAlert sajdaSahwNeeded(List<String> mistakes) {
    return PrayerTrackerAlert(
      type: AlertType.sajdaSahwNeeded,
      message: '📿 Sajda Sahw Recommended',
      details: 'Mistakes: ${mistakes.join(", ")}',
    );
  }

  /// Create alert for prayer completion
  static PrayerTrackerAlert prayerComplete(String prayerName, bool perfect) {
    return PrayerTrackerAlert(
      type: AlertType.prayerComplete,
      message: perfect ? '✅ Perfect Prayer!' : '✅ Prayer Complete',
      details: '$prayerName completed${perfect ? " with no mistakes" : ""}',
    );
  }
}
