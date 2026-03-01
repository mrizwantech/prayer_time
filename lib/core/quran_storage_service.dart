import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_api_client.dart';

class QuranStorageService {
  static const String _savedSurahsKey = 'saved_surahs';

  /// Save a surah detail to local storage
  Future<void> saveSurah(int surahNumber, SurahDetail detail) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedSurahsKey) ?? [];
    
    // Convert surah detail to JSON (manual serialization)
    final json = _surahDetailToJson(detail);
    final key = _getSurahKey(surahNumber);
    
    // Add to list if not already saved
    if (!saved.contains(surahNumber.toString())) {
      saved.add(surahNumber.toString());
      await prefs.setStringList(_savedSurahsKey, saved);
    }
    
    // Save the detail
    await prefs.setString(key, jsonEncode(json));
  }

  /// Get a saved surah from local storage (null if not saved)
  Future<SurahDetail?> getSavedSurah(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getSurahKey(surahNumber);
    final jsonStr = prefs.getString(key);
    
    if (jsonStr == null) return null;
    
    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _surahDetailFromJson(json);
    } catch (e) {
      debugPrint('Error parsing saved surah: $e');
      return null;
    }
  }

  /// Check if a surah is saved
  Future<bool> isSurahSaved(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedSurahsKey) ?? [];
    return saved.contains(surahNumber.toString());
  }

  /// Get list of all saved surah numbers
  Future<List<int>> getSavedSurahNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedSurahsKey) ?? [];
    return saved.map((s) => int.parse(s)).toList();
  }

  /// Delete a saved surah
  Future<void> deleteSavedSurah(int surahNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_savedSurahsKey) ?? [];
    
    saved.removeWhere((s) => s == surahNumber.toString());
    await prefs.setStringList(_savedSurahsKey, saved);
    
    final key = _getSurahKey(surahNumber);
    await prefs.remove(key);
  }

  // Private helper methods
  String _getSurahKey(int surahNumber) => 'surah_$surahNumber';

  Map<String, dynamic> _surahDetailToJson(SurahDetail detail) {
    return {
      'summary': {
        'number': detail.summary.number,
        'nameArabic': detail.summary.nameArabic,
        'nameEnglish': detail.summary.nameEnglish,
        'ayahCount': detail.summary.ayahCount,
        'revelationType': detail.summary.revelationType,
      },
      'ayahs': detail.ayahs.map((ayah) => _ayahToJson(ayah)).toList(),
    };
  }

  SurahDetail _surahDetailFromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>;
    final summary = SurahSummary(
      number: summaryJson['number'],
      nameArabic: summaryJson['nameArabic'],
      nameEnglish: summaryJson['nameEnglish'],
      ayahCount: summaryJson['ayahCount'],
      revelationType: summaryJson['revelationType'],
    );
    
    return SurahDetail(
      summary: summary,
      ayahs: (json['ayahs'] as List)
          .map((a) => _ayahFromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _ayahToJson(SurahAyah ayah) {
    return {
      'numberInSurah': ayah.numberInSurah,
      'arabic': ayah.arabic,
      'translation': ayah.translation,
      'audioUrl': ayah.audioUrl,
    };
  }

  SurahAyah _ayahFromJson(Map<String, dynamic> json) {
    return SurahAyah(
      numberInSurah: json['numberInSurah'],
      arabic: json['arabic'],
      translation: json['translation'] ?? '',
      audioUrl: json['audioUrl'],
    );
  }
}
