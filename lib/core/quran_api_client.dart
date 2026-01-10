import 'dart:convert';
import 'package:http/http.dart' as http;

class SurahSummary {
  final int number;
  final String nameArabic;
  final String nameEnglish;
  final int ayahCount;
  final String revelationType;

  const SurahSummary({
    required this.number,
    required this.nameArabic,
    required this.nameEnglish,
    required this.ayahCount,
    required this.revelationType,
  });
}

class Reciter {
  final String id; // matches edition identifier, e.g., ar.alafasy
  final String name;
  final String edition; // edition code used for verse-by-verse audio

  const Reciter({required this.id, required this.name, required this.edition});
}

class SurahAyah {
  final int numberInSurah;
  final String arabic;
  final String translation;
  final String? audioUrl;

  const SurahAyah({
    required this.numberInSurah,
    required this.arabic,
    required this.translation,
    this.audioUrl,
  });
}

class SurahDetail {
  final SurahSummary summary;
  final List<SurahAyah> ayahs;

  const SurahDetail({required this.summary, required this.ayahs});
}

class QuranApiClient {
  QuranApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  List<SurahSummary>? _surahCache;
  final Map<int, SurahDetail> _detailCache = {};
  List<Reciter>? _recitersCache;

  static const String _base = 'https://api.alquran.cloud/v1';
  static const Reciter _fallbackReciter = Reciter(
    id: 'ar.alafasy',
    name: 'Mishary Alafasy',
    edition: 'ar.alafasy',
  );

  // Known full-surah-supported reciters (match ids used by CDN and editions API)
  static const List<Reciter> _knownReciters = [
    Reciter(id: 'ar.alafasy', name: 'Mishary Alafasy', edition: 'ar.alafasy'),
    Reciter(id: 'ar.husary', name: 'Mahmoud Al-Husary', edition: 'ar.husary'),
    Reciter(id: 'ar.shaatree', name: 'Abu Bakr Ash-Shaatree', edition: 'ar.shaatree'),
    Reciter(id: 'ar.abdulbasitmurattal', name: 'Abdul Basit (Murattal)', edition: 'ar.abdulbasitmurattal'),
    Reciter(id: 'ar.abdulsamad', name: 'Abdul Samad', edition: 'ar.abdulsamad'),
    Reciter(id: 'ar.mahermuaiqly', name: 'Maher Al-Muaiqly', edition: 'ar.mahermuaiqly'),
    Reciter(id: 'ar.minshawi', name: 'Minshawi', edition: 'ar.minshawi'),
  ];

  Reciter get defaultReciter {
    if (_recitersCache != null) {
      return _recitersCache!.firstWhere(
        (r) => r.id == 'ar.alafasy',
        orElse: () => _recitersCache!.first,
      );
    }
    return _fallbackReciter;
  }

  Future<List<SurahSummary>> fetchSurahs() async {
    if (_surahCache != null) return _surahCache!;

    final uri = Uri.parse('$_base/surah');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load surah list (${resp.statusCode})');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> data = body['data'] as List<dynamic>;
    _surahCache = data.map((item) {
      return SurahSummary(
        number: item['number'] as int,
        nameArabic: item['name'] as String,
        nameEnglish: item['englishName'] as String,
        ayahCount: item['numberOfAyahs'] as int,
        revelationType: (item['revelationType'] as String?) ?? 'N/A',
      );
    }).toList();

    return _surahCache!;
  }

  Future<SurahDetail> fetchSurahDetail(int number, {Reciter? reciter}) async {
    final selected = reciter ?? defaultReciter;
    final cacheKey = number * 1000 + selected.id.hashCode;
    if (_detailCache.containsKey(cacheKey)) return _detailCache[cacheKey]!;

    final uri = Uri.parse('$_base/surah/$number/editions/quran-uthmani,en.asad,${selected.edition}');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load surah $number (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> editions = decoded['data'] as List<dynamic>;
    if (editions.length < 2) {
      throw Exception('Unexpected response shape for surah $number');
    }

    final arabic = editions[0]['ayahs'] as List<dynamic>;
    final translation = editions[1]['ayahs'] as List<dynamic>;
    final audio = editions.length > 2 ? editions[2]['ayahs'] as List<dynamic> : <dynamic>[];

    final summary = SurahSummary(
      number: editions[0]['number'] as int,
      nameArabic: editions[0]['name'] as String,
      nameEnglish: editions[0]['englishName'] as String,
      ayahCount: editions[0]['numberOfAyahs'] as int,
      revelationType: (editions[0]['revelationType'] as String?) ?? 'N/A',
    );

    final ayahs = <SurahAyah>[];
    for (int i = 0; i < arabic.length; i++) {
      final ar = arabic[i] as Map<String, dynamic>;
      final tr = translation.length > i ? translation[i] as Map<String, dynamic> : <String, dynamic>{};
      final au = audio.isNotEmpty && audio.length > i ? audio[i] as Map<String, dynamic> : <String, dynamic>{};

      ayahs.add(
        SurahAyah(
          numberInSurah: ar['numberInSurah'] as int,
          arabic: (ar['text'] as String?) ?? '',
          translation: (tr['text'] as String?) ?? '',
          audioUrl: au['audio'] as String?,
        ),
      );
    }

    final detail = SurahDetail(summary: summary, ayahs: ayahs);
    _detailCache[cacheKey] = detail;
    return detail;
  }

  Future<List<Reciter>> fetchReciters() async {
    if (_recitersCache != null) return _recitersCache!;

    // Fetch available audio editions (verse-by-verse) and map to reciters
    final uri = Uri.parse('$_base/edition?format=audio&type=versebyverse');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      // Fallback to a minimal built-in list if the API call fails
      _recitersCache = const [
        Reciter(id: 'ar.alafasy', name: 'Mishary Alafasy', edition: 'ar.alafasy'),
        Reciter(id: 'ar.husary', name: 'Mahmoud Al-Husary', edition: 'ar.husary'),
        Reciter(id: 'ar.shaatree', name: 'Abu Bakr Ash-Shaatree', edition: 'ar.shaatree'),
      ];
      return _recitersCache!;
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final List<dynamic> data = decoded['data'] as List<dynamic>? ?? <dynamic>[];
    _recitersCache = data.map((item) {
      final id = item['identifier'] as String? ?? '';
      final name = item['englishName'] as String? ?? id;
      return Reciter(id: id, name: name, edition: id);
    }).toList();

    if (_recitersCache!.isEmpty) {
      _recitersCache = const [_fallbackReciter];
    }

    // Ensure our known supported reciters are present; prepend if missing
    final existingIds = _recitersCache!.map((r) => r.id).toSet();
    final missing = _knownReciters.where((r) => !existingIds.contains(r.id)).toList();
    if (missing.isNotEmpty) {
      _recitersCache = [...missing, ..._recitersCache!];
    }

    return _recitersCache!;
  }
}
