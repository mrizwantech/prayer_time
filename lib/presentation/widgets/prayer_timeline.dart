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
import '../../core/prayer_font_settings.dart';

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
  const PrayerTimeline({super.key});

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

  bool get _isRamadan {
    final hijri = HijriDate.now();
    return hijri.hMonth == 9;
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

        final themeProvider = Provider.of<PrayerThemeProvider>(context);
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
        final isRamadan = _isRamadan;
        
        return Consumer<PrayerFontSettings>(
          builder: (context, fontSettings, _) {
            final fs = fontSettings.scale;
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
                  // Islamic Events (if any today)
                  if (todaysEvents.isNotEmpty) ...[
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
                  
                  // Ramadan suhoor/iftar chips
                  if (isRamadan)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ramadanChip(
                              label: 'Suhoor ends (Fajr)',
                              time: _formatTime(prayerService.fajr != null
                                  ? '${prayerService.fajr!.hour.toString().padLeft(2, '0')}:${prayerService.fajr!.minute.toString().padLeft(2, '0')}'
                                  : '--:--',
                                  Provider.of<TimeFormatSettings>(context, listen: false).is24Hour),
                              color: Colors.amber.shade200,
                            ),
                            _ramadanChip(
                              label: 'Iftar (Maghrib)',
                              time: _formatTime(prayerService.maghrib != null
                                  ? '${prayerService.maghrib!.hour.toString().padLeft(2, '0')}:${prayerService.maghrib!.minute.toString().padLeft(2, '0')}'
                                  : '--:--',
                                  Provider.of<TimeFormatSettings>(context, listen: false).is24Hour),
                              color: Colors.teal.shade200,
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  
                  // Row-based Timeline (always)
                  Consumer<TimeFormatSettings>(
                    builder: (context, timeSettings, _) => Column(
                      children: prayers.map((p) {
                        final isCurrent = prayers[currentIndex]['name'] == p['name'];
                        final theme = Theme.of(context);
                        final isDark = theme.brightness == Brightness.dark;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (isCurrent
                                    ? currentTheme.secondaryColor.withOpacity(0.18)
                                    : Colors.white.withOpacity(0.08))
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? (isCurrent ? currentTheme.secondaryColor : Colors.white).withOpacity(0.16)
                                  : Colors.black12,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p['icon'],
                                        style: TextStyle(fontSize: 18, color: isDark ? currentTheme.textColor : Colors.black),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['name'],
                                            style: TextStyle(
                                              color: isDark ? currentTheme.textColor : Colors.black,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15 * fs,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(p['time'], timeSettings.is24Hour),
                                            style: TextStyle(
                                              color: isDark ? currentTheme.textColor.withOpacity(0.8) : Colors.black87,
                                              fontSize: 13 * fs,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? currentTheme.secondaryColor.withOpacity(0.2) : Colors.black12,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Now',
                                        style: TextStyle(
                                          color: isDark ? currentTheme.textColor : Colors.black,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12 * fs,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // Show quote for current prayer
                              if (isCurrent && _currentQuote.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '"$_currentQuote"',
                                  style: TextStyle(
                                    color: isDark ? currentTheme.textColor.withOpacity(0.7) : Colors.black54,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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

  Widget _ramadanChip({required String label, required String time, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.75),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTimelinePainter extends CustomPainter {
  final double progress;
  final List<Map<String, dynamic>> prayers;
  final int currentIndex;
  final int actualCurrentIndex;
  final PrayerTheme currentTheme;

  _PrayerTimelinePainter({
    required this.progress,
    required this.prayers,
    required this.currentIndex,
    required this.actualCurrentIndex,
    required this.currentTheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double radius = 170;
    
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
