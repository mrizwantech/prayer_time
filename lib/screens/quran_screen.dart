import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/quran_api_client.dart';
import '../core/quran_provider.dart';
import '../presentation/widgets/app_header.dart';
import 'quran_surah_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final Map<int, int?> _savedAyahPerSurah = {};
  int? _lastSavedSurah;
  int? _lastSavedAyah;

  @override
  void initState() {
    super.initState();
    _loadAllSavedProgress();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(
              title: 'Quran',
              showLocation: false,
            ),
            Expanded(
              child: Consumer<QuranProvider>(
                builder: (context, quranProvider, _) {
                  if (quranProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (quranProvider.error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Unable to load surahs. Please check your connection and try again.',
                              textAlign: TextAlign.center,
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
                  final surahs = quranProvider.surahs;
                  if (surahs.isEmpty) {
                    return const Center(child: Text('No surahs found.'));
                  }
                    final hasLastSaved = _lastSavedSurah != null && _lastSavedAyah != null &&
                      surahs.any((s) => s.number == _lastSavedSurah);
                  return ListView.separated(
                    itemCount: surahs.length + (hasLastSaved ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (hasLastSaved && index == 0) {
                        final summary = surahs.firstWhere(
                          (s) => s.number == _lastSavedSurah,
                          orElse: () => surahs.first,
                        );

                        return ListTile(
                          tileColor: Colors.blue.withOpacity(0.06),
                          leading: const Icon(Icons.bookmark_added_outlined, color: Colors.blue),
                          title: Text('Resume at Surah ${_lastSavedSurah}, Ayah ${_lastSavedAyah}'),
                          subtitle: Text(summary.nameEnglish),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () => _openSurah(summary, jumpToSaved: true),
                        );
                      }

                      final s = surahs[hasLastSaved ? index - 1 : index];
                      final savedAyah = _savedAyahPerSurah[s.number];
                      final hasSavedProgress = savedAyah != null;
                      
                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text('${s.number}. ${s.nameEnglish}'),
                            ),
                           
                          ],
                        ),
                        subtitle: Text(
                          '${s.nameArabic} • ${s.ayahCount} ayahs • ${s.revelationType}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openSurah(s, jumpToSaved: hasSavedProgress),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
