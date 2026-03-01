import '../../domain/entities/prayer_time.dart';

class PrayerTimeModel extends PrayerTime {
  PrayerTimeModel({
    required super.fajr,
    required super.dhuhr,
    required super.asr,
    required super.maghrib,
    required super.isha,
  });

  factory PrayerTimeModel.fromMap(Map<String, DateTime> map) {
    return PrayerTimeModel(
      fajr: map['fajr']!,
      dhuhr: map['dhuhr']!,
      asr: map['asr']!,
      maghrib: map['maghrib']!,
      isha: map['isha']!,
    );
  }
}
