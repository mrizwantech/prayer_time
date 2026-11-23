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
  /// Page number in the standard 604-page Madani mushaf (0 = unknown).
  final int page;

  const SurahAyah({
    required this.numberInSurah,
    required this.arabic,
    required this.translation,
    this.audioUrl,
    this.page = 0,
  });
}

class SurahDetail {
  final SurahSummary summary;
  final List<SurahAyah> ayahs;

  const SurahDetail({required this.summary, required this.ayahs});
}

/// Timestamp window (ms) of one verse inside a continuous surah recording.
class AyahTiming {
  final int verse;
  final int fromMs;
  final int toMs;

  const AyahTiming({
    required this.verse,
    required this.fromMs,
    required this.toMs,
  });
}

/// A continuous surah recording plus per-verse timestamps.
class SurahAudioTimings {
  final String audioUrl;
  final List<AyahTiming> timings;

  const SurahAudioTimings({required this.audioUrl, required this.timings});
}

/// A reciter offering gapless (continuous, timestamped) surah recordings.
class GaplessReciter {
  final int id;
  final String name;
  final String style;

  const GaplessReciter({
    required this.id,
    required this.name,
    required this.style,
  });
}

class QuranApiClient {
  QuranApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  List<SurahSummary>? _surahCache;
  final Map<int, SurahDetail> _detailCache = {};
  final Map<int, SurahAudioTimings> _timingsCache = {};
  List<GaplessReciter>? _gaplessRecitersCache;
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
          page: (ar['page'] as int?) ?? 0,
        ),
      );
    }

    final detail = SurahDetail(summary: summary, ayahs: ayahs);
    _detailCache[cacheKey] = detail;
    return detail;
  }

  /// Fetches the continuous (gapless) recording of a surah together with
  /// per-verse timestamps for the given quran.com reciter id, enabling
  /// smooth single-stream playback with follow-along highlighting.
  Future<SurahAudioTimings> fetchSurahTimings(
    int surahNumber, {
    int reciterId = 7,
  }) async {
    final cacheKey = reciterId * 1000 + surahNumber;
    final cached = _timingsCache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.parse(
      'https://api.qurancdn.com/api/qdc/audio/reciters/$reciterId/audio_files'
      '?chapter=$surahNumber&segments=true',
    );
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load timings (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final files = decoded['audio_files'] as List<dynamic>? ?? <dynamic>[];
    if (files.isEmpty) {
      throw Exception('No audio timing data for surah $surahNumber');
    }
    final file = files.first as Map<String, dynamic>;
    var audioUrl = (file['audio_url'] as String?) ?? '';
    if (audioUrl.isEmpty) {
      throw Exception('No audio URL in timing data');
    }
    if (!audioUrl.startsWith('http')) {
      audioUrl = 'https://download.quranicaudio.com/$audioUrl';
    }
    final verseTimings = file['verse_timings'] as List<dynamic>? ?? <dynamic>[];
    final timings = <AyahTiming>[];
    for (final vt in verseTimings) {
      final map = vt as Map<String, dynamic>;
      final key = map['verse_key'] as String?;
      final from = map['timestamp_from'] as num?;
      final to = map['timestamp_to'] as num?;
      if (key == null || from == null || to == null) continue;
      timings.add(AyahTiming(
        verse: int.parse(key.split(':').last),
        fromMs: from.toInt(),
        toMs: to.toInt(),
      ));
    }
    timings.sort((a, b) => a.fromMs.compareTo(b.fromMs));
    final result = SurahAudioTimings(audioUrl: audioUrl, timings: timings);
    _timingsCache[reciterId * 1000 + surahNumber] = result;
    return result;
  }

  /// Reciters with gapless (continuous, timestamped) surah recordings.
  Future<List<GaplessReciter>> fetchGaplessReciters() async {
    if (_gaplessRecitersCache != null) return _gaplessRecitersCache!;
    final uri =
        Uri.parse('https://api.qurancdn.com/api/qdc/audio/reciters?locale=en');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load reciters (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = decoded['reciters'] as List<dynamic>? ?? <dynamic>[];
    final reciters = <GaplessReciter>[];
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final id = map['id'] as int?;
      final name = (map['translated_name'] as Map<String, dynamic>?)?['name']
              as String? ??
          map['name'] as String? ??
          '';
      final style =
          (map['style'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      if (id == null || name.isEmpty) continue;
      reciters.add(GaplessReciter(id: id, name: name, style: style));
    }
    reciters.sort((a, b) => a.name.compareTo(b.name));
    if (reciters.isEmpty) throw Exception('No reciters available');
    _gaplessRecitersCache = reciters;
    return reciters;
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
