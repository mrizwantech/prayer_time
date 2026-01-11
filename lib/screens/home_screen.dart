import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import '../core/prayer_time_service.dart';
import '../presentation/widgets/prayer_timeline.dart';
import '../presentation/widgets/app_header.dart';
import '../core/prayer_theme_provider.dart';
import '../core/quran_api_client.dart';
import 'quran_surah_screen.dart';
import 'dua_generator_screen.dart';
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
  SurahSummary? _lastReadSurah;
  int? _lastReadAyah;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerState();
    _loadLastReadQuran();
    _startCountdownTimer();
    _loadRewardedAd();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 App resumed');
      // Always ensure next prayer is scheduled when app is opened
      final prayerService = Provider.of<PrayerTimeService>(context, listen: false);
      prayerService.ensureNextPrayerScheduled();
      // Restart countdown timer
      _startCountdownTimer();
    }
  }
  
  bool get _isAppInForeground => _lifecycleState == AppLifecycleState.resumed;
  
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

  Future<void> _loadLastReadQuran() async {
    final prefs = await SharedPreferences.getInstance();
    final surahNumber = prefs.getInt('last_read_surah');
    final ayahNumber = prefs.getInt('last_read_ayah');
    if (surahNumber == null || ayahNumber == null) {
      if (mounted) {
        setState(() {
          _lastReadSurah = null;
          _lastReadAyah = null;
        });
      }
      return;
    }

    final nameEn = prefs.getString('last_read_surah_name_en') ?? 'Surah $surahNumber';
    final nameAr = prefs.getString('last_read_surah_name_ar') ?? '';
    final ayahCount = prefs.getInt('last_read_surah_ayah_count') ?? 0;
    final revelation = prefs.getString('last_read_surah_revelation') ?? 'Meccan';

    final summary = SurahSummary(
      number: surahNumber,
      nameArabic: nameAr,
      nameEnglish: nameEn,
      ayahCount: ayahCount,
      revelationType: revelation,
    );

    if (mounted) {
      setState(() {
        _lastReadSurah = summary;
        _lastReadAyah = ayahNumber;
      });
    }
  }

  // Set to true to use Google test ads (for debugging decoder issues)
  static const bool _useTestAds = false;

  String get _rewardedUnitId {
    if (_useTestAds) {
      // Google test rewarded ad (always works, no decoder issues)
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    // Real ad unit IDs
    return Platform.isIOS
        ? 'ca-app-pub-3940256099942544/1712485313' // TODO: Add iOS rewarded ad unit ID
        : 'ca-app-pub-5118580699569063/7195644830';
  }

  void _loadRewardedAd() {
    if (_isRewardedLoading || _rewardedAd != null || !mounted) return;
    _isRewardedLoading = true;
    debugPrint('📺 Loading rewarded ad...');

    RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          debugPrint('✅ Rewarded ad loaded successfully');
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
          );
          setState(() {});
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded ad failed to load: ${error.code} - ${error.message}');
          _isRewardedLoading = false;
          _rewardedAd = null;
          // Retry after delay - longer delay for repeated failures
          final retryDelay = error.code == 0 ? 60 : 30; // Internal error = longer wait
          Future.delayed(Duration(seconds: retryDelay), () {
            if (mounted) _loadRewardedAd();
          });
        },
      ),
    );
  }

  void _showSupportAd() {
    // Check if app is in foreground - AdMob requires this
    if (!_isAppInForeground) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please unlock your device to watch the ad.')),
      );
      return;
    }

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
    // Navigate to the Dynamic Dua Generator screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DuaGeneratorScreen()),
    );
  }

  void _resumeQuran() {
    if (_lastReadSurah == null) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => QuranSurahScreen(summary: _lastReadSurah!)))
        .then((_) => _loadLastReadQuran());
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
        final midnight = DateTime(now.year, now.month, now.day + 1);
        final end = nextFajr.isBefore(midnight) ? nextFajr : midnight;
        return {
          'currentName': last['name'],
          'currentEndsAt': end,
          'nextName': 'Fajr',
          'nextTime': nextFajr,
        };
      }
      // If no Fajr time, at least show until midnight
      final fallbackMidnight = DateTime(now.year, now.month, now.day + 1);
      return {
        'currentName': last['name'],
        'currentEndsAt': fallbackMidnight,
        'nextName': 'Fajr',
        'nextTime': fallbackMidnight,
      };
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
      case 'dhuhr':
        if (service.asr != null) {
          end = service.asr!.subtract(const Duration(minutes: 5));
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
        // For Isha, show time left until midnight or next Fajr (whichever is sooner)
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final tomorrowTimes = service.getPrayerTimesForDate(tomorrow);
        final nextFajr = tomorrowTimes?['Fajr'];
        final midnight = DateTime(now.year, now.month, now.day + 1);
        if (nextFajr != null) {
          end = nextFajr.isBefore(midnight) ? nextFajr : midnight;
        } else {
          end = midnight;
        }
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
                if (_lastReadSurah != null && _lastReadAyah != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF2DD4BF), Color(0xFF14B8A6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.bookmark_added, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Continue Quran',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.92),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_lastReadSurah!.number}. ${_lastReadSurah!.nameEnglish}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                                ),
                                Text(
                                  'Start at ayah $_lastReadAyah',
                                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _resumeQuran,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent.shade400,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Resume'),
                          ),
                        ],
                      ),
                    ),
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
      case 'dhuhr':
        window = const Duration(minutes: 5);
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

