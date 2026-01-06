import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import 'prayer_position.dart';

/// Detects prayer positions using device sensors
class PrayerPositionDetector {
  // Sensor streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  
  // Current detected position
  PrayerPosition _currentPosition = PrayerPosition.unknown;
  PrayerPosition get currentPosition => _currentPosition;
  
  // Position change callback
  void Function(PrayerPosition position)? onPositionChanged;
  
  // Sensor data
  double _pitch = 0.0; // Forward/backward tilt
  double _roll = 0.0;  // Side tilt
  double _verticalAccel = 0.0;
  
  // Thresholds for position detection (can be calibrated)
  // Adjusted for phone-in-pocket usage
  double _standingPitchMin = 0.0;
  double _standingPitchMax = 30.0;
  double _bowingPitchMin = 35.0;
  double _bowingPitchMax = 50.0;
  double _prostrationPitchMin = 50.0;  // Lowered from 70 for pocket use
  double _sittingPitchMin = 25.0;
  double _sittingPitchMax = 40.0;
  
  // Debounce timer to avoid rapid position changes
  Timer? _debounceTimer;
  PrayerPosition? _pendingPosition;
  static const Duration _debounceDuration = Duration(milliseconds: 800);

  PrayerPositionDetector({this.onPositionChanged});

  /// Start detecting positions
  void startDetection() {
    _accelerometerSubscription = accelerometerEventStream().listen(
      _onAccelerometerData,
      onError: (error) => print('Accelerometer error: $error'),
    );

    _gyroscopeSubscription = gyroscopeEventStream().listen(
      _onGyroscopeData,
      onError: (error) => print('Gyroscope error: $error'),
    );
  }

  /// Stop detection and clean up
  void stopDetection() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _debounceTimer?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  /// Process accelerometer data
  void _onAccelerometerData(AccelerometerEvent event) {
    // Calculate pitch (forward/backward tilt) in degrees
    // event.x = left/right, event.y = forward/back, event.z = up/down
    _pitch = _calculatePitch(event.x, event.y, event.z);
    _roll = _calculateRoll(event.x, event.y, event.z);
    _verticalAccel = event.z;
    
    _detectPosition();
  }

  /// Process gyroscope data
  void _onGyroscopeData(GyroscopeEvent event) {
    // Can be used for detecting rapid movements/transitions
    // Currently using accelerometer only for position detection
  }

  /// Calculate pitch angle from accelerometer
  double _calculatePitch(double x, double y, double z) {
    final pitch = math.atan2(-y, math.sqrt(x * x + z * z));
    return pitch * (180.0 / math.pi); // Convert to degrees
  }

  /// Calculate roll angle from accelerometer
  double _calculateRoll(double x, double y, double z) {
    final roll = math.atan2(x, z);
    return roll * (180.0 / math.pi); // Convert to degrees
  }

  /// Detect current prayer position based on sensor data
  void _detectPosition() {
    PrayerPosition newPosition = PrayerPosition.unknown;

    // Use absolute pitch for detection (phone can be oriented either way)
    final absPitch = _pitch.abs();
    final absZ = _verticalAccel.abs();

    // Prostration (Sajda): Very tilted (>70°) or nearly horizontal (low z < 2.5)
    if (absPitch >= _prostrationPitchMin || absZ < 2.5) {
      newPosition = PrayerPosition.prostration;
    }
    // Bowing (Ruku): Tilted forward 45-70°
    else if (absPitch >= _bowingPitchMin && absPitch < _prostrationPitchMin) {
      newPosition = PrayerPosition.bowing;
    }
    // Sitting (Jalsa): Moderate tilt 35-55° with moderate z (not too high)
    else if (absPitch >= _sittingPitchMin && 
             absPitch <= _sittingPitchMax && 
             absZ < 9.0) {
      newPosition = PrayerPosition.sitting;
    }
    // Standing (Qiyam): Low tilt 0-35° (catch-all for upright positions)
    else if (absPitch <= _standingPitchMax) {
      newPosition = PrayerPosition.standing;
    }

    // Debounce position changes to avoid jitter
    if (newPosition != _currentPosition && newPosition != PrayerPosition.unknown) {
      _pendingPosition = newPosition;
      
      print('⏳ Pending position: ${newPosition.shortName} (current: ${_currentPosition.shortName})');
      
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceDuration, () {
        if (_pendingPosition != null && _pendingPosition != _currentPosition) {
          _currentPosition = _pendingPosition!;
          onPositionChanged?.call(_currentPosition);
          print('Position changed to: ${_currentPosition.shortName} (pitch: ${_pitch.toStringAsFixed(1)}°, z: ${_verticalAccel.toStringAsFixed(2)})');
        }
      });
    }
  }

  /// Manually calibrate for current standing position
  void calibrateStanding() {
    final absPitch = _pitch.abs();
    _standingPitchMax = absPitch + 5.0; // Add 5° tolerance
    print('✅ Calibrated standing: pitch=${_pitch.toStringAsFixed(1)}°, max=${_standingPitchMax.toStringAsFixed(1)}°');
    _currentPosition = PrayerPosition.standing;
    onPositionChanged?.call(_currentPosition);
  }

  /// Calibrate ruku (bowing) position
  void calibrateBowing() {
    final absPitch = _pitch.abs();
    _bowingPitchMin = (absPitch - 5.0).clamp(35.0, 90.0);
    _bowingPitchMax = (absPitch + 5.0).clamp(40.0, 90.0);
    print('✅ Calibrated ruku: pitch=${_pitch.toStringAsFixed(1)}°, range=${_bowingPitchMin.toStringAsFixed(1)}-${_bowingPitchMax.toStringAsFixed(1)}°');
    _currentPosition = PrayerPosition.bowing;
    onPositionChanged?.call(_currentPosition);
  }

  /// Calibrate sajda (prostration) position
  void calibrateProstration() {
    final absPitch = _pitch.abs();
    _prostrationPitchMin = (absPitch - 5.0).clamp(60.0, 90.0);
    print('✅ Calibrated sajda: pitch=${_pitch.toStringAsFixed(1)}°, min=${_prostrationPitchMin.toStringAsFixed(1)}°');
    _currentPosition = PrayerPosition.prostration;
    onPositionChanged?.call(_currentPosition);
  }

  /// Calibrate sitting position
  void calibrateSitting() {
    final absPitch = _pitch.abs();
    _sittingPitchMin = (absPitch - 5.0).clamp(25.0, 50.0);
    _sittingPitchMax = (absPitch + 5.0).clamp(30.0, 65.0);
    print('✅ Calibrated sitting: pitch=${_pitch.toStringAsFixed(1)}°, range=${_sittingPitchMin.toStringAsFixed(1)}-${_sittingPitchMax.toStringAsFixed(1)}°');
    _currentPosition = PrayerPosition.sitting;
    onPositionChanged?.call(_currentPosition);
  }

  /// Reset to default thresholds
  void resetCalibration() {
    _standingPitchMin = 0.0;
    _standingPitchMax = 35.0;
    _bowingPitchMin = 45.0;
    _bowingPitchMax = 75.0;
    _prostrationPitchMin = 70.0;
    _sittingPitchMin = 35.0;
    _sittingPitchMax = 55.0;
    print('🔄 Reset to default calibration');
  }

  /// Get current sensor readings for debugging
  Map<String, double> getSensorReadings() {
    return {
      'pitch': _pitch,
      'roll': _roll,
      'verticalAccel': _verticalAccel,
    };
  }
}
