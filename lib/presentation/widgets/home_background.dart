import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/prayer_theme_provider.dart';
import '../../core/prayer_time_service.dart';

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prayerService = context.watch<PrayerTimeService>();
    final theme = context.watch<PrayerThemeProvider>().getCurrentTheme(
      prayerService.getCurrentPrayerName(),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.backgroundGradient,
        ),
        image: DecorationImage(
          image: AssetImage(
            isDark
                ? 'assets/images/home_bg_dark.png'
                : 'assets/images/home_bg_light.png',
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(isDark ? 0.30 : 0.25),
            BlendMode.darken,
          ),
        ),
      ),
      child: child,
    );
  }
}
