import 'package:flutter/material.dart';
import '../presentation/widgets/streak_tracker_widget.dart';
import '../presentation/widgets/celebration_overlay.dart';
import '../core/prayer_tracking_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _trackingService = PrayerTrackingService();
  bool _shouldCelebrate = false;
  List<String> _previousBadges = [];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final badges = await _trackingService.getUnlockedBadges();
    setState(() {
      _previousBadges = List.from(badges);
    });
  }

  Future<void> _checkForNewBadges() async {
    final currentBadges = await _trackingService.getUnlockedBadges();
    if (currentBadges.length > _previousBadges.length) {
      setState(() {
        _shouldCelebrate = true;
      });
    }
  }

  void _onCelebrationEnd() {
    setState(() {
      _shouldCelebrate = false;
    });
    _loadBadges();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CelebrationOverlay(
          shouldCelebrate: _shouldCelebrate,
          onCelebrationEnd: _onCelebrationEnd,
          child: SingleChildScrollView(
            child: StreakTrackerWidget(),
          ),
        ),
      ),
    );
  }
}
