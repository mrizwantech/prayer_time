import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri_date/hijri_date.dart';
import 'package:hijri_date/hijri.dart';
import 'package:intl/intl.dart';
import '../../core/prayer_theme_provider.dart';
import '../../core/time_format_settings.dart';
import '../../core/prayer_time_service.dart';
import 'prayer_countdown_timer.dart';

// Inspirational quotes for each prayer
const Map<String, List<String>> prayerQuotes = {
  'Fajr': [
    'Fajr is witnessed by angels and filled with divine light',
    'It brings Allah\'s help at the beginning of the day',
    'Rising for Fajr is beloved to Allah despite difficulty',
    'Fajr opens doors of barakah and protection',
    'It reflects sincerity known only to Allah',
  ],
  'Dhuhr': [
    'Dhuhr reminds the heart to remember Allah in ease and effort',
    'It brings mercy when the sun is at its peak',
    'Dhuhr cleanses sins earned during the day',
    'It renews faith amid worldly responsibility',
    'Dhuhr strengthens gratitude for provision',
  ],
  'Asr': [
    'Asr protects the believer from loss and regret',
    'Guarding Asr is a sign of true faith',
    'It preserves the reward of the entire day',
    'Asr strengthens patience before exhaustion',
    'Missing Asr is warned against, showing its great value',
  ],
  'Maghrib': [
    'Maghrib reminds us how quickly life passes',
    'It calls the soul back before darkness falls',
    'Maghrib encourages repentance before night',
    'It fills the evening with remembrance',
    'Maghrib marks gratitude for another completed day',
  ],
  'Isha': [
    'Isha places the believer under Allah\'s protection',
    'It strengthens faith when the world sleeps',
    'Isha completes the daily cycle of obedience',
    'It brings peace before resting the soul',
    'Walking to Isha carries great reward',
  ],
  'Tahajjud (Qiyam-u-lail)': [
    'The night prayer is the honor of the believer',
    'Allah descends to the lowest heaven in the last third of the night',
    'Tahajjud brings closeness to Allah like no other prayer',
    'It is a time when duas are answered',
    'The best prayer after the obligatory ones is the night prayer',
  ],
};

String getRandomQuote(String prayerName) {
  final quotes = prayerQuotes[prayerName] ?? prayerQuotes['Fajr']!;
  final random = Random();
  return quotes[random.nextInt(quotes.length)];
}

class PrayerTimeline extends StatefulWidget {
  const PrayerTimeline({Key? key}) : super(key: key);

  @override
  State<PrayerTimeline> createState() => _PrayerTimelineState();
}

class _PrayerTimelineState extends State<PrayerTimeline> with SingleTickerProviderStateMixin {
  int currentIndex = 0;
  int actualCurrentIndex = 0;
  double progress = 0;
  Timer? timer;
  bool isManualSelection = false;
  Timer? manualSelectionTimer;
  String _currentQuote = '';
  String _lastPrayerForQuote = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isManualSelection && mounted) {
        setState(() {
          _updateCurrentPrayerAndProgress();
        });
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize immediately when data is available
    if (!_initialized) {
      _updateCurrentPrayerAndProgress();
      _initialized = true;
    }
  }
  
  void _updateQuoteIfNeeded(String prayerName) {
    if (_lastPrayerForQuote != prayerName) {
      _lastPrayerForQuote = prayerName;
      _currentQuote = getRandomQuote(prayerName);
    }
  }
  
  List<Map<String, dynamic>> _getPrayersFromService(PrayerTimeService service) {
    if (!service.hasPrayerTimes) return [];
    
    String formatTime(DateTime dt) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    
    final now = DateTime.now();
    return [
      {'name': 'Fajr', 'time': formatTime(service.fajr!), 'icon': '🌅', 'dateTime': service.fajr!},
      {'name': 'Dhuhr', 'time': formatTime(service.dhuhr!), 'icon': '☀️', 'dateTime': service.dhuhr!},
      {'name': 'Asr', 'time': formatTime(service.asr!), 'icon': '🌤️', 'dateTime': service.asr!},
      {'name': 'Maghrib', 'time': formatTime(service.maghrib!), 'icon': '🌅', 'dateTime': service.maghrib!},
      {'name': 'Isha', 'time': formatTime(service.isha!), 'icon': '🌙', 'dateTime': service.isha!},
      {'name': 'Tahajjud (Qiyam-u-lail)', 'time': '00:00', 'icon': '🌌', 'dateTime': DateTime(now.year, now.month, now.day + 1, 0, 0)},
    ];
  }

  /// Calculate current prayer and progress - can be called synchronously
  void _calculateCurrentPrayerAndProgress(PrayerTimeService service) {
    if (!service.hasPrayerTimes) return;
    
    final prayers = _getPrayersFromService(service);
    if (prayers.isEmpty) return;
    
    final now = DateTime.now();
    
    List<DateTime> times = prayers.map((p) => p['dateTime'] as DateTime).toList();
    times.add(times[0].add(const Duration(days: 1))); // Next day's Fajr

    int idx = 0;
    bool found = false;
    
    for (int i = 0; i < times.length - 1; i++) {
      if (now.isAfter(times[i]) && now.isBefore(times[i + 1])) {
        idx = i;
        found = true;
        break;
      }
    }
    
    if (!found && now.isBefore(times[0])) {
      idx = 5; // Tahajjud index
    }
    
    currentIndex = idx % prayers.length;
    actualCurrentIndex = idx % prayers.length;
    
    _updateQuoteIfNeeded(prayers[currentIndex]['name']);
    
    final start = times[idx];
    final end = times[idx + 1];
    final total = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    progress = (elapsed / total).clamp(0, 1) * 100;
  }

  void _updateCurrentPrayerAndProgress() {
    final service = Provider.of<PrayerTimeService>(context, listen: false);
    _calculateCurrentPrayerAndProgress(service);
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

  @override
  void dispose() {
    timer?.cancel();
    manualSelectionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerTimeService>(
      builder: (context, prayerService, child) {
        if (prayerService.isLoading || !prayerService.hasPrayerTimes) {
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

        // Calculate current prayer and progress synchronously before rendering
        _calculateCurrentPrayerAndProgress(prayerService);

        final prayers = _getPrayersFromService(prayerService);
        if (prayers.isEmpty) {
          return const Center(child: Text('No prayer times available'));
        }

        const double size = 350;
        const double radius = 110;
        const double center = size / 2;
        const double nodeRadius = 32;

        final themeProvider = PrayerThemeProvider();
        final currentTheme = themeProvider.getCurrentTheme(prayers[currentIndex]['name']);
        
        // Get dates
        final now = DateTime.now();
        final gregorianDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
        final hijriDate = HijriDate.now();
        final hijriDateStr = hijriDate.toFormat('dd MMMM yyyy');
        
        // Get moon phase and Islamic events
        final moonPhase = hijriDate.getMoonPhase();
        final moonPhaseName = hijriDate.getMoonPhaseName();
        final moonIllumination = (moonPhase.illumination * 100).toStringAsFixed(0);
        final todaysEvents = IslamicEventsManager.getTodaysEvents();
        
        // Calculate next prayer index
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

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: currentTheme.backgroundGradient,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Date Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          gregorianDate,
                          style: TextStyle(
                            color: currentTheme.textColor.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hijriDateStr,
                        style: TextStyle(
                          color: currentTheme.secondaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Current Time (without seconds)
                  Consumer<TimeFormatSettings>(
                    builder: (context, timeSettings, _) {
                      final timeFormat = timeSettings.is24Hour ? 'HH:mm' : 'hh:mm a';
                      final currentTime = DateFormat(timeFormat).format(now);
                      return Text(
                        currentTime,
                        style: TextStyle(
                          color: currentTheme.textColor,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  // Moon phase & Sunrise/Sunset row
                  const SizedBox(height: 8),
                  Consumer<TimeFormatSettings>(
                    builder: (context, timeSettings, _) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Moon phase
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(3.14159),
                            child: Icon(
                              _getMoonIcon(moonPhaseName),
                              color: currentTheme.secondaryColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$moonIllumination%',
                            style: TextStyle(
                              color: currentTheme.textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1,
                            height: 14,
                            color: currentTheme.textColor.withOpacity(0.3),
                          ),
                          const SizedBox(width: 12),
                          // Sunrise
                          if (prayerService.sunrise != null) ...[
                            Icon(
                              Icons.wb_sunny_outlined,
                              color: Colors.orange.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sunrise ',
                              style: TextStyle(
                                color: currentTheme.textColor.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _formatTime('${prayerService.sunrise!.hour.toString().padLeft(2, '0')}:${prayerService.sunrise!.minute.toString().padLeft(2, '0')}', timeSettings.is24Hour),
                              style: TextStyle(
                                color: currentTheme.textColor.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          // Sunset
                          if (prayerService.sunset != null) ...[
                            Icon(
                              Icons.wb_twilight,
                              color: Colors.deepOrange.withOpacity(0.9),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Sunset ',
                              style: TextStyle(
                                color: currentTheme.textColor.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _formatTime('${prayerService.sunset!.hour.toString().padLeft(2, '0')}:${prayerService.sunset!.minute.toString().padLeft(2, '0')}', timeSettings.is24Hour),
                              style: TextStyle(
                                color: currentTheme.textColor.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  
                  // Islamic Events (if any today)
                  if (todaysEvents.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: currentTheme.primaryColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.celebration,
                            color: currentTheme.secondaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              todaysEvents.map((e) => e.getTitle('en')).join(' • '),
                              style: TextStyle(
                                color: currentTheme.textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  // Two Prayer Cards Row
                  Consumer<TimeFormatSettings>(
                    builder: (context, timeSettings, _) {
                      return Row(
                        children: [
                          // Current Prayer Card
                          Expanded(
                            child: _buildPrayerCard(
                              prayerName: prayers[currentIndex]['name'],
                              prayerTime: _formatTime(prayers[currentIndex]['time'], timeSettings.is24Hour),
                              label: 'Current Prayer',
                              isCurrentPrayer: true,
                              theme: currentTheme,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Next Prayer Card
                          Expanded(
                            child: _buildPrayerCard(
                              prayerName: prayers[nextIndex]['name'],
                              prayerTime: _formatTime(prayers[nextIndex]['time'], timeSettings.is24Hour),
                              label: 'Next Prayer',
                              isCurrentPrayer: false,
                              theme: currentTheme,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  // Inspirational quote
                  if (_currentQuote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, left: 8, right: 8),
                      child: Text(
                        '"$_currentQuote"',
                        style: TextStyle(
                          color: currentTheme.textColor.withOpacity(0.7),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Circular Timeline
                  SizedBox(
                    width: size,
                    height: size,
                    child: Stack(
                      children: [
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
                            child: Container(
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
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPrayerCard({
    required String prayerName,
    required String prayerTime,
    required String label,
    required bool isCurrentPrayer,
    required PrayerTheme theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrentPrayer 
            ? Colors.white.withOpacity(0.2)
            : theme.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPrayer 
              ? Colors.white.withOpacity(0.3)
              : theme.primaryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.textColor.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prayerName,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            prayerTime,
            style: TextStyle(
              color: theme.textColor.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getMoonIcon(String moonPhaseName) {
    final phase = moonPhaseName.toLowerCase();
    if (phase.contains('new')) {
      return Icons.brightness_3;
    } else if (phase.contains('full')) {
      return Icons.circle;
    } else if (phase.contains('first') || phase.contains('waxing crescent')) {
      return Icons.brightness_2;
    } else if (phase.contains('last') || phase.contains('waning')) {
      return Icons.brightness_3;
    } else if (phase.contains('gibbous')) {
      return Icons.brightness_1;
    } else {
      return Icons.nightlight_round;
    }
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
    
    final themeProvider = PrayerThemeProvider();
    final currentPrayerName = prayers[currentIndex]['name'];
    final currentTheme = themeProvider.getCurrentTheme(currentPrayerName);
    
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress circle
    final progressPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    final startAngle = -pi / 2;
    final arcLength = (1 / prayers.length) * 2 * pi;
    final totalProgress = actualCurrentIndex + (progress / 100);
    final sweepAngle = arcLength * totalProgress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      shadowPaint,
    );
    
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
