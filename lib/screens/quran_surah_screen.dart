import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/quran_api_client.dart';
import '../core/quran_storage_service.dart';

class QuranSurahScreen extends StatefulWidget {
  const QuranSurahScreen({super.key, required this.summary, this.autoJumpToSaved = false});

  final SurahSummary summary;
  final bool autoJumpToSaved;

  @override
  State<QuranSurahScreen> createState() => _QuranSurahScreenState();
}

class _QuranSurahScreenState extends State<QuranSurahScreen> {
  final _client = QuranApiClient();
  final _storage = QuranStorageService();
  final AudioPlayer _player = AudioPlayer();
  static const String _defaultFullSurahId = 'ar.alafasy';
  late Future<SurahDetail> _future;
  late Reciter _reciter;
  String? _playingUrl;
  String? _fullSurahUrlPrimary;   // QDC Mishary (reliable)
  bool _isFullSurahPlaying = false;
  bool _audioLoading = false;
  bool _isSavedOffline = false;
  int? _savedSurahNumber;
  int? _savedAyahNumber;
  final List<GlobalKey> _ayahKeys = [];
  final GlobalKey _listViewKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  SurahDetail? _currentDetail;
  bool _shouldAutoJump = false;
  bool _autoJumpDone = false;
  bool _autoJumpScheduled = false;
  int? _lastInteractedAyahNumber;

  @override
  void initState() {
    super.initState();
    _reciter = _client.defaultReciter;
    _shouldAutoJump = widget.autoJumpToSaved;
    
    // Load surah: check local storage first, then fetch from API
    _future = _loadSurahWithStorage();
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

  /// Load surah from local storage if available, otherwise fetch from API
  Future<SurahDetail> _loadSurahWithStorage() async {
    final saved = await _storage.getSavedSurah(widget.summary.number);
    if (saved != null) {
      if (mounted) {
        setState(() => _isSavedOffline = true);
      }
      return saved;
    }
    
    // Not saved locally, fetch from API
    final detail = await _client.fetchSurahDetail(
      widget.summary.number,
      reciter: _reciter,
    );
    if (mounted) {
      setState(() => _isSavedOffline = false);
    }
    return detail;
  }

  Future<void> _loadSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final surahNumber = widget.summary.number;

    // Load progress specific to this surah (and honor global last saved if it matches)
    int? ayah = prefs.getInt('surah_${surahNumber}_last_ayah');
    final globalSurah = prefs.getInt('last_saved_surah');
    final globalAyah = prefs.getInt('last_saved_ayah');
    if (globalSurah == surahNumber && globalAyah != null) {
      ayah = globalAyah;
    }
    if (!mounted) return;
    setState(() {
      _savedAyahNumber = ayah;
      _savedSurahNumber = ayah != null ? surahNumber : null;
    });

    // Queue jump if requested and saved data exists
    if (_shouldAutoJump && _savedAyahNumber != null) {
      _autoJumpDone = false;
      _autoJumpScheduled = false;
    }
  }

  Future<void> _saveLastRead(SurahAyah ayah, {bool showMessage = true}) async {
    final prefs = await SharedPreferences.getInstance();
    // Save progress specific to this surah
    await prefs.setInt('surah_${widget.summary.number}_last_ayah', ayah.numberInSurah);
    await prefs.setInt('last_saved_surah', widget.summary.number);
    await prefs.setInt('last_saved_ayah', ayah.numberInSurah);
    if (!mounted) return;
    setState(() {
      _savedAyahNumber = ayah.numberInSurah;
      _savedSurahNumber = widget.summary.number;
      _lastInteractedAyahNumber = ayah.numberInSurah;
    });
    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved at ayah ${ayah.numberInSurah}.')),
      );
    }
  }

  void _jumpToSavedAyah({int attempt = 1}) {
    if (_currentDetail == null || _savedAyahNumber == null) return;

    // Remember that user intends to continue from this ayah for exit prompt
    _recordInteraction(_savedAyahNumber!);

    final index = _currentDetail!.ayahs.indexWhere(
      (a) => a.numberInSurah == _savedAyahNumber,
    );

    if (index < 0) return;

    // Wait for scroll controller to be attached
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && attempt < 5) {
          Future.delayed(const Duration(milliseconds: 100), () => _jumpToSavedAyah(attempt: attempt + 1));
        }
      });
      return;
    }

    // Calculate position as a fraction of total content
    final totalItems = _currentDetail!.ayahs.length;
    final fraction = index / totalItems;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = (fraction * maxScroll).clamp(0.0, maxScroll);

    // Animate scroll to target position
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (!mounted) return;
      
      // After scroll animation completes, refine with ensureVisible
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted || index >= _ayahKeys.length) return;

        final key = _ayahKeys[index];
        final contextForAyah = key.currentContext;

        if (contextForAyah != null) {
          Scrollable.ensureVisible(
            contextForAyah,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
        } else if (attempt < 3) {
          // Retry if still not built
          Future.delayed(const Duration(milliseconds: 200), () => _jumpToSavedAyah(attempt: attempt + 1));
        }
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureAyahKeysExist(int count) {
    while (_ayahKeys.length < count) {
      _ayahKeys.add(GlobalKey());
    }
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

    _recordInteraction(ayah.numberInSurah);

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

  /// Toggle offline save for this surah
  Future<void> _toggleSaveOffline() async {
    if (_currentDetail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surah not loaded yet. Please wait.')),
      );
      return;
    }

    try {
      if (_isSavedOffline) {
        // Delete offline copy
        await _storage.deleteSavedSurah(widget.summary.number);
        if (mounted) {
          setState(() => _isSavedOffline = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offline copy deleted.')),
          );
        }
      } else {
        // Save offline copy
        await _storage.saveSurah(widget.summary.number, _currentDetail!);
        if (mounted) {
          setState(() => _isSavedOffline = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved for offline reading.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling offline save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return WillPopScope(
      onWillPop: _handleExitAttempt,
      child: Scaffold(
        body: SafeArea(
          child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${summary.number}. ${summary.nameEnglish}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isSavedOffline)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                                    SizedBox(width: 4),
                                    Text(
                                      'Offline',
                                      style: TextStyle(fontSize: 12, color: Colors.green),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.nameArabic,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isSavedOffline ? Icons.bookmark : Icons.bookmark_border,
                          color: _isSavedOffline ? Colors.blue : Colors.grey,
                        ),
                        onPressed: _toggleSaveOffline,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _onBackPressed,
                      ),
                    ],
                  ),
                ],
              ),
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
                  _ensureAyahKeysExist(detail.ayahs.length);
                  _maybeAutoJumpToSaved();

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
                   
                      Expanded(
                        child: ListView.separated(
                          key: _listViewKey,
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: detail.ayahs.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final ayah = detail.ayahs[index];
                            final itemKey = _ayahKeys[index];
                            final isPlaying = !_isFullSurahPlaying && _playingUrl == ayah.audioUrl;
                            final isSaved = summary.number == _savedSurahNumber && ayah.numberInSurah == _savedAyahNumber;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _recordInteraction(ayah.numberInSurah),
                              child: Column(
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
                              ),
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
    ),
    );
  }

  void _recordInteraction(int ayahNumber) {
    if (!mounted) return;
    // Defer state change to avoid setState during build frames (e.g., auto-jump path)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _lastInteractedAyahNumber = ayahNumber);
    });
  }

  void _maybeAutoJumpToSaved() {
    if (_autoJumpDone || _autoJumpScheduled || !_shouldAutoJump || _savedAyahNumber == null || _currentDetail == null) {
      return;
    }

    _autoJumpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoJumpDone = true;
      _autoJumpScheduled = false;
      _jumpToSavedAyah();
    });
  }

  Future<void> _onBackPressed() async {
    final shouldPop = await _handleExitAttempt();
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _clearSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('surah_${widget.summary.number}_last_ayah');
    final globalSurah = prefs.getInt('last_saved_surah');
    if (globalSurah == widget.summary.number) {
      await prefs.remove('last_saved_surah');
      await prefs.remove('last_saved_ayah');
    }

    if (!mounted) return;
    setState(() {
      _savedAyahNumber = null;
      _savedSurahNumber = null;
      _lastInteractedAyahNumber = null;
    });
  }

  Future<bool> _handleExitAttempt() async {
    final candidateAyahNumber = _lastInteractedAyahNumber ?? _savedAyahNumber;
    if (candidateAyahNumber == null) {
      return true;
    }

    if (_currentDetail == null) {
      return true;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save reading progress?'),
          content: Text('Keep your place at ayah $candidateAyahNumber before leaving? Tap Save to keep the bookmark.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('discard'),
              child: const Text('Don\'t save'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_add_outlined),
                  SizedBox(width: 6),
                  Text('Save'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (choice == null || choice == 'cancel') {
      return false;
    }

    if (choice == 'save') {
      final ayah = _currentDetail!.ayahs.firstWhere(
        (a) => a.numberInSurah == candidateAyahNumber,
        orElse: () => _currentDetail!.ayahs.last,
      );
      await _saveLastRead(ayah, showMessage: false);
    } else {
      await _clearSavedProgress();
    }

    return true;
  }
}
