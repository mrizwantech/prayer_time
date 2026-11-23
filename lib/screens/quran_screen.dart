import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/quran_api_client.dart';
import '../core/quran_provider.dart';
import 'quran_surah_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  static const _gold = Color(0xFFE6C464);
  static const _cardColor = Color(0x14FFFFFF);
  static const _cardBorder = Color(0x1FFFFFFF);

  final Map<int, int?> _savedAyahPerSurah = {};
  int? _lastSavedSurah;
  int? _lastSavedAyah;

  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllSavedProgress();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final latestSurah = prefs.getInt('last_saved_surah');
    final latestAyah = prefs.getInt('last_saved_ayah');

    // Load saved progress for all surahs (1-114)
    final Map<int, int?> saved = {};
    for (int surahNum = 1; surahNum <= 114; surahNum++) {
      saved[surahNum] = prefs.getInt('surah_${surahNum}_last_ayah');
    }

    if (!mounted) return;
    setState(() {
      _savedAyahPerSurah
        ..clear()
        ..addAll(saved);
      _lastSavedSurah = latestSurah;
      _lastSavedAyah = latestAyah;
    });
  }

  void _openSurah(SurahSummary summary, {bool jumpToSaved = false}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => QuranSurahScreen(
              summary: summary,
              autoJumpToSaved: jumpToSaved,
            ),
          ),
        )
        .then((_) => _loadAllSavedProgress());
  }

  List<SurahSummary> _filtered(List<SurahSummary> surahs) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return surahs;
    return surahs.where((s) {
      return s.nameEnglish.toLowerCase().contains(q) ||
          s.nameArabic.contains(q) ||
          s.number.toString() == q;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF071F1C),
              Color(0xFF0E3A34),
              Color(0xFF071F1C),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              if (_searching) _searchField(),
              Expanded(
                child: Consumer<QuranProvider>(
                  builder: (context, quranProvider, _) {
                    if (quranProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: _gold),
                      );
                    }
                    if (quranProvider.error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Unable to load surahs. Please check your connection and try again.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => quranProvider.loadSurahs(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final surahs = _filtered(quranProvider.surahs);
                    if (surahs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No surahs found.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    final hasLastSaved = _query.isEmpty &&
                        _lastSavedSurah != null &&
                        _lastSavedAyah != null &&
                        surahs.any((s) => s.number == _lastSavedSurah);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                      itemCount: surahs.length + (hasLastSaved ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (hasLastSaved && index == 0) {
                          final summary = surahs.firstWhere(
                            (s) => s.number == _lastSavedSurah,
                            orElse: () => surahs.first,
                          );
                          return _resumeCard(summary);
                        }
                        final s = surahs[hasLastSaved ? index - 1 : index];
                        // Highlight only the most recently saved surah
                        final isLatest = s.number == _lastSavedSurah;
                        return _surahCard(
                          s,
                          savedAyah: isLatest ? _lastSavedAyah : null,
                          jumpToSaved: _savedAyahPerSurah[s.number] != null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          // Round app logo with gold ring
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withOpacity(0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.menu_book, color: _gold, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quran',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Read • Listen • Reflect',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Search toggle
          Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder),
            ),
            child: IconButton(
              icon: Icon(
                _searching ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _query = '';
                    _searchController.clear();
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        cursorColor: _gold,
        decoration: InputDecoration(
          hintText: 'Search surah by name or number…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          filled: true,
          fillColor: _cardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _gold.withOpacity(0.7)),
          ),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );
  }

  Widget _resumeCard(SurahSummary summary) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: _gold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: const Icon(Icons.bookmark_added_outlined, color: _gold),
          title: Text(
            'Resume at Surah $_lastSavedSurah, Ayah $_lastSavedAyah',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            summary.nameEnglish,
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: const Icon(Icons.chevron_right, color: _gold),
          onTap: () => _openSurah(summary, jumpToSaved: true),
        ),
      ),
    );
  }

  Widget _surahCard(SurahSummary s, {int? savedAyah, bool jumpToSaved = false}) {
    final hasSavedProgress = savedAyah != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: hasSavedProgress ? _gold.withOpacity(0.10) : _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSavedProgress ? _gold.withOpacity(0.55) : _cardBorder,
          width: hasSavedProgress ? 1.3 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSurah(s, jumpToSaved: jumpToSaved),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Gold number ring
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold, width: 1.4),
                ),
                child: Text(
                  '${s.number}',
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Names and verse count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nameEnglish,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.nameArabic,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${s.ayahCount} verses',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        if (hasSavedProgress) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.bookmark, color: _gold, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            'Ayah $savedAyah',
                            style: const TextStyle(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.15),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              // Revelation place
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mosque, color: Colors.white54, size: 16),
                  const SizedBox(height: 4),
                  Text(
                    s.revelationType,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: _gold, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
