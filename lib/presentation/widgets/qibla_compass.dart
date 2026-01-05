import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class QiblaCompass extends StatefulWidget {
  const QiblaCompass({Key? key}) : super(key: key);

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  double? _manualQiblaAngle;
  StreamSubscription<Position>? _positionSubscription;
  bool _showCalibrationHint = true;
  bool _deviceSupported = true;

  @override
  void initState() {
    super.initState();
    _checkDeviceSupport();
    _calculateManualQibla();
    // Hide calibration hint after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showCalibrationHint = false;
        });
      }
    });
  }

  Future<void> _checkDeviceSupport() async {
    final supported = await FlutterQiblah.androidDeviceSensorSupport();
    setState(() {
      _deviceSupported = supported ?? false;
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  // Manually calculate Qibla direction using coordinates
  Future<void> _calculateManualQibla() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final qibla = _getQiblaDirection(position.latitude, position.longitude);
      setState(() {
        _manualQiblaAngle = qibla;
      });
    } catch (e) {
      // Handle error
    }
  }

  // Calculate Qibla bearing from current location to Kaaba (21.4225, 39.8262)
  double _getQiblaDirection(double lat, double lon) {
    const kaabaLat = 21.4225; // Kaaba latitude
    const kaabaLon = 39.8262; // Kaaba longitude

    final latRad = lat * math.pi / 180;
    final lonRad = lon * math.pi / 180;
    final kaabaLatRad = kaabaLat * math.pi / 180;
    final kaabaLonRad = kaabaLon * math.pi / 180;

    final dLon = kaabaLonRad - lonRad;

    final y = math.sin(dLon) * math.cos(kaabaLatRad);
    final x = math.cos(latRad) * math.sin(kaabaLatRad) -
        math.sin(latRad) * math.cos(kaabaLatRad) * math.cos(dLon);

    final bearing = math.atan2(y, x);
    final bearingDegrees = (bearing * 180 / math.pi + 360) % 360;

    return bearingDegrees;
  }

  @override
  Widget build(BuildContext context) {
    // If device doesn't support sensors, show manual compass
    if (!_deviceSupported) {
      return _buildCompassWithManualQibla();
    }

    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Only use manual fallback if there's actually an error
        if (snapshot.hasError) {
          print('Qibla stream error: ${snapshot.error}');
          if (_manualQiblaAngle != null) {
            return _buildCompassWithManualQibla();
          }
          return const Center(child: Text('Qibla direction unavailable'));
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final qiblahDirection = snapshot.data!;
        
        // Use manual calculation for qibla angle, but use live direction for rotation
        final qiblaAngle = _manualQiblaAngle ?? qiblahDirection.qiblah;
        
        // Convert degrees to radians using dart:math
        final qiblahRad = qiblaAngle * (math.pi / 180);
        final directionRad = qiblahDirection.direction * (math.pi / 180);
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Compass rose background with N/S/E/W markers (rotates to keep North up)
            Transform.rotate(
              angle: -directionRad,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Stack(
                  children: [
                    // North marker
                    Positioned(
                      top: 5,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text('N', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Qibla direction indicator with icon and arrow
            Transform.rotate(
              angle: qiblahRad - directionRad,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation, size: 32, color: Colors.green),
                  SizedBox(height: 1),
                  FaIcon(FontAwesomeIcons.kaaba, size: 32, color: Colors.black),
                  SizedBox(height: 2),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'QIBLA',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Calibration hint
            if (_showCalibrationHint)
              Positioned(
                bottom: -50,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Move phone in figure-8',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCompassWithManualQibla() {
    if (_manualQiblaAngle == null) {
      return const Center(child: Text('Calculating Qibla direction...'));
    }

    final qiblahRad = _manualQiblaAngle! * (math.pi / 180);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Static compass rose
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 2),
          ),
          child: Stack(
            children: [
              // North marker
              Positioned(
                top: 5,
                left: 0,
                right: 0,
                child: Center(
                  child: Text('N', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
        // Qibla direction indicator (pointing to calculated direction)
        Transform.rotate(
          angle: qiblahRad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.navigation, size: 40, color: Colors.green),
              SizedBox(height: 2),
              FaIcon(FontAwesomeIcons.kaaba, size: 40, color: Colors.black),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'QIBLA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Direction info at bottom
        Positioned(
          bottom: -60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_manualQiblaAngle!.toStringAsFixed(1)}°',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rotate device to align',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
