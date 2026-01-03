import '../entities/prayer_time.dart';

abstract class PrayerTimeRepository {
  Future<PrayerTime> getPrayerTimes({required double latitude, required double longitude, required DateTime date});
}
