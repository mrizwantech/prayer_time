import 'dart:async';
import 'prayer_position.dart';
import 'prayer_position_detector.dart';
import 'prayer_sequence.dart';
import 'prayer_alert_service.dart';

/// Tracking state for prayer
enum PrayerTrackingState {
  idle,
  ready,
  tracking,
  paused,
  completed,
}

/// Mistake record for post-prayer summary
class PrayerMistake {
  final int stepIndex;
  final String description;
  final DateTime timestamp;

  PrayerMistake({
    required this.stepIndex,
    required this.description,
    required this.timestamp,
  });
}

/// Main service for tracking prayer movements and validating sequence
class PrayerTrackerService {
  final PrayerPositionDetector _positionDetector;
  final PrayerAlertService _alertService = PrayerAlertService();
  
  // Current prayer being tracked
  PrayerSequence? _currentSequence;
  PrayerTrackingState _state = PrayerTrackingState.idle;
  
  // Current step in prayer sequence
  int _currentStepIndex = 0;
  DateTime? _stepStartTime;
  
  // Tracking data
  final List<PrayerMistake> _mistakes = [];
  int _sajdaCount = 0; // Count consecutive Sajdas in current set
  PrayerPosition? _lastPosition;
  DateTime? _lastPositionChangeTime;
  bool _positionConfirmed = false;
  bool _stepCompleted = false; // Require position to be held for min duration
  Timer? _positionCheckTimer;
  
  // Callbacks
  final void Function(PrayerTrackingState state)? onStateChanged;
  final void Function(int stepIndex, int totalSteps)? onProgressChanged;
  final void Function(PrayerTrackerAlert alert)? onAlert;
  final void Function(List<PrayerMistake> mistakes, bool needsSajdaSahw)? onPrayerComplete;

  PrayerTrackerService({
    required PrayerPositionDetector positionDetector,
    this.onStateChanged,
    this.onProgressChanged,
    this.onAlert,
    this.onPrayerComplete,
  }) : _positionDetector = positionDetector {
    _positionDetector.onPositionChanged = _onPositionChanged;
  }

  // Getters
  PrayerTrackingState get state => _state;
  PrayerSequence? get currentSequence => _currentSequence;
  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _currentSequence?.steps.length ?? 0;
  List<PrayerMistake> get mistakes => List.unmodifiable(_mistakes);
  PrayerPosition? get currentExpectedPosition => 
      _currentSequence?.getExpectedPosition(_currentStepIndex);

  /// Start tracking a prayer
  void startTracking(String prayerName) {
    _currentSequence = PrayerSequences.getSequence(prayerName);
    if (_currentSequence == null) {
      print('Error: Unknown prayer name: $prayerName');
      return;
    }

    _state = PrayerTrackingState.ready;
    _currentStepIndex = 0;
    _mistakes.clear();
    _sajdaCount = 0;
    _lastPosition = null;
    _stepStartTime = DateTime.now();

    _positionDetector.startDetection();
    onStateChanged?.call(_state);
    onProgressChanged?.call(_currentStepIndex, totalSteps);
    
    print('📿 Started tracking ${_currentSequence!.prayerName} (${_currentSequence!.rakats} rakats, ${totalSteps} steps)');
  }

  /// Begin actual prayer (after Takbeer)
  void beginPrayer() {
    if (_state != PrayerTrackingState.ready) return;
    
    _state = PrayerTrackingState.tracking;
    _stepStartTime = DateTime.now();
    _lastPosition = null;
    _lastPositionChangeTime = null;
    _positionConfirmed = false;
    _stepCompleted = false;
    
    // Start continuous position checking
    _positionCheckTimer?.cancel();
    _positionCheckTimer = Timer.periodic(Duration(milliseconds: 500), (_) => _checkCurrentPosition());
    
    onStateChanged?.call(_state);
    
    print('🕌 Prayer tracking active (Step: $_currentStepIndex/$totalSteps)');
  }

  /// Pause tracking
  void pause() {
    if (_state != PrayerTrackingState.tracking) return;
    
    _state = PrayerTrackingState.paused;
    onStateChanged?.call(_state);
  }

  /// Resume tracking
  void resume() {
    if (_state != PrayerTrackingState.paused) return;
    
    _state = PrayerTrackingState.tracking;
    _stepStartTime = DateTime.now();
    onStateChanged?.call(_state);
  }

  /// Stop tracking and get results
  void stopTracking() {
    _positionCheckTimer?.cancel();
    _positionDetector.stopDetection();
    _state = PrayerTrackingState.idle;
    _currentSequence = null;
    onStateChanged?.call(_state);
  }

  /// Force complete prayer (for manual completion)
  void completePrayer() {
    print('⚠️ completePrayer() called! Stack trace:');
    print(StackTrace.current);
    
    if (_currentSequence == null) return;

    _state = PrayerTrackingState.completed;
    final needsSajdaSahw = _mistakes.length > 2; // More than 2 mistakes needs Sajda Sahw
    
    // Send completion callback
    onPrayerComplete?.call(_mistakes, needsSajdaSahw);
    
    // Send completion alert
    final alert = PrayerAlertService.prayerComplete(
      _currentSequence!.prayerName,
      _mistakes.isEmpty,
    );
    _alertService.triggerAlert(alert);
    onAlert?.call(alert);

    // If mistakes occurred, suggest Sajda Sahw
    if (needsSajdaSahw) {
      final sahwAlert = PrayerAlertService.sajdaSahwNeeded(
        _mistakes.map((m) => m.description).toList(),
      );
      _alertService.triggerAlert(sahwAlert);
      onAlert?.call(sahwAlert);
    }

    onStateChanged?.call(_state);
    print('✅ Prayer completed with ${_mistakes.length} mistake(s)');
  }

  /// Continuously check if current position matches expected and has been held long enough
  void _checkCurrentPosition() {
    if (_state != PrayerTrackingState.tracking) return;
    if (_currentSequence == null) return;
    if (_stepCompleted) return;
    
    final currentPosition = _positionDetector.currentPosition;
    if (currentPosition == PrayerPosition.unknown || 
        currentPosition == PrayerPosition.transitioning) return;
    
    final expectedPosition = _currentSequence!.getExpectedPosition(_currentStepIndex);
    
    // Check if this matches the expected position
    if (currentPosition == expectedPosition) {
      // Check if we've been in this position long enough
      if (_lastPositionChangeTime != null && _lastPosition == currentPosition) {
        final duration = DateTime.now().difference(_lastPositionChangeTime!);
        if (duration.inMilliseconds >= 1000 && !_positionConfirmed) {
          _positionConfirmed = true;
          print('✅ Position ${currentPosition.shortName} confirmed after ${duration.inMilliseconds}ms');
          _handleCorrectPosition(currentPosition);
        }
      }
    }
  }
  
  /// Handle position changes from detector
  void _onPositionChanged(PrayerPosition newPosition) {
    print('🔍 _onPositionChanged called: ${newPosition.shortName}, state: $_state, index: $_currentStepIndex');
    
    if (_state != PrayerTrackingState.tracking) {
      print('   ❌ Not tracking (state: $_state)');
      return;
    }
    if (_currentSequence == null) {
      print('   ❌ No sequence');
      return;
    }
    if (newPosition == PrayerPosition.transitioning || 
        newPosition == PrayerPosition.unknown) {
      print('   ❌ Transitioning/Unknown');
      return;
    }

    final expectedPosition = _currentSequence!.getExpectedPosition(_currentStepIndex);

    print('✅ Position: ${newPosition.shortName} (Expected: ${expectedPosition.shortName}, Step ${_currentStepIndex + 1}/${totalSteps})');

    // Track position changes - reset confirmation when position changes
    if (newPosition != _lastPosition) {
      print('   🔄 New position detected (was: ${_lastPosition?.shortName ?? "null"})');
      _lastPositionChangeTime = DateTime.now();
      _positionConfirmed = false;
      _stepCompleted = false;
      _lastPosition = newPosition;
      
      // If wrong position, immediately alert
      if (newPosition != expectedPosition) {
        _handleIncorrectPosition(newPosition, expectedPosition);
      }
    }
  }

  /// Handle correct position detection
  void _handleCorrectPosition(PrayerPosition position) {
    // Track consecutive Sajdas
    if (position == PrayerPosition.prostration) {
      _sajdaCount++;
    } else if (_lastPosition == PrayerPosition.prostration && 
               position != PrayerPosition.sitting) {
      // Reset if moved away from Sajda (not to sitting)
      _sajdaCount = 0;
    }

    // Move to next step
    _stepCompleted = true; // Mark step as completed
    _advanceToNextStep();
  }

  /// Handle incorrect position detection
  void _handleIncorrectPosition(PrayerPosition actual, PrayerPosition expected) {
    // Record mistake
    final mistake = PrayerMistake(
      stepIndex: _currentStepIndex,
      description: 'Expected ${expected.shortName}, got ${actual.shortName}',
      timestamp: DateTime.now(),
    );
    _mistakes.add(mistake);

    // Trigger alert based on mistake type
    PrayerTrackerAlert? alert;

    if (expected == PrayerPosition.prostration && actual != PrayerPosition.prostration) {
      // Missed Sajda
      final rakatNum = (_currentStepIndex ~/ 6) + 1; // Approximate rakat number
      final sajdaNum = ((_currentStepIndex % 6) > 2) ? 2 : 1;
      alert = PrayerAlertService.missedSajda(rakatNum, sajdaNum);
    } else if (expected == PrayerPosition.bowing && actual != PrayerPosition.bowing) {
      // Missed Ruku
      final rakatNum = (_currentStepIndex ~/ 6) + 1;
      alert = PrayerAlertService.missedRuku(rakatNum);
    } else {
      // Wrong sequence
      alert = PrayerAlertService.wrongSequence(
        expected.shortName,
        actual.shortName,
      );
    }

    _alertService.triggerAlert(alert);
    onAlert?.call(alert);

    // Try to recover: skip to matching step in sequence
    _tryRecoverSequence(actual);
  }

  /// Try to find and jump to correct step in sequence
  void _tryRecoverSequence(PrayerPosition actualPosition) {
    // Look ahead in sequence for matching position
    for (int i = _currentStepIndex + 1; i < _currentSequence!.steps.length; i++) {
      if (_currentSequence!.steps[i].position == actualPosition) {
        print('Recovered sequence at step ${i + 1}');
        _currentStepIndex = i;
        _stepStartTime = DateTime.now();
        onProgressChanged?.call(_currentStepIndex, totalSteps);
        return;
      }
    }
  }

  /// Advance to next step in sequence
  void _advanceToNextStep() {
    print('📈 Advancing from step $_currentStepIndex to ${_currentStepIndex + 1} (total: $totalSteps)');
    
    _currentStepIndex++;
    _stepStartTime = DateTime.now();
    _positionConfirmed = false; // Reset confirmation for next step
    _stepCompleted = false; // Reset completion for next step

    if (_currentStepIndex >= totalSteps) {
      // Prayer completed
      print('🏁 Reached end of sequence, calling completePrayer()');
      completePrayer();
    } else {
      onProgressChanged?.call(_currentStepIndex, totalSteps);
    }
  }

  /// Get current progress percentage
  double getProgress() {
    if (totalSteps == 0) return 0.0;
    return (_currentStepIndex / totalSteps) * 100;
  }

  /// Manual step navigation (for testing/calibration)
  void manualNextStep() {
    if (_state != PrayerTrackingState.tracking) return;
    _advanceToNextStep();
  }

  void manualPrevStep() {
    if (_state != PrayerTrackingState.tracking) return;
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      onProgressChanged?.call(_currentStepIndex, totalSteps);
    }
  }
}
