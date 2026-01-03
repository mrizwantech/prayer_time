import '../../domain/entities/prayer_time.dart';
import '../../domain/repositories/prayer_time_repository.dart';
import '../datasources/prayer_time_data_source.dart';

class PrayerTimeRepositoryImpl implements PrayerTimeRepository {
  final PrayerTimeDataSource dataSource;
  PrayerTimeRepositoryImpl(this.dataSource);

  @override
  Future<PrayerTime> getPrayerTimes({required double latitude, required double longitude, required DateTime date}) {
    return dataSource.getPrayerTimes(latitude: latitude, longitude: longitude, date: date);
  }
}
