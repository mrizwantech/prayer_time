import 'package:adhan/adhan.dart';
import '../models/prayer_time_model.dart';
import 'prayer_time_data_source.dart';

class PrayerTimeDataSourceImpl implements PrayerTimeDataSource {
  @override
  Future<PrayerTimeModel> getPrayerTimes({required double latitude, required double longitude, required DateTime date}) async {
    final params = CalculationMethod.muslim_world_league.getParameters();
    final coordinates = Coordinates(latitude, longitude);
    final dateComponents = DateComponents(date.year, date.month, date.day);
    final prayerTimes = PrayerTimes(coordinates, dateComponents, params);
    return PrayerTimeModel(
      fajr: prayerTimes.fajr,
      dhuhr: prayerTimes.dhuhr,
      asr: prayerTimes.asr,
      maghrib: prayerTimes.maghrib,
      isha: prayerTimes.isha,
    );
  }
}
