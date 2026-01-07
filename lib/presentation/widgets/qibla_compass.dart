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
  bool _showCalibrationHint = true;
  bool _deviceSupported = true;
  bool _isCalculating = false;
  String? _errorMessage;
  Timer? _calibrationTimer;

  @override
  void initState() {
    super.initState();
    _initializeQibla();
  }

  Future<void> _initializeQibla() async {
    await _checkDeviceSupport();
    
    // If device doesn't support sensors, calculate manual qibla
    if (!_deviceSupported) {
      await _calculateManualQibla();
    } else {
      // Hide calibration hint after 5 seconds for sensor-based compass
      _calibrationTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showCalibrationHint = false;
          });
        }
      });
    }
  }

  Future<void> _checkDeviceSupport() async {
    try {
      final supported = await FlutterQiblah.androidDeviceSensorSupport();
      if (mounted) {
        setState(() {
          _deviceSupported = supported ?? false;
        });
      }
    } catch (e) {
      // If check fails, assume device is supported and let the stream handle it
      if (mounted) {
        setState(() {
          _deviceSupported = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _calibrationTimer?.cancel();
    super.dispose();
  }

  // Manually calculate Qibla direction using coordinates
  Future<void> _calculateManualQibla() async {
    setState(() {
      _isCalculating = true;
      _errorMessage = null;
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Please enable in settings.');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Calculate Qibla direction
      final qibla = _getQiblaDirection(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _manualQiblaAngle = qibla;
          _isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCalculating = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
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
      return _buildManualCompass();
    }

    return StreamBuilder<QiblahDirection>(
      stream: FlutterQiblah.qiblahStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        // If there's an error with the sensor, fall back to manual
        if (snapshot.hasError) {
          return _buildManualCompass();
        }
        
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        final qiblahDirection = snapshot.data!;
        
        return _buildSensorCompass(qiblahDirection);
      },
    );
  }

  Widget _buildSensorCompass(QiblahDirection qiblahDirection) {
    // Convert degrees to radians
    // direction = device compass heading from North (0-360)
    // qiblah = the angle to rotate to point to Qibla (relative to device heading)
    final directionRad = (qiblahDirection.direction * math.pi / 180);
    // qiblah from flutter_qiblah is the relative angle to Qibla from current heading
    // Negative because Flutter's Transform.rotate is counterclockwise positive
    final qiblahOffsetRad = (qiblahDirection.qiblah * math.pi / 180);
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Static outer border circle (doesn't rotate)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                    ),
                  ),
                  // Compass rose with N/S/E/W markers (rotates to keep North up)
                  Positioned.fill(
                    child: Transform.rotate(
                      angle: -directionRad,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // North marker
                          Positioned(
                            top: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Text(
                                'N',
                                style: TextStyle(
                                  fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ),
                        // South marker
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'S',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        // East marker
                        Positioned(
                          right: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              'E',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        // West marker
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Text(
                              'W',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                  // Qibla direction indicator - points to Qibla
                  // Rotate by negative qiblah offset (Flutter uses counterclockwise positive)
                  Transform.rotate(
                    angle: -qiblahOffsetRad,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.navigation,
                          size: 40,
                          color: Colors.green.shade700,
                        ),
                      const SizedBox(height: 4),
                      FaIcon(
                        FontAwesomeIcons.kaaba,
                        size: 36,
                        color: Colors.black87,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Qibla angle display - show absolute bearing from North
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Text(
                  'Qibla Bearing: ${((qiblahDirection.direction - qiblahDirection.qiblah + 360) % 360).toStringAsFixed(1)}°',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Device Heading: ${qiblahDirection.direction.toStringAsFixed(1)}°',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Calibration hint
          if (_showCalibrationHint) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade900,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Move phone in figure-8 to calibrate',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildManualCompass() {
    // Show loading state
    if (_isCalculating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Calculating Qibla direction...',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show error state
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _calculateManualQibla,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show compass with calculated direction
    if (_manualQiblaAngle == null) {
      return const Center(
        child: Text('Unable to determine Qibla direction'),
      );
    }

    final qiblahRad = _manualQiblaAngle! * (math.pi / 180);
    
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Static compass rose
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Stack(
                    children: [
                      // North marker
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'N',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                      // South marker
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'S',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      // East marker
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            'E',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      // West marker
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Text(
                            'W',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Qibla direction indicator
                Transform.rotate(
                  angle: qiblahRad,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.navigation,
                        size: 40,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 4),
                      FaIcon(
                        FontAwesomeIcons.kaaba,
                        size: 36,
                        color: Colors.black87,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Direction info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              '${_manualQiblaAngle!.toStringAsFixed(1)}°',
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rotate device to align with arrow',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Compass sensor unavailable',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}