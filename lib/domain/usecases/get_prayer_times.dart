import '../entities/prayer_time.dart';
import '../repositories/prayer_time_repository.dart';

class GetPrayerTimes {
  final PrayerTimeRepository repository;
  GetPrayerTimes(this.repository);

  Future<PrayerTime> call({required double latitude, required double longitude, required DateTime date}) {
    return repository.getPrayerTimes(latitude: latitude, longitude: longitude, date: date);
  }
}
