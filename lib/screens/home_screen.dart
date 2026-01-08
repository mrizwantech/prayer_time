import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../core/prayer_time_service.dart';
import '../presentation/widgets/prayer_timeline.dart';
import '../presentation/widgets/app_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCountdownTimer();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed');
      // Check if we need to reschedule (new day or after Isha)
      final prayerService = Provider.of<PrayerTimeService>(context, listen: false);
      if (prayerService.needsReschedule()) {
        debugPrint('📅 New day detected - rescheduling notifications');
        prayerService.rescheduleIfNeeded();
      }
      // Restart countdown timer
      _startCountdownTimer();
    }
  }
  
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerTimeService>(
      builder: (context, prayerService, child) {
        return SafeArea(
          child: Column(
            children: [
              // App Header with Location and Refresh
              AppHeader(
                city: prayerService.city,
                state: prayerService.state,
                isLoading: prayerService.isLoading,
                onRefresh: () => prayerService.refresh(),
                showLocation: true,
              ),
              // Prayer Timeline
              const Expanded(
                child: SingleChildScrollView(
                  child: PrayerTimeline(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

