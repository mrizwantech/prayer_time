import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/prayer_theme_provider.dart';
import '../../core/time_format_settings.dart';
import 'prayer_countdown_timer.dart';

class PrayerTimeline extends StatefulWidget {
  const PrayerTimeline({Key? key}) : super(key: key);

  @override
  State<PrayerTimeline> createState() => _PrayerTimelineState();
}

class _PrayerTimelineState extends State<PrayerTimeline> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> prayers = [];
  bool isLoading = true;

  int currentIndex = 0;
  int actualCurrentIndex = 0; // Track real prayer time for "Next Prayer" display
  double progress = 0;
  Timer? timer;
  bool isManualSelection = false;
  Timer? manualSelectionTimer;
  
  // Static cache to preserve data across navigation
  static List<Map<String, dynamic>> _cachedPrayers = [];
  static DateTime? _cacheDate;

  @override
  void initState() {
    super.initState();
    _initializePrayerTimes();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isManualSelection && prayers.isNotEmpty) {
        setState(() {
          _updateCurrentPrayerAndProgress();
        });
      }
    });
  }
  
  void _initializePrayerTimes() {
    final now = DateTime.now();
    // Check if we have cached data from today
    if (_cachedPrayers.isNotEmpty && 
        _cacheDate != null && 
        _cacheDate!.year == now.year &&
        _cacheDate!.month == now.month &&
        _cacheDate!.day == now.day) {
      // Use cached data - instant load
      prayers = _cachedPrayers;
      isLoading = false;
      _updateCurrentPrayerAndProgress();
    } else {
      // Fetch fresh data
      _loadPrayerTimes();
    }
  }

  Future<void> _loadPrayerTimes() async {
    try {
      // Try last known position first for faster load
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Calculate prayer times using adhan package
      final coordinates = Coordinates(position.latitude, position.longitude);
      final params = CalculationMethod.muslim_world_league.getParameters();
      final dateComponents = DateComponents.from(DateTime.now());
      final prayerTimes = PrayerTimes(coordinates, dateComponents, params);

      // Format times
      String formatPrayerTime(DateTime dt) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }

      setState(() {
        prayers = [
          {'name': 'Fajr', 'time': formatPrayerTime(prayerTimes.fajr), 'icon': '🌅', 'dateTime': prayerTimes.fajr},
          {'name': 'Dhuhr', 'time': formatPrayerTime(prayerTimes.dhuhr), 'icon': '☀️', 'dateTime': prayerTimes.dhuhr},
          {'name': 'Asr', 'time': formatPrayerTime(prayerTimes.asr), 'icon': '🌤️', 'dateTime': prayerTimes.asr},
          {'name': 'Maghrib', 'time': formatPrayerTime(prayerTimes.maghrib), 'icon': '🌅', 'dateTime': prayerTimes.maghrib},
          {'name': 'Isha', 'time': formatPrayerTime(prayerTimes.isha), 'icon': '🌙', 'dateTime': prayerTimes.isha},
          {'name': 'Tahajjud (Qiyam-u-lail)', 'time': '00:00', 'icon': '🌌', 'dateTime': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1, 0, 0)},
        ];
        // Cache the results
        _cachedPrayers = prayers;
        _cacheDate = DateTime.now();
        isLoading = false;
        _updateCurrentPrayerAndProgress();
      });
    } catch (e) {
      print('Error loading prayer times: $e');
      // Fallback to default times if location fails
      setState(() {
        prayers = [
          {'name': 'Fajr', 'time': '05:30', 'icon': '🌅'},
          {'name': 'Dhuhr', 'time': '12:30', 'icon': '☀️'},
          {'name': 'Asr', 'time': '15:45', 'icon': '🌤️'},
          {'name': 'Maghrib', 'time': '18:15', 'icon': '🌅'},
          {'name': 'Isha', 'time': '19:45', 'icon': '🌙'},
          {'name': 'Tahajjud (Qiyam-u-lail)', 'time': '00:00', 'icon': '🌌'},
        ];
        isLoading = false;
        _updateCurrentPrayerAndProgress();
      });
    }
  }

  void _updateCurrentPrayerAndProgress() {
    if (prayers.isEmpty) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Use dateTime if available, otherwise parse time string
    List<DateTime> times = prayers.map((p) {
      if (p.containsKey('dateTime')) {
        return p['dateTime'] as DateTime;
      }
      final parts = (p['time'] as String).split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      if (p['name'] == 'Tahajjud (Qiyam-u-lail)') {
        return DateTime(today.year, today.month, today.day + 1, hour, minute);
      }
      return DateTime(today.year, today.month, today.day, hour, minute);
    }).toList();
    // Add next day's Fajr for after Tahajjud
    times.add(times[0].add(const Duration(days: 1)));

    // Find which prayer period we're in
    int idx = 0;
    bool found = false;
    
    for (int i = 0; i < times.length - 1; i++) {
      if (now.isAfter(times[i]) && now.isBefore(times[i + 1])) {
        idx = i;
        found = true;
        break;
      }
    }
    
    // If not found and we're before Fajr, we're in Tahajjud period
    if (!found && now.isBefore(times[0])) {
      idx = 5; // Tahajjud index
      found = true;
    }
    
    currentIndex = idx % prayers.length;
    actualCurrentIndex = idx % prayers.length; // Always update actual current prayer
    final start = times[idx];
    final end = times[idx + 1];
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    progress = (elapsed / total).clamp(0, 1) * 100;
  }

  String _formatTime(String time24, bool is24Hour) {
    if (is24Hour) return time24;
    
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];
    
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    
    return '$hour:$minute $period';
  }

  DateTime _getNextPrayerDateTime(int nextIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final parts = (prayers[nextIndex]['time'] as String).split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    var nextPrayerTime = DateTime(today.year, today.month, today.day, hour, minute);
    
    // If prayer time has passed today, use tomorrow's time
    if (nextPrayerTime.isBefore(now)) {
      nextPrayerTime = nextPrayerTime.add(const Duration(days: 1));
    }
    
    return nextPrayerTime;
  }

  @override
  void dispose() {
    timer?.cancel();
    manualSelectionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade400, Colors.purple.shade300],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    const double size = 350;
    const double radius = 110;
    const double center = size / 2;
    const double nodeRadius = 32;

    final themeProvider = PrayerThemeProvider();
    final currentTheme = themeProvider.getCurrentTheme(prayers[currentIndex]['name']);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: currentTheme.backgroundGradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, color: currentTheme.primaryColor, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Daily Prayer Timeline',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: currentTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Current Prayer: ${prayers[currentIndex]['name']}',
              style: TextStyle(
                color: currentTheme.secondaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            // Next Prayer info above cards
            const SizedBox(height: 32),
            Builder(
              builder: (context) {
                final timeSettings = Provider.of<TimeFormatSettings>(context);
                // Use actualCurrentIndex for next prayer calculation (not affected by manual selection)
                final nextIndex = (() {
                  int idx = actualCurrentIndex + 1;
                  for (int i = 0; i < prayers.length; i++) {
                    final name = prayers[idx % prayers.length]['name'] as String;
                    if (name != 'Tahajjud (Qiyam-u-lail)') {
                      return idx % prayers.length;
                    }
                    idx++;
                  }
                  return (actualCurrentIndex + 1) % prayers.length;
                })();
                return Column(
                  children: [
                    Text(
                      'Next Prayer',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      prayers[nextIndex]['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(prayers[nextIndex]['time'], timeSettings.is24Hour),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            // Circular Timeline with Qibla in center
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                children: [
                  // SVG-like custom painter
                  CustomPaint(
                    size: Size(size, size),
                    painter: _PrayerTimelinePainter(
                      progress: progress,
                      prayers: prayers,
                      currentIndex: currentIndex,
                      actualCurrentIndex: actualCurrentIndex,
                    ),
                  ),
                  // Prayer nodes
                  ...List.generate(prayers.length, (index) {
                    final angle = (index / prayers.length) * 2 * pi - pi / 2;
                    final x = center + radius * cos(angle);
                    final y = center + radius * sin(angle);
                    final isCurrent = index == currentIndex;
                    return Positioned(
                      left: x - nodeRadius,
                      top: y - nodeRadius,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            currentIndex = index;
                            progress = 0;
                            isManualSelection = true;
                          });
                          
                          // Cancel any existing timer
                          manualSelectionTimer?.cancel();
                          
                          // Set timer to revert to automatic after 5 seconds
                          manualSelectionTimer = Timer(const Duration(seconds: 5), () {
                            setState(() {
                              isManualSelection = false;
                              _updateCurrentPrayerAndProgress();
                            });
                          });
                        },
                        child: Column(
                          children: [
                            Container(
                              width: isCurrent ? nodeRadius * 2.2 : nodeRadius * 2,
                              height: isCurrent ? nodeRadius * 2.2 : nodeRadius * 2,
                              decoration: BoxDecoration(
                                color: isCurrent ? currentTheme.primaryColor : currentTheme.cardColor.withOpacity(0.7),
                                shape: BoxShape.circle,
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: currentTheme.primaryColor.withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : [],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        prayers[index]['name'],
                                        style: TextStyle(
                                          color: isCurrent ? currentTheme.textColor : currentTheme.textColor.withOpacity(0.9),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                    Consumer<TimeFormatSettings>(
                                      builder: (context, timeSettings, _) => Text(
                                        _formatTime(prayers[index]['time'], timeSettings.is24Hour),
                                        style: TextStyle(
                                          color: isCurrent ? currentTheme.textColor.withOpacity(0.8) : currentTheme.textColor.withOpacity(0.6),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Qibla direction compass in center
                  // QiblaCompass removed from home screen timeline
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerTimelinePainter extends CustomPainter {
  final double progress;
  final List<Map<String, dynamic>> prayers;
  final int currentIndex;
  final int actualCurrentIndex;

  _PrayerTimelinePainter({
    required this.progress,
    required this.prayers,
    required this.currentIndex,
    required this.actualCurrentIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double radius = 170;
    
    // Get theme colors for current prayer
    final themeProvider = PrayerThemeProvider();
    final currentPrayerName = prayers[currentIndex]['name'];
    final currentTheme = themeProvider.getCurrentTheme(currentPrayerName);
    
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress circle - solid white for visibility on all backgrounds
    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    // Shadow for the progress arc
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    // Start from Fajr position (index 0)
    final startAngle = -pi / 2; // Fajr is at the top
    final arcLength = (1 / prayers.length) * 2 * pi; // Length for one prayer segment
    // Total progress: completed prayers + progress in current prayer (use actual time, not manual selection)
    final totalProgress = actualCurrentIndex + (progress / 100);
    final sweepAngle = arcLength * totalProgress;
    
    // Draw shadow arc first
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      shadowPaint,
    );
    
    // Draw white progress arc on top
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PrayerTimelinePainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.currentIndex != currentIndex ||
           oldDelegate.actualCurrentIndex != actualCurrentIndex;
  }
}
