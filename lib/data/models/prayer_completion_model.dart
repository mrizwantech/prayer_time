class PrayerCompletionModel {
  final String dateString; // Format: yyyy-MM-dd
  final Map<String, bool> prayers;

  PrayerCompletionModel({
    required this.dateString,
    required this.prayers,
  });

  factory PrayerCompletionModel.fromJson(Map<String, dynamic> json) {
    return PrayerCompletionModel(
      dateString: json['date'] as String,
      prayers: Map<String, bool>.from(json['prayers'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': dateString,
      'prayers': prayers,
    };
  }
}
