import 'package:flutter/material.dart';


class DigitalPrayerClock extends StatelessWidget {
  final List<PrayerBlock> prayers;
  final int activeIndex;
  final bool is24Hour;

  const DigitalPrayerClock({
    super.key,
    required this.prayers,
    required this.activeIndex,
    required this.is24Hour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Prayer Times',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(prayers.length, (i) {
            final p = prayers[i];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: i == activeIndex
                      ? p.gradientActive
                      : p.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: i == activeIndex
                    ? [
                        BoxShadow(
                          color: p.gradientActive.first.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                leading: Icon(p.icon, color: Colors.white, size: 32),
                title: Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  '${p.startTime} – ${p.endTime}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
                trailing: i == activeIndex
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class PrayerBlock {
  final String name;
  final String startTime;
  final String endTime;
  final IconData icon;
  final List<Color> gradient;
  final List<Color> gradientActive;

  PrayerBlock({
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.icon,
    required this.gradient,
    required this.gradientActive,
  });
}
