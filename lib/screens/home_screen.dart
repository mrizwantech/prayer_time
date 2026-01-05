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
import '../presentation/widgets/digital_prayer_clock.dart';
import '../presentation/widgets/prayer_timeline.dart';
import 'package:provider/provider.dart';

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
  bool _loading = true;
  String? _error;
  String? _nextPrayerName;
  Duration? _nextPrayerCountdown;
  final List<String> _prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
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
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final double latitude = position.latitude;
      final double longitude = position.longitude;
      await _fetchCityState(latitude, longitude);
      final date = DateTime.now();
      final dataSource = PrayerTimeDataSourceImpl();
      final repository = PrayerTimeRepositoryImpl(dataSource);
      final getPrayerTimes = GetPrayerTimes(repository);
      final result = await getPrayerTimes(latitude: latitude, longitude: longitude, date: date);
      setState(() {
        _prayerTime = result;
        _loading = false;
      });
      _updateNextPrayer();
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
      if (placemarks.isNotEmpty) {
        setState(() {
          _city = placemarks.first.locality;
          _state = placemarks.first.administrativeArea;
        });
      }
    } catch (e) {
      // Ignore geocoding errors for now
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
    return const SafeArea(
      child: SingleChildScrollView(
        child: PrayerTimeline(),
      ),
    );
  }
}
