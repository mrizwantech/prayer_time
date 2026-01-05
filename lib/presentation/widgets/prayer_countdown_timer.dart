import 'package:flutter/material.dart';
import 'dart:async';

class PrayerCountdownTimer extends StatefulWidget {
  final DateTime nextPrayerTime;
  final String nextPrayerName;
  final Color? textColor;
  final double? fontSize;

  const PrayerCountdownTimer({
    Key? key,
    required this.nextPrayerTime,
    required this.nextPrayerName,
    this.textColor,
    this.fontSize,
  }) : super(key: key);

  @override
  State<PrayerCountdownTimer> createState() => _PrayerCountdownTimerState();
}

class _PrayerCountdownTimerState extends State<PrayerCountdownTimer> {
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  bool _isPrayerTimeEnding = false;

  @override
  void initState() {
    super.initState();
    _updateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining();
    });
  }

  @override
  void didUpdateWidget(PrayerCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextPrayerTime != widget.nextPrayerTime) {
      _updateTimeRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeRemaining() {
    final now = DateTime.now();
    final remaining = widget.nextPrayerTime.difference(now);

    if (mounted) {
      setState(() {
        _timeRemaining = remaining;
        // Mark as ending if less than 5 minutes left
        _isPrayerTimeEnding = remaining.inMinutes < 5 && remaining.inSeconds > 0;
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00:00';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.textColor ?? Colors.white;
    final warningColor = _isPrayerTimeEnding ? Colors.orange : defaultColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isPrayerTimeEnding)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Prayer time ending soon!',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Text(
          _formatDuration(_timeRemaining),
          style: TextStyle(
            color: warningColor,
            fontSize: widget.fontSize ?? 36,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
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
  }
}
