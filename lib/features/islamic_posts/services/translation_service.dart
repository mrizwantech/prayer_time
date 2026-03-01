import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Service for translating text to Arabic and other languages
class TranslationService {
  // Using MyMemory Translation API (free, no API key required for basic use)
  static const String _baseUrl = 'https://api.mymemory.translated.net/get';

  /// Translate text from source language to target language
  /// Returns null if translation fails
  static Future<String?> translate({
    required String text,
    required String fromLang,
    required String toLang,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': text,
        'langpair': '$fromLang|$toLang',
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['responseStatus'] == 200) {
          return data['responseData']['translatedText'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Translation error: $e');
      return null;
    }
  }

  /// Translate text to Arabic
  static Future<String?> translateToArabic(String text, {String fromLang = 'en'}) async {
    return translate(text: text, fromLang: fromLang, toLang: 'ar');
  }

  /// Translate Arabic text to another language
  static Future<String?> translateFromArabic(String arabicText, {String toLang = 'en'}) async {
    return translate(text: arabicText, fromLang: 'ar', toLang: toLang);
  }

  /// Supported source languages for translation
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'ur': 'Urdu',
    'fr': 'French',
    'tr': 'Turkish',
    'id': 'Indonesian',
    'ms': 'Malay',
    'es': 'Spanish',
    'de': 'German',
    'hi': 'Hindi',
    'bn': 'Bengali',
    'fa': 'Persian',
  };

  /// Get language name from code
  static String getLanguageName(String code) {
    return supportedLanguages[code] ?? code;
  }
}

/// Transliteration helper - simple phonetic Arabic to English
class TransliterationService {
  // Basic Arabic to Latin transliteration map
  static const Map<String, String> _arabicToLatin = {
    'ا': 'a',
    'أ': 'a',
    'إ': 'i',
    'آ': 'aa',
    'ب': 'b',
    'ت': 't',
    'ث': 'th',
    'ج': 'j',
    'ح': 'h',
    'خ': 'kh',
    'د': 'd',
    'ذ': 'dh',
    'ر': 'r',
    'ز': 'z',
    'س': 's',
    'ش': 'sh',
    'ص': 's',
    'ض': 'd',
    'ط': 't',
    'ظ': 'dh',
    'ع': '\'',
    'غ': 'gh',
    'ف': 'f',
    'ق': 'q',
    'ك': 'k',
    'ل': 'l',
    'م': 'm',
    'ن': 'n',
    'ه': 'h',
    'و': 'w',
    'ي': 'y',
    'ى': 'a',
    'ة': 'h',
    'ء': '\'',
    'ئ': '\'',
    'ؤ': '\'',
    // Vowel marks (harakat)
    'َ': 'a',
    'ُ': 'u',
    'ِ': 'i',
    'ً': 'an',
    'ٌ': 'un',
    'ٍ': 'in',
    'ْ': '',
    'ّ': '', // shadda - doubles the consonant
    // Common combinations
    'لا': 'la',
    'الل': 'all',
  };

  /// Simple transliteration of Arabic text to Latin script
  /// Note: This is a basic implementation. For proper transliteration,
  /// a more sophisticated algorithm or API would be needed.
  static String transliterate(String arabic) {
    if (arabic.isEmpty) return '';

    String result = arabic;
    
    // Replace common combinations first
    result = result.replaceAll('الله', 'Allah');
    result = result.replaceAll('اللَّه', 'Allah');
    result = result.replaceAll('محمد', 'Muhammad');
    result = result.replaceAll('إن شاء الله', 'In sha Allah');
    result = result.replaceAll('سبحان الله', 'SubhanAllah');
    result = result.replaceAll('الحمد لله', 'Alhamdulillah');
    
    // Then do character by character replacement
    final buffer = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final char = result[i];
      if (_arabicToLatin.containsKey(char)) {
        buffer.write(_arabicToLatin[char]);
      } else if (char == ' ') {
        buffer.write(' ');
      } else if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        buffer.write(char);
      }
      // Skip unknown characters
    }

    // Clean up the result
    String cleaned = buffer.toString();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }
}
