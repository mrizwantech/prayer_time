import 'package:flutter/material.dart';
import '../core/quran_api_client.dart';
import '../presentation/widgets/app_header.dart';
import 'quran_surah_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _client = QuranApiClient();
  late Future<List<SurahSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _client.fetchSurahs();
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
              child: FutureBuilder<List<SurahSummary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Unable to load surahs. Please check your connection and try again.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final surahs = snapshot.data ?? [];
                  if (surahs.isEmpty) {
                    return const Center(child: Text('No surahs found.'));
                  }
                  return ListView.separated(
                    itemCount: surahs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = surahs[index];
                      return ListTile(
                        title: Text('${s.number}. ${s.nameEnglish}'),
                        subtitle: Text(
                          '${s.nameArabic} • ${s.ayahCount} ayahs • ${s.revelationType}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => QuranSurahScreen(summary: s),
                            ),
                          );
                        },
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
