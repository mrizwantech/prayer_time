import '../../domain/entities/prayer_time.dart';

class PrayerTimeModel extends PrayerTime {
  PrayerTimeModel({
    required DateTime fajr,
    required DateTime dhuhr,
    required DateTime asr,
    required DateTime maghrib,
    required DateTime isha,
  }) : super(
          fajr: fajr,
          dhuhr: dhuhr,
          asr: asr,
          maghrib: maghrib,
          isha: isha,
        );

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
