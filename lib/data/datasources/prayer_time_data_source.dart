import '../models/prayer_time_model.dart';

abstract class PrayerTimeDataSource {
  Future<PrayerTimeModel> getPrayerTimes({required double latitude, required double longitude, required DateTime date});
}
