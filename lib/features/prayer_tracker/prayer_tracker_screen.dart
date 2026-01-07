import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'prayer_position.dart';
import 'prayer_position_detector.dart';
import 'prayer_tracker_service.dart';
import 'prayer_alert_service.dart';
import 'prayer_sequence.dart';
import '../../presentation/widgets/app_header.dart';
import '../../core/prayer_time_service.dart';

/// Screen for prayer movement tracking
class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({Key? key}) : super(key: key);

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  late PrayerPositionDetector _detector;
  late PrayerTrackerService _tracker;
  
  String? _selectedPrayer;
  PrayerTrackingState _trackingState = PrayerTrackingState.idle;
  int _currentStep = 0;
  int _totalSteps = 0;
  PrayerPosition _currentPosition = PrayerPosition.unknown;
  final List<PrayerMistake> _mistakes = [];
  final List<PrayerTrackerAlert> _alerts = [];
  Map<String, double> _sensorReadings = {};
  
  Timer? _sensorUpdateTimer;

  @override
  void initState() {
    super.initState();
    _detector = PrayerPositionDetector(
      onPositionChanged: (position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      },
    );

    _tracker = PrayerTrackerService(
      positionDetector: _detector,
      onStateChanged: (state) {
        if (mounted) {
          setState(() {
            _trackingState = state;
          });
        }
      },
      onProgressChanged: (step, total) {
        if (mounted) {
          setState(() {
            _currentStep = step;
            _totalSteps = total;
          });
        }
      },
      onAlert: (alert) {
        if (mounted) {
          setState(() {
            _alerts.insert(0, alert);
            if (_alerts.length > 5) _alerts.removeLast();
          });
        }
      },
      onPrayerComplete: (mistakes, needsSajdaSahw) {
        if (mounted) {
          _showCompletionDialog(mistakes, needsSajdaSahw);
        }
      },
    );

    // Update sensor readings every 200ms
    _sensorUpdateTimer = Timer.periodic(Duration(milliseconds: 200), (_) {
      if (mounted) {
        setState(() {
          _sensorReadings = _detector.getSensorReadings();
          // Also sync current position from detector
          _currentPosition = _detector.currentPosition;
        });
      }
    });
  }

  @override
  void dispose() {
    _sensorUpdateTimer?.cancel();
    // Mark as disposed before stopping to prevent setState during dispose
    _tracker.dispose();
    _tracker.stopTracking();
    super.dispose();
  }

  void _showCompletionDialog(List<PrayerMistake> mistakes, bool needsSajdaSahw) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              mistakes.isEmpty ? Icons.check_circle : Icons.info,
              color: mistakes.isEmpty ? Colors.green : Colors.orange,
            ),
            SizedBox(width: 8),
            Text(mistakes.isEmpty ? 'Perfect Prayer!' : 'Prayer Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mistakes.isEmpty) ...[
              Text('Alhamdulillah! You completed the prayer perfectly.'),
            ] else ...[
              Text('Prayer completed with ${mistakes.length} mistake(s):'),
              SizedBox(height: 12),
              ...mistakes.map((m) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('• ${m.description}', style: TextStyle(fontSize: 13)),
              )),
              if (needsSajdaSahw) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sajda Sahw recommended',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalSteps > 0 ? (_currentStep / _totalSteps) : 0.0;
    final prayerService = Provider.of<PrayerTimeService>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              city: prayerService.city,
              state: prayerService.state,
              isLoading: prayerService.isLoading,
              onRefresh: () => prayerService.refresh(),
              showLocation: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Prayer Selection
                    if (_trackingState == PrayerTrackingState.idle) ...[
                      // Sensor Test Mode
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.sensors, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Sensor Test Mode',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getPositionColor(_currentPosition).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _getPositionColor(_currentPosition)),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      _getPositionIcon(_currentPosition),
                                      size: 40,
                                      color: _getPositionColor(_currentPosition),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      _currentPosition.displayName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _getPositionColor(_currentPosition),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                            Text('Pitch: ${_sensorReadings['pitch']?.toStringAsFixed(1) ?? "0"}°', style: TextStyle(fontSize: 12)),
                            Text('Roll: ${_sensorReadings['roll']?.toStringAsFixed(1) ?? "0"}°', style: TextStyle(fontSize: 12)),
                            Text('Vertical: ${_sensorReadings['verticalAccel']?.toStringAsFixed(2) ?? "0"} m/s²', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_detector.currentPosition == PrayerPosition.unknown) {
                                  _detector.startDetection();
                                } else {
                                  _detector.stopDetection();
                                  setState(() {
                                    _currentPosition = PrayerPosition.unknown;
                                  });
                                }
                              },
                              icon: Icon(_detector.currentPosition == PrayerPosition.unknown ? Icons.play_arrow : Icons.stop),
                              label: Text(_detector.currentPosition == PrayerPosition.unknown ? 'Start' : 'Stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              // Calibration Section
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Calibration',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                            SizedBox(height: 4),
                            Text(
                              '📱 PUT PHONE IN POCKET before calibrating!\nHold each position for 2-3 seconds.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Current position: ${_currentPosition.displayName}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _getPositionColor(_currentPosition)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pitch: ${_sensorReadings['pitch']?.toStringAsFixed(1) ?? "0"}° | Z: ${_sensorReadings['verticalAccel']?.toStringAsFixed(1) ?? "0"}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Hold position and tap to calibrate',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _detector.startDetection();
                              Future.delayed(Duration(milliseconds: 100), () {
                                _detector.calibrateStanding();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Standing position calibrated!'), duration: Duration(seconds: 2)),
                                );
                              });
                            },
                            icon: Icon(Icons.accessibility_new, size: 18),
                            label: Text('Standing', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _detector.startDetection();
                              Future.delayed(Duration(milliseconds: 100), () {
                                _detector.calibrateBowing();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Ruku position calibrated!'), duration: Duration(seconds: 2)),
                                );
                              });
                            },
                            icon: Icon(Icons.accessibility, size: 18),
                            label: Text('Ruku', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _detector.startDetection();
                              Future.delayed(Duration(milliseconds: 100), () {
                                _detector.calibrateProstration();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Sajda position calibrated!'), duration: Duration(seconds: 2)),
                                );
                              });
                            },
                            icon: Icon(Icons.airline_seat_recline_extra, size: 18),
                            label: Text('Sajda', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _detector.startDetection();
                              Future.delayed(Duration(milliseconds: 100), () {
                                _detector.calibrateSitting();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Sitting position calibrated!'), duration: Duration(seconds: 2)),
                                );
                              });
                            },
                            icon: Icon(Icons.event_seat, size: 18),
                            label: Text('Sitting', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              _detector.resetCalibration();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('🔄 Reset to defaults'), duration: Duration(seconds: 2)),
                              );
                            },
                            icon: Icon(Icons.refresh, size: 18),
                            label: Text('Reset', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Select Prayer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].map((prayer) {
                final sequence = PrayerSequences.getSequence(prayer)!;
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(Icons.mosque, color: Colors.deepPurple),
                    title: Text(prayer, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${sequence.rakats} Rakats • ${sequence.steps.length} Steps'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      setState(() {
                        _selectedPrayer = prayer;
                        _alerts.clear();
                      });
                      _tracker.startTracking(prayer);
                    },
                  ),
                );
              }),
            ],

            // Tracking Interface
            if (_trackingState != PrayerTrackingState.idle) ...[
              // Prayer Info Card
              Card(
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mosque, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            _selectedPrayer ?? '',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Spacer(),
                          Text(
                            _trackingState.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation(Colors.green),
                        minHeight: 8,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Step $_currentStep of $_totalSteps',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Current Position Display
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Current Position',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _getPositionColor(_currentPosition).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getPositionColor(_currentPosition),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _getPositionIcon(_currentPosition),
                              size: 48,
                              color: _getPositionColor(_currentPosition),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _currentPosition.shortName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _getPositionColor(_currentPosition),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_trackingState == PrayerTrackingState.tracking) ...[
                        SizedBox(height: 12),
                        Text(
                          'Expected: ${_tracker.currentExpectedPosition?.shortName ?? "Unknown"}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        // Sensor data display
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text('Sensor Data:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Pitch: ${_sensorReadings['pitch']?.toStringAsFixed(1) ?? "0"}°', style: TextStyle(fontSize: 11)),
                              Text('Roll: ${_sensorReadings['roll']?.toStringAsFixed(1) ?? "0"}°', style: TextStyle(fontSize: 11)),
                              Text('Vertical: ${_sensorReadings['verticalAccel']?.toStringAsFixed(2) ?? "0"} m/s²', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Recent Alerts
              if (_alerts.isNotEmpty) ...[
                Text(
                  'Recent Alerts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ..._alerts.take(3).map((alert) => Card(
                  color: _getAlertColor(alert.type),
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(_getAlertIcon(alert.type), color: Colors.white),
                    title: Text(
                      alert.message,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: alert.details != null
                        ? Text(alert.details!, style: TextStyle(color: Colors.white70))
                        : null,
                  ),
                )),
                SizedBox(height: 16),
              ],

              // Control Buttons
              if (_trackingState == PrayerTrackingState.ready) ...[
                ElevatedButton.icon(
                  onPressed: () => _tracker.beginPrayer(),
                  icon: Icon(Icons.play_arrow),
                  label: Text('BEGIN PRAYER'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(16),
                  ),
                ),
              ],

              if (_trackingState == PrayerTrackingState.tracking) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _tracker.pause(),
                        icon: Icon(Icons.pause),
                        label: Text('PAUSE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _tracker.stopTracking(),
                        icon: Icon(Icons.stop),
                        label: Text('CANCEL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (_trackingState == PrayerTrackingState.paused) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _tracker.resume(),
                        icon: Icon(Icons.play_arrow),
                        label: Text('RESUME'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _tracker.stopTracking();
                          setState(() {
                            _selectedPrayer = null;
                          });
                        },
                        icon: Icon(Icons.stop),
                        label: Text('STOP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 16),

              // Cancel Button
              TextButton(
                onPressed: () {
                  _tracker.stopTracking();
                  setState(() {
                    _selectedPrayer = null;
                  });
                },
                child: Text('Cancel Prayer'),
              ),
            ],
          ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Color _getPositionColor(PrayerPosition position) {
    switch (position) {
      case PrayerPosition.standing:
        return Colors.blue;
      case PrayerPosition.bowing:
        return Colors.orange;
      case PrayerPosition.prostration:
        return Colors.green;
      case PrayerPosition.sitting:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getPositionIcon(PrayerPosition position) {
    switch (position) {
      case PrayerPosition.standing:
        return Icons.accessibility;
      case PrayerPosition.bowing:
        return Icons.airline_seat_legroom_reduced;
      case PrayerPosition.prostration:
        return Icons.airline_seat_recline_normal;
      case PrayerPosition.sitting:
        return Icons.event_seat;
      default:
        return Icons.help_outline;
    }
  }

  Color _getAlertColor(AlertType type) {
    switch (type) {
      case AlertType.missedPosition:
      case AlertType.wrongSequence:
      case AlertType.incompleteSajda:
        return Colors.red.shade400;
      case AlertType.sajdaSahwNeeded:
        return Colors.orange.shade400;
      case AlertType.prayerComplete:
        return Colors.green.shade400;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.missedPosition:
      case AlertType.wrongSequence:
      case AlertType.incompleteSajda:
        return Icons.warning;
      case AlertType.sajdaSahwNeeded:
        return Icons.info;
      case AlertType.prayerComplete:
        return Icons.check_circle;
    }
  }
}
