import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/quran_api_client.dart';
import '../presentation/widgets/app_header.dart';

class QuranSurahScreen extends StatefulWidget {
  const QuranSurahScreen({super.key, required this.summary});

  final SurahSummary summary;

  @override
  State<QuranSurahScreen> createState() => _QuranSurahScreenState();
}

class _QuranSurahScreenState extends State<QuranSurahScreen> {
  final _client = QuranApiClient();
  final AudioPlayer _player = AudioPlayer();
  static const String _defaultFullSurahId = 'ar.alafasy';
  late Future<SurahDetail> _future;
  late Reciter _reciter;
  String? _playingUrl;
  String? _fullSurahUrlPrimary;   // QDC Mishary (reliable)
  bool _isFullSurahPlaying = false;
  bool _audioLoading = false;
  int? _savedSurahNumber;
  int? _savedAyahNumber;
  final List<GlobalKey> _ayahKeys = [];
  SurahDetail? _currentDetail;

  @override
  void initState() {
    super.initState();
    _reciter = _client.defaultReciter;
    _future = _client.fetchSurahDetail(
      widget.summary.number,
      reciter: _reciter,
    );
    _setFullSurahUrlsForReciter(_reciter);
    _loadSavedProgress();

    _player.setPlayerMode(PlayerMode.mediaPlayer);
    _player.setReleaseMode(ReleaseMode.stop);

    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed && mounted) {
        setState(() {
          _playingUrl = null;
          _isFullSurahPlaying = false;
        });
      }
    });

    _player.onLog.listen((msg) {
      debugPrint('AudioPlayer log: $msg');
    });
  }

  Future<void> _loadSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final surah = prefs.getInt('last_read_surah');
    final ayah = prefs.getInt('last_read_ayah');
    if (!mounted) return;
    setState(() {
      _savedSurahNumber = surah;
      _savedAyahNumber = ayah;
    });
  }

  Future<void> _saveLastRead(SurahAyah ayah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_surah', widget.summary.number);
    await prefs.setInt('last_read_ayah', ayah.numberInSurah);
    await prefs.setString('last_read_surah_name_en', widget.summary.nameEnglish);
    await prefs.setString('last_read_surah_name_ar', widget.summary.nameArabic);
    await prefs.setInt('last_read_surah_ayah_count', widget.summary.ayahCount);
    await prefs.setString('last_read_surah_revelation', widget.summary.revelationType);
    if (!mounted) return;
    setState(() {
      _savedSurahNumber = widget.summary.number;
      _savedAyahNumber = ayah.numberInSurah;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved at ayah ${ayah.numberInSurah}.')),
    );
  }

  void _jumpToSavedAyah() {
    if (_currentDetail == null || _savedAyahNumber == null) return;
    final index = _currentDetail!.ayahs.indexWhere((a) => a.numberInSurah == _savedAyahNumber);
    if (index < 0 || index >= _ayahKeys.length) return;
    final key = _ayahKeys[index];
    final contextForAyah = key.currentContext;
    if (contextForAyah != null) {
      Scrollable.ensureVisible(
        contextForAyah,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _setFullSurahUrlsForReciter(Reciter reciter) {
    _fullSurahUrlPrimary = 'https://download.quranicaudio.com/qdc/mishari_al_afasy/murattal/${widget.summary.number}.mp3';
  }

  Future<void> _stopAudio() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _playingUrl = null;
        _isFullSurahPlaying = false;
      });
    }
  }

  Future<bool> _playUrlSafe(String url, String label) async {
    try {
      await _player.play(UrlSource(url));
      return true;
    } catch (e, stackTrace) {
      debugPrint('Play error ($label): $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> _toggleAudio(SurahAyah ayah) async {
    final url = ayah.audioUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not available for this ayah.')),
      );
      return;
    }

    if (_playingUrl == url) {
      await _stopAudio();
      return;
    }

    setState(() => _audioLoading = true);
    try {
      await _player.stop();
      await _player.setVolume(1.0);

      final ok = await _playUrlSafe(url, 'ayah');
      if (ok && mounted) {
        setState(() {
          _playingUrl = url;
          _isFullSurahPlaying = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Audio error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not play audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  Future<void> _toggleFullSurah() async {
    final primary = _fullSurahUrlPrimary;

    if (primary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio not available for this surah.')),
      );
      return;
    }

    if (_isFullSurahPlaying && _playingUrl == primary) {
      await _stopAudio();
      return;
    }

    setState(() => _audioLoading = true);
    try {
      await _player.stop();
      await _player.setVolume(1.0);

      final okPrimary = await _playUrlSafe(primary, 'primary');
      if (okPrimary) {
        if (mounted) {
          setState(() {
            _playingUrl = primary;
            _isFullSurahPlaying = true;
          });
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play surah audio.')),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Full surah fatal error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playback error. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: '${summary.number}. ${summary.nameEnglish}',
              showLocation: false,
              showBackButton: true,
            ),
            Expanded(
              child: FutureBuilder<SurahDetail>(
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
                          'Unable to load surah. Please try again.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final detail = snapshot.data;
                  if (detail == null) {
                    return const Center(child: Text('No data found.'));
                  }

                  _currentDetail = detail;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.deepPurple.withOpacity(0.08),
                          leading: _audioLoading && _isFullSurahPlaying
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  _isFullSurahPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                                  color: Colors.deepPurple,
                                ),
                          title: const Text('Play full surah'),
                          subtitle: Text(_reciter.name),
                          onTap: _toggleFullSurah,
                        ),
                      ),
                      if (_savedSurahNumber == summary.number && _savedAyahNumber != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.bookmark_added_outlined),
                            label: Text('Start from ayah $_savedAyahNumber'),
                            onPressed: _jumpToSavedAyah,
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: detail.ayahs.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final ayah = detail.ayahs[index];
                            if (_ayahKeys.length <= index) {
                              _ayahKeys.add(GlobalKey());
                            }
                            final itemKey = _ayahKeys[index];
                            final isPlaying = !_isFullSurahPlaying && _playingUrl == ayah.audioUrl;
                            final isSaved = summary.number == _savedSurahNumber && ayah.numberInSurah == _savedAyahNumber;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  key: itemKey,
                                  decoration: isSaved
                                      ? BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        )
                                      : null,
                                  padding: const EdgeInsets.all(6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        child: Text('${ayah.numberInSurah}'),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ayah.arabic,
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              ayah.translation,
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: _audioLoading && isPlaying
                                                ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  )
                                                : Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill),
                                            onPressed: () => _toggleAudio(ayah),
                                          ),
                                          IconButton(
                                            icon: Icon(isSaved ? Icons.bookmark_added : Icons.bookmark_add_outlined),
                                            onPressed: () => _saveLastRead(ayah),
                                            tooltip: 'Save and start here',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
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
