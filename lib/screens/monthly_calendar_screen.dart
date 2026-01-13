import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hijri_date/hijri_date.dart';

import '../core/prayer_time_service.dart';
import '../core/time_format_settings.dart';
import '../presentation/widgets/app_header.dart';
import '../main.dart';

class MonthlyCalendarScreen extends StatefulWidget {
  const MonthlyCalendarScreen({super.key});

  @override
  State<MonthlyCalendarScreen> createState() => _MonthlyCalendarScreenState();
}

Widget _infoChip(String label, DateTime time, bool is24, Color color) {
  final formatted = is24 ? DateFormat('HH:mm').format(time) : DateFormat('hh:mm a').format(time);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black.withOpacity(0.8)),
        ),
        const SizedBox(width: 6),
        Text(
          formatted,
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.75)),
        ),
      ],
    ),
  );
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  Map<String, DateTime>? _selectedTimes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
    _loadTimesFor(_selectedDate);
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
      _selectedDate = _focusedMonth;
      _loadTimesFor(_selectedDate);
    });
  }

  void _loadTimesFor(DateTime date) {
    final prayerService = Provider.of<PrayerTimeService>(context, listen: false);
    _selectedTimes = prayerService.getPrayerTimesForDate(date);
  }

  String _formatTime(DateTime time, bool is24Hour) {
    if (is24Hour) {
      return DateFormat('HH:mm').format(time);
    }
    return DateFormat('hh:mm a').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final prayerService = Provider.of<PrayerTimeService>(context);
    final timeSettings = Provider.of<TimeFormatSettings>(context);
    final theme = Theme.of(context);

    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1=Mon
    final cells = <DateTime?>[];
    final leadingEmpty = (firstWeekday % 7); // make Sunday=0
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(null);
    }
    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, day));
    }

    final hijriMonth = HijriDate.fromDate(_focusedMonth);

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 28),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Column(
                    children: [
                      Text(
                        DateFormat('MMMM yyyy').format(_focusedMonth),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${hijriMonth.toFormat('MMMM')} ${hijriMonth.hYear}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 28),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Text('Sun', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Mon', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Tue', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Wed', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Thu', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Fri', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Sat', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: GridView.builder(
                  itemCount: cells.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    final date = cells[index];
                    if (date == null) {
                      return const SizedBox.shrink();
                    }
                    final isToday = DateUtils.isSameDay(date, DateTime.now());
                    final isSelected = DateUtils.isSameDay(date, _selectedDate);
                    final hijri = HijriDate.fromDate(date);
                    final isHijriMonthStart = hijri.hDay == 1;
                    final isHijriDay20 = hijri.hDay == 20;
                    final isRamadanDay = hijri.hMonth == 9;
                    final ramadanTimes = isRamadanDay
                        ? prayerService.getPrayerTimesForDate(date)
                        : null;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                          _loadTimesFor(date);
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.teal.shade600
                              : isToday
                                  ? Colors.teal.shade100
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Colors.teal.shade800
                                : isRamadanDay
                                    ? Colors.amber.shade500
                                    : isHijriMonthStart
                                        ? Colors.amber.shade600
                                        : isHijriDay20
                                            ? Colors.teal.shade400
                                            : Colors.grey.shade300,
                            width: isSelected || isRamadanDay || isHijriMonthStart ? 1.6 : 1,
                          ),
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                            ? Colors.teal.shade900
                                            : Colors.grey.shade800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${hijri.hDay}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.85)
                                        : isHijriMonthStart
                                            ? Colors.amber.shade700
                                            : Colors.grey.shade600,
                                  ),
                                ),
                                if (isHijriMonthStart || isHijriDay20 || isRamadanDay)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (hijri.hDay == 1)
                                          Icon(Icons.nightlight_round, size: 14, color: Colors.amber.shade700)
                                        else if (hijri.hDay == 27)
                                          Icon(Icons.emoji_objects, size: 14, color: Colors.orange.shade700)
                                        else
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: isRamadanDay
                                                  ? Colors.amber.shade600
                                                  : isHijriMonthStart
                                                      ? Colors.amber.shade600
                                                      : Colors.teal.shade500,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: _selectedTimes == null
                  ? Text(
                      'Prayer times unavailable for this date. Ensure location is set.',
                      style: TextStyle(color: Colors.grey.shade700),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prayer times for ${DateFormat('EEE, MMM d, yyyy').format(_selectedDate)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Hijri: ${HijriDate.fromDate(_selectedDate).toFormat('dd MMMM yyyy')}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        if (HijriDate.fromDate(_selectedDate).hMonth == 9)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _infoChip('Suhoor ends (Fajr)', _selectedTimes!['Fajr']!, timeSettings.is24Hour, Colors.amber.shade200),
                              _infoChip('Iftar (Maghrib)', _selectedTimes!['Maghrib']!, timeSettings.is24Hour, Colors.teal.shade200),
                            ],
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _selectedTimes!.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    e.key,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTime(e.value, timeSettings.is24Hour),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 6, // Settings tab for calendar
        onTap: (idx) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainNavigation(initialIndex: idx)),
          );
        },
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.5),
        type: BottomNavigationBarType.fixed,
        backgroundColor: theme.colorScheme.surface,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Quran'),
          BottomNavigationBarItem(icon: Icon(Icons.radio_button_checked), label: 'Tasbeeh'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Qibla'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Rakat'),
          BottomNavigationBarItem(icon: Icon(Icons.brush), label: 'Posts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
