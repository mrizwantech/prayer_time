import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_time_model.dart';
import 'prayer_time_data_source.dart';

class PrayerTimeDataSourceImpl implements PrayerTimeDataSource {
  @override
  Future<PrayerTimeModel> getPrayerTimes({required double latitude, required double longitude, required DateTime date}) async {
    final params = await _getCalculationParams();
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

  /// Get calculation parameters from saved preferences
  Future<CalculationParameters> _getCalculationParams() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMethod = prefs.getString('calculation_method');
    
    if (savedMethod != null) {
      switch (savedMethod) {
        case 'muslimWorldLeague':
          return CalculationMethod.muslim_world_league.getParameters();
        case 'isna':
          return CalculationMethod.north_america.getParameters();
        case 'egyptian':
          return CalculationMethod.egyptian.getParameters();
        case 'ummAlQura':
          return CalculationMethod.umm_al_qura.getParameters();
        case 'dubai':
          return CalculationMethod.dubai.getParameters();
        case 'qatar':
          return CalculationMethod.qatar.getParameters();
        case 'kuwait':
          return CalculationMethod.kuwait.getParameters();
        case 'singapore':
          return CalculationMethod.singapore.getParameters();
        case 'karachi':
          return CalculationMethod.karachi.getParameters();
        case 'tehran':
          return CalculationMethod.tehran.getParameters();
        case 'turkey':
          return CalculationMethod.turkey.getParameters();
      }
    }
    
    // Default to ISNA for North America
    return CalculationMethod.north_america.getParameters();
  }
}
