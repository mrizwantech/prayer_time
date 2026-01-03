
import 'package:flutter/material.dart';
import '../data/datasources/prayer_time_data_source_impl.dart';
import '../data/repositories/prayer_time_repository_impl.dart';
import '../domain/usecases/get_prayer_times.dart';
import '../domain/entities/prayer_time.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTime? _prayerTime;
  bool _loading = true;
  String? _error;

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
      // Example coordinates (Mecca)
      const double latitude = 21.3891;
      const double longitude = 39.8579;
      final date = DateTime.now();
      final dataSource = PrayerTimeDataSourceImpl();
      final repository = PrayerTimeRepositoryImpl(dataSource);
      final getPrayerTimes = GetPrayerTimes(repository);
      final result = await getPrayerTimes(latitude: latitude, longitude: longitude, date: date);
      setState(() {
        _prayerTime = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _prayerTime == null
                  ? const Center(child: Text('No data'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fajr:    ${_prayerTime!.fajr}'),
                          Text('Dhuhr:   ${_prayerTime!.dhuhr}'),
                          Text('Asr:     ${_prayerTime!.asr}'),
                          Text('Maghrib: ${_prayerTime!.maghrib}'),
                          Text('Isha:    ${_prayerTime!.isha}'),
                        ],
                      ),
                    ),
    );
  }
}
