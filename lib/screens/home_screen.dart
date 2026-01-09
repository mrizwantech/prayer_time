import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import '../core/prayer_time_service.dart';
import '../presentation/widgets/prayer_timeline.dart';
import '../presentation/widgets/app_header.dart';
import '../core/prayer_theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri_date/hijri_date.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _countdownTimer;
  bool _bannerDismissed = false;
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerState();
    _startCountdownTimer();
    _loadRewardedAd();
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
    _rewardedAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bannerDismissed = prefs.getBool('ramadanBannerDismissed') ?? false;
    });
  }

  Future<void> _dismissBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ramadanBannerDismissed', true);
    if (mounted) {
      setState(() => _bannerDismissed = true);
    }
  }

  String get _rewardedUnitId {
    // Test IDs; replace with your real rewarded ad unit IDs when ready.
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/1712485313'
        : 'ca-app-pub-3940256099942544/5224354917';
  }

  void _loadRewardedAd() {
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
          );
          setState(() {});
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          _isRewardedLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void _showSupportAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Thanks for your support! (${reward.amount} ${reward.type})')),
          );
          _handleDuaFlow();
        },
      );
      _rewardedAd = null;
      _loadRewardedAd();
    } else {
      _loadRewardedAd();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading ad, please try again in a moment.')),
      );
    }
  }

  Future<void> _handleDuaFlow() async {
    if (!mounted) return;
    final choice = await _promptDuaSelection();
    if (choice == null || !mounted) return;
    await _showDuaForChoice(choice);
  }

  Future<String?> _promptDuaSelection() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Who do you want us to make dua for?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('Business'),
            child: const Text('Business / work'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('Mother'),
            child: const Text('Mother'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('Health'),
            child: const Text('Health'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('Family'),
            child: const Text('Family'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('Guidance'),
            child: const Text('Guidance and ease'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDuaForChoice(String choice) {
    final base = _duaFor(choice);
    final duas = List<String>.generate(10, (i) => '${i + 1}. $base');

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Making duas for $choice'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('We will make these 10 duas for you:'),
              const SizedBox(height: 8),
              ...duas.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(d),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ameen'),
          ),
        ],
      ),
    );
  }

  String _duaFor(String choice) {
    switch (choice) {
      case 'Business':
        return 'May Allah put barakah in your work, open halal opportunities, and ease your provision.';
      case 'Mother':
        return 'May Allah bless your mother with health, mercy, and Jannah, and keep her under His protection.';
      case 'Health':
        return 'May Allah grant you and your loved ones full healing, strength, and steadfast patience.';
      case 'Family':
        return 'May Allah protect your family, unite your hearts, and fill your home with mercy and peace.';
      case 'Guidance':
        return 'May Allah guide you, remove difficulties, and make the path ahead clear and beneficial.';
      default:
        return 'May Allah accept your intentions, grant you ease, and increase you in goodness.';
    }
  }

  Future<void> _onSupportPressed() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Support us'),
            content: const Text(
              'Watch a short ad to support us in building more helpful features?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Watch'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;
    _showSupportAd();
  }

  Map<String, dynamic>? _countdownTarget(PrayerTimeService service) {
    final now = DateTime.now();
    final maghrib = service.maghrib;
    final fajrToday = service.fajr;
    if (maghrib == null || fajrToday == null) return null;

    if (now.isBefore(maghrib)) {
      return {
        'label': 'Countdown to Iftar',
        'target': maghrib,
      };
    }

    // After Maghrib: countdown to next day's Fajr
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowTimes = service.getPrayerTimesForDate(tomorrow);
    final nextFajr = tomorrowTimes?['Fajr'];
    if (nextFajr != null) {
      return {
        'label': 'Countdown to Suhoor end',
        'target': nextFajr,
      };
    }
    return null;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _currentAndNext(PrayerTimeService service) {
    final now = DateTime.now();
    final ordered = <Map<String, dynamic>>[
      {'name': 'Fajr', 'time': service.fajr},
      {'name': 'Dhuhr', 'time': service.dhuhr},
      {'name': 'Asr', 'time': service.asr},
      {'name': 'Maghrib', 'time': service.maghrib},
      {'name': 'Isha', 'time': service.isha},
    ].where((e) => e['time'] != null).toList();

    if (ordered.isEmpty) return null;

    int nextIdx = ordered.indexWhere((e) => (e['time'] as DateTime).isAfter(now));
    if (nextIdx == -1) {
      // After Isha: next is tomorrow Fajr
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final tTimes = service.getPrayerTimesForDate(tomorrow);
      final nextFajr = tTimes?['Fajr'];
      final last = ordered.last;
      if (nextFajr != null) {
        return {
          'currentName': last['name'],
          'currentEndsAt': nextFajr,
          'nextName': 'Fajr',
          'nextTime': nextFajr,
        };
      }
      return null;
    }

    final next = ordered[nextIdx];
    final currentIdx = nextIdx == 0 ? ordered.length - 1 : nextIdx - 1;
    final current = ordered[currentIdx];

    final adjustedCurrentEnd = _adjustCurrentEnd(
      current['name'] as String,
      next['time'] as DateTime,
      service,
    );

    return {
      'currentName': current['name'],
      'currentEndsAt': adjustedCurrentEnd,
      'nextName': next['name'],
      'nextTime': next['time'],
    };
  }

  DateTime _adjustCurrentEnd(
    String currentName,
    DateTime nominalNext,
    PrayerTimeService service,
  ) {
    final now = DateTime.now();
    DateTime end = nominalNext;

    switch (currentName.toLowerCase()) {
      case 'fajr':
        if (service.sunrise != null) {
          end = service.sunrise!.subtract(const Duration(minutes: 10));
        }
        break;
      case 'asr':
        if (service.maghrib != null) {
          end = service.maghrib!.subtract(const Duration(minutes: 20));
        }
        break;
      case 'maghrib':
        // Maghrib window lasts 90 minutes after Maghrib
        if (service.maghrib != null) {
          end = service.maghrib!.add(const Duration(minutes: 90));
        }
        break;
      case 'isha':
        // For Isha, show time left until midnight
        final midnight = DateTime(now.year, now.month, now.day + 1);
        end = midnight;
        break;
      default:
        end = nominalNext;
    }

    if (!end.isAfter(now)) {
      // Fallback to nominal next if adjusted time already passed
      end = nominalNext;
    }

    return end;
  }

  Map<String, dynamic>? _nextPrayerInfo(PrayerTimeService service) {
    final now = DateTime.now();
    final today = <Map<String, dynamic>>[
      {'name': 'Fajr', 'time': service.fajr},
      {'name': 'Dhuhr', 'time': service.dhuhr},
      {'name': 'Asr', 'time': service.asr},
      {'name': 'Maghrib', 'time': service.maghrib},
      {'name': 'Isha', 'time': service.isha},
    ].where((e) => e['time'] != null).toList();

    for (final p in today) {
      if ((p['time'] as DateTime).isAfter(now)) {
        return {'name': p['name'], 'time': p['time']};
      }
    }

    // After Isha: use tomorrow's Fajr
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tTimes = service.getPrayerTimesForDate(tomorrow);
    if (tTimes != null && tTimes['Fajr'] != null) {
      return {'name': 'Fajr', 'time': tTimes['Fajr']};
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerTimeService>(
      builder: (context, prayerService, child) {
        final themeProvider = Provider.of<PrayerThemeProvider>(context);
        final currentPrayer = prayerService.getCurrentPrayerName();
        final theme = themeProvider.getCurrentTheme(currentPrayer);
        final isRamadan = themeProvider.isRamadan;
        final hijri = HijriDate.now();
        final bannerDay = hijri.hDay;
        final daysInMonth = hijri.lengthOfMonth;
        final countdown = _countdownTarget(prayerService);
        final nextPrayer = _nextPrayerInfo(prayerService);
        final currentNext = _currentAndNext(prayerService);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.backgroundGradient,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // App Header with Location and Refresh
                AppHeader(
                  city: prayerService.city,
                  state: prayerService.state,
                  isLoading: prayerService.isLoading,
                  onRefresh: () => prayerService.refresh(),
                  showLocation: true,
                  showSupport: true,
                  onSupport: _onSupportPressed,
                ),
                if (isRamadan && !_bannerDismissed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Material(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: Text(
                          'Ramadan Kareem – Day $bannerDay of $daysInMonth',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        subtitle: Text(
                          'May your fast be accepted',
                          style: TextStyle(color: Colors.white.withOpacity(0.85)),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: _dismissBanner,
                        ),
                      ),
                    ),
                  ),

                if (isRamadan && countdown != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container
                    (
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                countdown['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('hh:mm a').format(countdown['target'] as DateTime),
                                style: TextStyle(color: Colors.white.withOpacity(0.85)),
                              ),
                            ],
                          ),
                          Text(
                            _formatDuration((countdown['target'] as DateTime).difference(DateTime.now())),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!isRamadan && currentNext != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _currentNextCard(currentNext),
                  )
                else if (!isRamadan && nextPrayer != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _nextPrayerCard(nextPrayer),
                  ),

                // Prayer Timeline
                const Expanded(
                  child: SingleChildScrollView(
                    child: PrayerTimeline(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _currentNextCard(Map<String, dynamic> data) {
    final currentName = data['currentName'] as String;
    final currentEndsAt = data['currentEndsAt'] as DateTime;
    final nextName = data['nextName'] as String;
    final nextTime = data['nextTime'] as DateTime;

    final currentRemaining = currentEndsAt.difference(DateTime.now());
    final nextRemaining = nextTime.difference(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time left in $currentName',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(currentRemaining),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Next: $nextName',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(nextRemaining),
                    style: TextStyle(color: Colors.amber.shade100, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('hh:mm a').format(currentEndsAt),
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              Text(
                DateFormat('hh:mm a').format(nextTime),
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nextPrayerCard(Map<String, dynamic> nextPrayer) {
    final name = nextPrayer['name'] as String;
    final time = nextPrayer['time'] as DateTime;
    final remaining = time.difference(DateTime.now());

    Duration window;
    switch (name.toLowerCase()) {
      case 'fajr':
        window = const Duration(minutes: 10);
        break;
      case 'asr':
        window = const Duration(minutes: 20);
        break;
      case 'maghrib':
        window = const Duration(minutes: 90);
        break;
      default:
        window = Duration.zero;
    }

    final isPreWindow = remaining <= window;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next: $name',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('hh:mm a').format(time),
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              if (isPreWindow && window > Duration.zero)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Pre-window (${window.inMinutes} min)',
                    style: TextStyle(color: Colors.amber.shade200, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          Text(
            _formatDuration(remaining),
            style: TextStyle(
              color: isPreWindow ? Colors.amber.shade100 : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

