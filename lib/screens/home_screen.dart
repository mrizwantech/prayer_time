import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import '../data/datasources/prayer_time_data_source_impl.dart';
import '../data/repositories/prayer_time_repository_impl.dart';
import '../domain/usecases/get_prayer_times.dart';
import '../domain/entities/prayer_time.dart';
import 'package:provider/provider.dart';
import '../core/time_format_settings.dart';
import '../core/location_provider.dart';
import '../presentation/widgets/digital_prayer_clock.dart';
import '../presentation/widgets/prayer_timeline.dart';
import '../presentation/widgets/app_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _countdownTimer;
  String? _city;
  String? _state;
  PrayerTime? _prayerTime;
  bool _loading = false;  // Start with false, check cache first
  String? _error;
  String? _nextPrayerName;
  Duration? _nextPrayerCountdown;
  final List<String> _prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  
  // Static cache to preserve data across navigation
  static PrayerTime? _cachedPrayerTime;
  static String? _cachedCity;
  static String? _cachedState;
  static DateTime? _cacheDate;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  void _initializeData() {
    // Check if we have cached data from today - SYNC, no setState needed
    final now = DateTime.now();
    if (_cachedPrayerTime != null && 
        _cacheDate != null && 
        _cacheDate!.year == now.year &&
        _cacheDate!.month == now.month &&
        _cacheDate!.day == now.day) {
      // Use cached data - instant load, no async needed
      _prayerTime = _cachedPrayerTime;
      _city = _cachedCity;
      _state = _cachedState;
      _loading = false;
      // Schedule update after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateNextPrayer();
      });
    } else {
      // Need to fetch - show loading
      _loading = true;
      _fetchPrayerTimes();
    }
  }

  Future<void> _fetchPrayerTimes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }
      
      // Try last known position first for faster load
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      
      final double latitude = position.latitude;
      final double longitude = position.longitude;
      
      // Fetch prayer times first (don't wait for geocoding)
      final date = DateTime.now();
      final dataSource = PrayerTimeDataSourceImpl();
      final repository = PrayerTimeRepositoryImpl(dataSource);
      final getPrayerTimes = GetPrayerTimes(repository);
      final result = await getPrayerTimes(latitude: latitude, longitude: longitude, date: date);
      
      // Cache prayer results immediately
      _cachedPrayerTime = result;
      _cacheDate = DateTime.now();
      
      setState(() {
        _prayerTime = result;
        _loading = false;
      });
      _updateNextPrayer();
      
      // Fetch location in parallel (fire-and-forget to avoid blocking)
      _fetchCityState(latitude, longitude).then((_) {
        // Update cache after geocoding completes
        _cachedCity = _city;
        _cachedState = _state;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchCityState(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      debugPrint('🌍 Geocoding results: ${placemarks.length} placemarks found');
      if (placemarks.isNotEmpty) {
        final mark = placemarks.first;
        debugPrint('📍 City: ${mark.locality}, State: ${mark.administrativeArea}');
        setState(() {
          _city = mark.locality ?? mark.subAdministrativeArea;
          _state = mark.administrativeArea;
        });
      }
    } catch (e) {
      debugPrint('❌ Geocoding error: $e');
    }
  }

  void _updateNextPrayer() {
    if (_prayerTime == null) return;
    final now = DateTime.now();
    final times = [
      _prayerTime!.fajr,
      _prayerTime!.dhuhr,
      _prayerTime!.asr,
      _prayerTime!.maghrib,
      _prayerTime!.isha,
    ];
    for (int i = 0; i < times.length; i++) {
      if (now.isBefore(times[i])) {
        setState(() {
          _nextPrayerName = _prayerNames[i];
          _nextPrayerCountdown = times[i].difference(now);
        });
        _startCountdown(times[i]);
        return;
      }
    }
    setState(() {
      _nextPrayerName = _prayerNames[0];
      _nextPrayerCountdown = times[0].add(const Duration(days: 1)).difference(now);
    });
    _startCountdown(times[0].add(const Duration(days: 1)));
  }

  void _startCountdown(DateTime nextPrayerTime) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      _updateNextPrayer();
    });
  }
  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(duration.inHours);
    final m = twoDigits(duration.inMinutes.remainder(60));
    final s = twoDigits(duration.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  List<PrayerBlock> _getPrayerBlocks(bool is24Hour) {
    if (_prayerTime == null) return [];
    final times = [
      _prayerTime!.fajr,
      _prayerTime!.dhuhr,
      _prayerTime!.asr,
      _prayerTime!.maghrib,
      _prayerTime!.isha,
    ];
    final names = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final icons = [
      Icons.wb_twighlight,
      Icons.wb_sunny,
      Icons.wb_cloudy,
      Icons.nights_stay,
      Icons.nightlight_round,
    ];
    final gradients = [
      [const Color(0xFF00BFA6), const Color(0xFF43E97B)],
      [const Color(0xFFFFC107), const Color(0xFFFFE082)],
      [const Color(0xFF29B6F6), const Color(0xFF6DD5FA)],
      [const Color(0xFFFF7043), const Color(0xFFFFA726)],
      [const Color(0xFF7C4DFF), const Color(0xFFB388FF)],
    ];
    final gradientsActive = [
      [const Color(0xFF00BFA6), const Color(0xFF1DE9B6)],
      [const Color(0xFFFFC107), const Color(0xFFFFD54F)],
      [const Color(0xFF29B6F6), const Color(0xFF00E5FF)],
      [const Color(0xFFFF7043), const Color(0xFFFF8A65)],
      [const Color(0xFF7C4DFF), const Color(0xFF651FFF)],
    ];
    List<PrayerBlock> blocks = [];
    for (int i = 0; i < 5; i++) {
      final start = times[i];
      final end = times[(i + 1) % 5];
      blocks.add(PrayerBlock(
        name: names[i],
        startTime: is24Hour ? _format24Hour(start) : _format12Hour(start),
        endTime: is24Hour ? _format24Hour(end) : _format12Hour(end),
        icon: icons[i],
        gradient: gradients[i],
        gradientActive: gradientsActive[i],
      ));
    }
    return blocks;
  }

  String _format24Hour(DateTime t) {
    String hour = t.hour.toString().padLeft(2, '0');
    String minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _getActivePrayerIndex() {
    if (_prayerTime == null) return 0;
    final now = DateTime.now();
    final times = [
      _prayerTime!.fajr,
      _prayerTime!.dhuhr,
      _prayerTime!.asr,
      _prayerTime!.maghrib,
      _prayerTime!.isha,
    ];
    for (int i = 0; i < times.length; i++) {
      final next = times[(i + 1) % times.length];
      if (now.isAfter(times[i]) && now.isBefore(next)) {
        return i;
      }
    }
    if (now.isAfter(times.last)) return times.length - 1;
    return 0;
  }

  String _format12Hour(DateTime t) {
    int hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    String period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${t.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final is24Hour = Provider.of<TimeFormatSettings>(context).is24Hour;
    final locationProvider = Provider.of<LocationProvider>(context);
    
    return SafeArea(
      child: Column(
        children: [
          // App Header with Location and Refresh
          AppHeader(
            city: locationProvider.city ?? _city,
            state: locationProvider.state ?? _state,
            isLoading: locationProvider.isLoading || _loading,
            onRefresh: () async {
              await locationProvider.refreshLocation();
              await _refreshLocation();
            },
            showLocation: true,
          ),
          // Prayer Timeline
          Expanded(
            child: SingleChildScrollView(
              child: const PrayerTimeline(),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _refreshLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Clear cache to force fresh fetch
      _cacheDate = null;
      
      // Get fresh location
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      
      final double latitude = position.latitude;
      final double longitude = position.longitude;
      
      // Fetch new location info
      await _fetchCityState(latitude, longitude);
      
      // Fetch new prayer times
      final date = DateTime.now();
      final dataSource = PrayerTimeDataSourceImpl();
      final repository = PrayerTimeRepositoryImpl(dataSource);
      final getPrayerTimes = GetPrayerTimes(repository);
      final result = await getPrayerTimes(latitude: latitude, longitude: longitude, date: date);
      
      // Update cache
      _cachedPrayerTime = result;
      _cachedCity = _city;
      _cachedState = _state;
      _cacheDate = DateTime.now();
      
      setState(() {
        _prayerTime = result;
        _loading = false;
      });
      
      // Trigger prayer timeline refresh
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      _updateNextPrayer();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
