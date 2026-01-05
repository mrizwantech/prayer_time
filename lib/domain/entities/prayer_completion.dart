class PrayerCompletion {
  final DateTime date;
  final Map<String, bool> prayers; // Prayer name -> completion status

  PrayerCompletion({
    required this.date,
    required this.prayers,
  });

  PrayerCompletion copyWith({
    DateTime? date,
    Map<String, bool>? prayers,
  }) {
    return PrayerCompletion(
      date: date ?? this.date,
      prayers: prayers ?? this.prayers,
    );
  }

  // Get completion percentage for the day
  double get completionPercentage {
    final total = prayers.length;
    final completed = prayers.values.where((v) => v).length;
    return total > 0 ? (completed / total) * 100 : 0;
  }

  // Check if all prayers are completed
  bool get isComplete {
    return prayers.values.every((v) => v);
  }
}
