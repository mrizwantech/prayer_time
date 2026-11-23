import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/quran_api_client.dart';
import '../core/quran_provider.dart';
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
  late AudioPlayer _player = _createSequencePlayer();
  // Second player that pre-buffers the next ayah for near-gapless playback
  AudioPlayer? _nextPlayer;
  int? _nextPreloadedIndex;
  AudioPlayer? _sparePlayer;
  // Downloaded clip cache: audio URL -> local file path
  final Map<String, String> _audioCache = {};
  // In-flight downloads, so the prefetcher and preloader never duplicate work
  final Map<String, Future<void>> _inflightDownloads = {};
  bool _prefetchActive = false;
  static const int _prefetchAhead = 20;
  // Early hand-off: start the next clip just before the current one ends
  final Map<AudioPlayer, Duration> _clipDurations = {};
  bool _earlyAdvanceTriggered = false;
  static const Duration _handOffLead = Duration(milliseconds: 250);
  // Single-stream playback with verse timestamps (preferred over clips)
  bool _timedStreamMode = false;
  SurahAudioTimings? _streamTimings;
  // Stream starts right after the standalone Bismillah clip finishes
  bool _pendingStreamStart = false;
  // Where recitation was when the user stopped; keeps the place marked
  int? _stoppedAtAyahNumber;
  // Selected gapless reciter (quran.com id); 7 = Mishary Alafasy
  int _streamReciterId = 7;
  String _streamReciterName = 'Mishary Alafasy';
  late Future<SurahDetail> _future;
  late Reciter _reciter;
  String? _playingUrl;
  bool _isFullSurahPlaying = false;
  // Ayah currently being recited during full-surah playback (for follow-along)
  int? _playingAyahNumber;
  // True while the opening Bismillah clip is playing
  bool _playingBismillah = false;
  bool _audioLoading = false;
  bool _isSavedOffline = false;
  int? _savedSurahNumber;
  int? _savedAyahNumber;
  final List<GlobalKey> _ayahKeys = [];
  final GlobalKey _bismillahKey = GlobalKey();
  final GlobalKey _listViewKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  SurahDetail? _currentDetail;
  bool _shouldAutoJump = false;
  bool _autoJumpDone = false;
  bool _autoJumpScheduled = false;
  int? _lastInteractedAyahNumber;

  // Reading preferences
  bool _showTranslation = true;
  bool _pagedMode = false;
  double _fontScale = 1.0;
  int _currentPageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _reciter = _client.defaultReciter;
    _shouldAutoJump = widget.autoJumpToSaved;
    _loadReadingPrefs();
    
    // Load surah: check local storage first, then fetch from API
    _future = _loadSurahWithStorage();
    _loadSavedProgress();
  }

  AudioPlayer _createSequencePlayer() {
    final player = AudioPlayer();
    player.setPlayerMode(PlayerMode.mediaPlayer);
    player.setReleaseMode(ReleaseMode.stop);
    player.onPlayerComplete.listen((_) => _onClipComplete(player));
    player.onDurationChanged.listen((d) => _clipDurations[player] = d);
    player.onPositionChanged.listen((p) => _onClipPosition(player, p));
    player.onLog.listen((msg) => debugPrint('AudioPlayer log: $msg'));
    return player;
  }

  /// Starts the next clip slightly before the current one ends so the
  /// transition overlaps the natural tail instead of stop-then-start.
  void _onClipPosition(AudioPlayer source, Duration position) {
    if (!mounted || !identical(source, _player)) return;
    if (_timedStreamMode) {
      _onStreamPosition(position);
      return;
    }
    if (_earlyAdvanceTriggered) return;
    if (!(_isFullSurahPlaying || _playingBismillah)) return;
    final total = _clipDurations[source];
    if (total == null || total == Duration.zero) return;
    if (total - position > _handOffLead) return;

    _earlyAdvanceTriggered = true;
    if (_playingBismillah) {
      _playingBismillah = false;
      if (_pendingStreamStart) {
        _pendingStreamStart = false;
        _beginTimedStreamPlayback();
      } else {
        _playAyahInSequence(0);
      }
    } else {
      _playNextAyahInSequence();
    }
  }

  /// Maps the stream position to the verse being recited and follows it.
  void _onStreamPosition(Duration position) {
    final timings = _streamTimings;
    final detail = _currentDetail;
    if (timings == null || detail == null || !_isFullSurahPlaying) return;
    // Stopping resets the position to zero; ignore events when not playing
    if (_player.state != PlayerState.playing) return;
    final ms = position.inMilliseconds;

    int? verse;
    for (final t in timings.timings) {
      if (ms >= t.fromMs && ms < t.toMs) {
        verse = t.verse;
        break;
      }
    }
    if (verse == null) {
      // Before the first verse: the Bismillah is being recited
      if (timings.timings.isNotEmpty &&
          ms < timings.timings.first.fromMs &&
          !_playingBismillah) {
        setState(() {
          _playingBismillah = true;
          _playingAyahNumber = null;
        });
        _showBismillahOnScreen();
      }
      return;
    }
    if (_playingBismillah || verse != _playingAyahNumber) {
      _playingBismillah = false;
      setState(() => _playingAyahNumber = verse);
      final index =
          detail.ayahs.indexWhere((a) => a.numberInSurah == verse);
      if (index >= 0) _followAyah(index);
    }
  }

  Future<void> _onClipComplete(AudioPlayer source) async {
    // Ignore events from recycled/stale players
    if (!mounted || !identical(source, _player)) return;
    if (_timedStreamMode) {
      // The continuous recording finished
      await _stopAudio();
      return;
    }
    // Early hand-off already advanced the sequence
    if (_earlyAdvanceTriggered && (_isFullSurahPlaying || _playingBismillah)) {
      return;
    }
    if (_playingBismillah) {
      // Bismillah finished: start the surah from its first ayah
      _playingBismillah = false;
      if (_pendingStreamStart) {
        _pendingStreamStart = false;
        await _beginTimedStreamPlayback();
      } else {
        await _playAyahInSequence(0);
      }
    } else if (_isFullSurahPlaying) {
      await _playNextAyahInSequence();
    } else {
      setState(() {
        _playingUrl = null;
      });
    }
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

  Future<void> _loadReadingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showTranslation = prefs.getBool('quran_show_translation') ?? true;
      _pagedMode = prefs.getBool('quran_paged_mode') ?? false;
      _fontScale = prefs.getDouble('quran_font_scale') ?? 1.0;
      _streamReciterId = prefs.getInt('quran_reciter_id') ?? 7;
      _streamReciterName =
          prefs.getString('quran_reciter_name') ?? 'Mishary Alafasy';
    });
  }

  Future<void> _toggleTranslation() async {
    setState(() => _showTranslation = !_showTranslation);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quran_show_translation', _showTranslation);
  }

  Future<void> _togglePagedMode() async {
    final detail = _currentDetail;
    if (!_pagedMode &&
        detail != null &&
        !detail.ayahs.any((a) => a.page > 0)) {
      // Old offline copy without page info
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Page data unavailable for this offline copy. Delete and re-save it to enable page view.'),
      ));
      return;
    }
    setState(() => _pagedMode = !_pagedMode);
    _currentPageIndex = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quran_paged_mode', _pagedMode);
  }

  /// Groups ayahs of this surah by their mushaf page, in order.
  List<MapEntry<int, List<SurahAyah>>> _mushafPages(SurahDetail detail) {
    final pages = <int, List<SurahAyah>>{};
    for (final ayah in detail.ayahs) {
      pages.putIfAbsent(ayah.page, () => []).add(ayah);
    }
    final entries = pages.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
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

    if (_pagedMode) {
      _jumpToSavedPage(attempt: attempt);
      return;
    }

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

  void _jumpToSavedPage({int attempt = 1}) {
    final detail = _currentDetail;
    if (detail == null || _savedAyahNumber == null) return;
    final pages = _mushafPages(detail);
    final pageIndex = pages.indexWhere(
      (entry) => entry.value.any((a) => a.numberInSurah == _savedAyahNumber),
    );
    if (pageIndex < 0) return;
    if (!_pageController.hasClients) {
      if (attempt < 5) {
        Future.delayed(const Duration(milliseconds: 100),
            () => _jumpToSavedPage(attempt: attempt + 1));
      }
      return;
    }
    _pageController.jumpToPage(pageIndex);
    // Then bring the exact ayah into view within the page
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final ayahIndex = detail.ayahs
          .indexWhere((a) => a.numberInSurah == _savedAyahNumber);
      if (ayahIndex < 0 || ayahIndex >= _ayahKeys.length) return;
      final contextForAyah = _ayahKeys[ayahIndex].currentContext;
      if (contextForAyah != null) {
        Scrollable.ensureVisible(
          contextForAyah,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _nextPlayer?.dispose();
    _sparePlayer?.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _ensureAyahKeysExist(int count) {
    while (_ayahKeys.length < count) {
      _ayahKeys.add(GlobalKey());
    }
  }

  Future<void> _stopAudio() async {
    await _player.stop();
    _playingBismillah = false;
    _timedStreamMode = false;
    _streamTimings = null;
    _pendingStreamStart = false;
    _earlyAdvanceTriggered = false;
    final lastPlayed = _playingAyahNumber;
    final preloaded = _nextPlayer;
    _nextPlayer = null;
    _nextPreloadedIndex = null;
    if (preloaded != null) {
      unawaited(preloaded.stop());
      if (_sparePlayer == null) {
        _sparePlayer = preloaded;
      } else {
        unawaited(preloaded.dispose());
      }
    }
    if (mounted) {
      setState(() {
        _playingUrl = null;
        _isFullSurahPlaying = false;
        _playingAyahNumber = null;
        if (lastPlayed != null) {
          // Keep the spot marked so the reader knows where they stopped
          _stoppedAtAyahNumber = lastPlayed;
          _lastInteractedAyahNumber = lastPlayed;
        }
      });
    }
  }

  /// Prefers a locally downloaded copy of the clip; falls back to streaming.
  Source _sourceFor(String url) {
    final cached = _audioCache[url];
    return cached != null ? DeviceFileSource(cached) : UrlSource(url);
  }

  Future<String> _audioCacheDir() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/quran_audio');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  int _currentPlayingIndexOrZero() {
    final detail = _currentDetail;
    if (detail == null || _playingAyahNumber == null) return 0;
    final idx = detail.ayahs
        .indexWhere((a) => a.numberInSurah == _playingAyahNumber);
    return idx < 0 ? 0 : idx;
  }

  Future<void> _downloadClip(String url, String dirPath) async {
    try {
      final segments = Uri.parse(url).pathSegments;
      final name = segments.length >= 2
          ? '${segments[segments.length - 2]}_${segments.last}'
          : segments.last;
      final file = File('$dirPath/$name');
      if (await file.exists() && await file.length() > 0) {
        _audioCache[url] = file.path;
        return;
      }
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(resp.bodyBytes);
        _audioCache[url] = file.path;
      }
    } catch (e) {
      debugPrint('Clip prefetch failed: $e');
    }
  }

  /// Downloads [url] once, even when requested concurrently.
  Future<void> _ensureClipDownloaded(String url) async {
    if (_audioCache.containsKey(url)) return;
    final existing = _inflightDownloads[url];
    if (existing != null) {
      await existing;
      return;
    }
    final dirPath = await _audioCacheDir();
    final download = _downloadClip(url, dirPath);
    _inflightDownloads[url] = download;
    try {
      await download;
    } finally {
      _inflightDownloads.remove(url);
    }
  }

  /// Downloads upcoming clips while the surah plays, staying up to
  /// [_prefetchAhead] ayahs ahead of the recitation.
  Future<void> _runPrefetch() async {
    if (_prefetchActive) return;
    _prefetchActive = true;
    try {
      final detail = _currentDetail;
      if (detail == null) return;
      for (var i = 0; i < detail.ayahs.length; i++) {
        if (!mounted || !(_isFullSurahPlaying || _playingBismillah)) return;
        // Throttle: don't run further than _prefetchAhead ayahs ahead
        while (i > _currentPlayingIndexOrZero() + _prefetchAhead) {
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted || !(_isFullSurahPlaying || _playingBismillah)) return;
        }
        final url = detail.ayahs[i].audioUrl;
        if (url == null) continue;
        await _ensureClipDownloaded(url);
      }
    } finally {
      _prefetchActive = false;
    }
  }

  Future<bool> _playUrlSafe(String url, String label) async {
    try {
      // Reset the player first: play() straight after a completion can fail
      await _player.stop();
      await _player.play(_sourceFor(url));
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
      _playingBismillah = false;
      _timedStreamMode = false;
      _streamTimings = null;
      _pendingStreamStart = false;
      await _player.setVolume(1.0);

      final ok = await _playUrlSafe(url, 'ayah');
      if (ok && mounted) {
        setState(() {
          _playingUrl = url;
          _isFullSurahPlaying = false;
          _playingAyahNumber = null;
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

  /// Plays the surah ayah-by-ayah so the current ayah can be highlighted
  /// and followed on screen.
  /// Attempts continuous single-stream playback with verse timestamps.
  /// Returns false so the caller can fall back to clip-by-clip playback.
  Future<bool> _startTimedStream({int? fromVerse}) async {
    try {
      final timings = await _client
          .fetchSurahTimings(widget.summary.number,
              reciterId: _streamReciterId)
          .timeout(const Duration(seconds: 15));
      if (timings.timings.isEmpty) return false;
      final detail = _currentDetail;
      if (detail == null) return false;

      _streamTimings = timings;
      _stoppedAtAyahNumber = null;
      setState(() {
        _isFullSurahPlaying = true;
        _playingAyahNumber = null;
      });

      final resuming = fromVerse != null && fromVerse > 1;

      // Many continuous recordings start straight at verse 1; recite the
      // standalone Bismillah clip first, then begin the stream.
      final recordingHasIntro = timings.timings.first.fromMs > 500;
      if (!resuming && _hasBismillahHeader && !recordingHasIntro) {
        final started = await _playBismillah(detail);
        if (started) {
          _pendingStreamStart = true;
          return true;
        }
      }

      _timedStreamMode = true;
      setState(() => _playingBismillah =
          !resuming && _hasBismillahHeader && recordingHasIntro);
      final ok = await _playUrlSafe(timings.audioUrl, 'stream');
      if (!ok) {
        _timedStreamMode = false;
        _streamTimings = null;
        setState(() {
          _isFullSurahPlaying = false;
          _playingBismillah = false;
        });
        return false;
      }
      if (resuming) {
        // Jump the continuous recording straight to the saved verse
        final timing = timings.timings.firstWhere(
          (t) => t.verse == fromVerse,
          orElse: () => timings.timings.first,
        );
        await _player.seek(Duration(milliseconds: timing.fromMs));
        setState(() => _playingAyahNumber = timing.verse);
        final index =
            detail.ayahs.indexWhere((a) => a.numberInSurah == timing.verse);
        if (index >= 0) _followAyah(index);
      } else if (_playingBismillah) {
        _showBismillahOnScreen();
      }
      return true;
    } catch (e) {
      debugPrint('Timed stream unavailable, using clips: $e');
      _timedStreamMode = false;
      _streamTimings = null;
      _pendingStreamStart = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(
                'Gapless stream unavailable for $_streamReciterName — playing ayah by ayah.'),
            duration: const Duration(seconds: 3),
          ));
      }
      return false;
    }
  }

  /// Starts the continuous recording after the Bismillah clip finished.
  Future<void> _beginTimedStreamPlayback() async {
    final timings = _streamTimings;
    if (timings == null || !_isFullSurahPlaying) return;
    _timedStreamMode = true;
    final ok = await _playUrlSafe(timings.audioUrl, 'stream');
    _earlyAdvanceTriggered = false;
    if (!ok) {
      // Fall back to clip-by-clip playback
      _timedStreamMode = false;
      _streamTimings = null;
      unawaited(_runPrefetch());
      await _playAyahInSequence(0);
    }
  }

  /// Resumes full-surah playback starting at the saved ayah.
  Future<void> _playFullSurahFrom(int verse) async {
    if (_isFullSurahPlaying) {
      await _stopAudio();
    }
    final detail = _currentDetail;
    if (detail == null || detail.ayahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surah not loaded yet. Please wait.')),
      );
      return;
    }
    setState(() => _audioLoading = true);
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      _stoppedAtAyahNumber = null;

      if (await _startTimedStream(fromVerse: verse)) return;

      // Fallback: clip-by-clip playback from the saved ayah
      setState(() => _isFullSurahPlaying = true);
      final index = detail.ayahs.indexWhere((a) => a.numberInSurah == verse);
      await _playAyahInSequence(index < 0 ? 0 : index);
      unawaited(_runPrefetch());
    } catch (e, stackTrace) {
      debugPrint('Resume playback error: $e');
      debugPrint('Stack trace: $stackTrace');
      await _stopAudio();
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  /// Stops full-surah playback and offers to save the stopping point.
  Future<void> _stopFullSurahWithPrompt() async {
    final lastPlayed = _playingAyahNumber;
    await _stopAudio();
    final detail = _currentDetail;
    if (lastPlayed == null || detail == null || !mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save your place?'),
        content: Text(
            'You stopped at ayah $lastPlayed. Save it so you can continue later?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, save'),
          ),
        ],
      ),
    );
    if (save == true && mounted) {
      final ayah = detail.ayahs.firstWhere(
        (a) => a.numberInSurah == lastPlayed,
        orElse: () => detail.ayahs.last,
      );
      await _saveLastRead(ayah, showMessage: false);
    }
  }

  Future<void> _toggleFullSurah() async {
    if (_isFullSurahPlaying) {
      await _stopFullSurahWithPrompt();
      return;
    }

    final detail = _currentDetail;
    if (detail == null || detail.ayahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Surah not loaded yet. Please wait.')),
      );
      return;
    }

    setState(() => _audioLoading = true);
    try {
      await _player.stop();
      await _player.setVolume(1.0);

      // Preferred: one continuous recording with verse timestamps, so the
      // recitation flows with no transitions at all
      if (await _startTimedStream()) return;

      // Fallback: clip-by-clip playback with prefetching
      _stoppedAtAyahNumber = null;
      setState(() => _isFullSurahPlaying = true);
      // Start downloading the next ~20 ayahs in the background
      unawaited(_runPrefetch());
      final bismillahStarted = await _playBismillah(detail);
      if (!bismillahStarted) {
        await _playAyahInSequence(0);
      }
    } catch (e, stackTrace) {
      debugPrint('Full surah fatal error: $e');
      debugPrint('Stack trace: $stackTrace');
      await _stopAudio();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playback error. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  /// Plays the opening Bismillah (global ayah 1 in the same audio edition)
  /// before the surah. Skipped for Al-Fatiha (its first ayah already is the
  /// Bismillah) and At-Tawbah (recited without it). Returns true if started.
  Future<bool> _playBismillah(SurahDetail detail) async {
    final surahNumber = widget.summary.number;
    if (surahNumber == 1 || surahNumber == 9) return false;
    final firstAudio =
        detail.ayahs.isNotEmpty ? detail.ayahs.first.audioUrl : null;
    if (firstAudio == null) return false;
    final bismillahUrl =
        firstAudio.replaceFirst(RegExp(r'/\d+\.mp3'), '/1.mp3');
    if (bismillahUrl == firstAudio) return false;

    final ok = await _playUrlSafe(bismillahUrl, 'bismillah');
    if (!ok) return false;
    _playingBismillah = true;
    if (mounted) {
      setState(() {
        _playingUrl = bismillahUrl;
        _playingAyahNumber = null;
      });
    }
    _showBismillahOnScreen();
    return true;
  }

  /// Keeps the (unnumbered) Bismillah header visible while it is recited.
  void _showBismillahOnScreen() {
    if (_pagedMode &&
        _pageController.hasClients &&
        (_pageController.page?.round() ?? _currentPageIndex) != 0) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final headerContext = _bismillahKey.currentContext;
      if (headerContext != null) {
        Scrollable.ensureVisible(
          headerContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: 0.05,
        );
      } else if (!_pagedMode && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _playAyahInSequence(int index) async {
    final detail = _currentDetail;
    if (detail == null || !_isFullSurahPlaying) return;
    if (index >= detail.ayahs.length) {
      await _stopAudio();
      return;
    }
    final ayah = detail.ayahs[index];
    final url = ayah.audioUrl;
    if (url == null) {
      // Skip ayahs without audio and continue the sequence
      await _playAyahInSequence(index + 1);
      return;
    }

    bool ok;
    if (_nextPlayer != null && _nextPreloadedIndex == index) {
      // Swap to the pre-buffered player; let the previous clip's tail finish
      // naturally so the transition overlaps instead of hard-stopping
      final previous = _player;
      _player = _nextPlayer!;
      _nextPlayer = null;
      _nextPreloadedIndex = null;
      if (_sparePlayer == null) {
        _sparePlayer = previous;
      } else {
        unawaited(previous.dispose());
      }
      try {
        await _player.resume();
        ok = true;
      } catch (e) {
        debugPrint('Preloaded resume error: $e');
        ok = await _playUrlSafe(url, 'sequence');
      }
    } else {
      // Not preloaded: brief pause keeps iOS happy when chaining plays
      await Future.delayed(const Duration(milliseconds: 60));
      ok = await _playUrlSafe(url, 'sequence');
    }

    if (!ok) {
      await _stopAudio();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play surah audio.')),
        );
      }
      return;
    }
    if (!mounted) return;
    _earlyAdvanceTriggered = false;
    setState(() {
      _playingUrl = url;
      _playingAyahNumber = ayah.numberInSurah;
    });
    _followAyah(index);
    // Buffer the next ayah while this one plays
    unawaited(_preloadAyah(index + 1));
  }

  /// Pre-buffers the next audible ayah on a spare player so the hand-off
  /// between ayahs is almost instant.
  Future<void> _preloadAyah(int index) async {
    final detail = _currentDetail;
    if (detail == null || !(_isFullSurahPlaying || _playingBismillah)) return;
    var i = index;
    while (i < detail.ayahs.length && detail.ayahs[i].audioUrl == null) {
      i++;
    }
    if (i >= detail.ayahs.length) return;
    final url = detail.ayahs[i].audioUrl!;

    var player = _sparePlayer ?? _createSequencePlayer();
    _sparePlayer = null;
    if (player.state == PlayerState.playing) {
      // Recycled player is still finishing its overlapped tail; use a fresh
      // one and keep it for later
      final finishing = player;
      player = _createSequencePlayer();
      _sparePlayer = finishing;
    }
    try {
      // Make sure the clip is a local file before arming the swap player,
      // so the hand-off never waits on the network
      await _ensureClipDownloaded(url);
      if (!(_isFullSurahPlaying || _playingBismillah)) {
        _sparePlayer = player;
        return;
      }
      await player.stop();
      await player.setVolume(1.0);
      await player.setSource(_sourceFor(url));
      _nextPlayer = player;
      _nextPreloadedIndex = i;
    } catch (e) {
      debugPrint('Preload error: $e');
      _sparePlayer = player;
    }
  }

  Future<void> _playNextAyahInSequence() async {
    final detail = _currentDetail;
    if (detail == null || _playingAyahNumber == null) {
      await _stopAudio();
      return;
    }
    final currentIndex = detail.ayahs
        .indexWhere((a) => a.numberInSurah == _playingAyahNumber);
    if (currentIndex < 0 || currentIndex + 1 >= detail.ayahs.length) {
      await _stopAudio();
      return;
    }
    await _playAyahInSequence(currentIndex + 1);
  }

  /// Keeps the currently recited ayah visible (scroll or page mode).
  void _followAyah(int index) {
    final detail = _currentDetail;
    if (detail == null) return;

    if (_pagedMode) {
      final ayahNumber = detail.ayahs[index].numberInSurah;
      final pages = _mushafPages(detail);
      final pageIndex = pages.indexWhere(
        (entry) => entry.value.any((a) => a.numberInSurah == ayahNumber),
      );
      var pageChanged = false;
      if (pageIndex >= 0 &&
          _pageController.hasClients &&
          (_pageController.page?.round() ?? _currentPageIndex) != pageIndex) {
        pageChanged = true;
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
      // Also scroll within the page so the recited ayah stays visible
      Future.delayed(
        Duration(milliseconds: pageChanged ? 500 : 60),
        () {
          if (!mounted || index >= _ayahKeys.length) return;
          final contextForAyah = _ayahKeys[index].currentContext;
          if (contextForAyah != null) {
            Scrollable.ensureVisible(
              contextForAyah,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              alignment: 0.1,
            );
          }
        },
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _ayahKeys.length) return;
      final contextForAyah = _ayahKeys[index].currentContext;
      if (contextForAyah != null) {
        Scrollable.ensureVisible(
          contextForAyah,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      } else if (_scrollController.hasClients) {
        // Card not built yet (far away) - approximate, then refine next ayah
        final fraction = index / detail.ayahs.length;
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          (fraction * maxScroll).clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
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

  // Parchment reading palette (mock-style, independent of app theme)
  static const _parchmentBg = Color(0xFFF3EDE0);
  static const _parchmentCard = Color(0xFFFCF8ED);
  static const _tealDark = Color(0xFF0B3B35);
  static const _tealMid = Color(0xFF14544B);
  static const _goldAccent = Color(0xFFC9A24B);
  static const _inkText = Color(0xFF26343A);

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return WillPopScope(
      onWillPop: _handleExitAttempt,
      child: Scaffold(
        backgroundColor: _parchmentBg,
        body: Column(
          children: [
            _buildHeader(summary),
            Expanded(
              child: FutureBuilder<SurahDetail>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _tealMid),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Unable to load surah. Please try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _inkText),
                        ),
                      ),
                    );
                  }
                  final detail = snapshot.data;
                  if (detail == null) {
                    return const Center(
                      child: Text('No data found.', style: TextStyle(color: _inkText)),
                    );
                  }

                  _currentDetail = detail;
                  _ensureAyahKeysExist(detail.ayahs.length);
                  _maybeAutoJumpToSaved();

                  return Column(
                    children: [
                      _playFullSurahSection(),
                      Expanded(
                        child: _pagedMode
                            ? _buildPagedReader(detail, summary)
                            : Builder(builder: (context) {
                                final next = _nextSurahSummary();
                                final headerCount =
                                    _hasBismillahHeader ? 1 : 0;
                                return ListView.builder(
                                  key: _listViewKey,
                                  controller: _scrollController,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 6, 16, 16),
                                  itemCount: detail.ayahs.length +
                                      headerCount +
                                      (next != null ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (_hasBismillahHeader && index == 0) {
                                      return _bismillahHeader();
                                    }
                                    final ayahIndex = index - headerCount;
                                    if (ayahIndex >= detail.ayahs.length) {
                                      return _nextSurahCard(next!);
                                    }
                                    final ayah = detail.ayahs[ayahIndex];
                                    return _ayahCard(ayah, summary,
                                        key: _ayahKeys[ayahIndex]);
                                  },
                                );
                              }),
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

  /// Teal gradient header with round actions, surah title and the page pill.
  Widget _buildHeader(SurahSummary summary) {
    String pillText;
    final detail = _currentDetail;
    if (_pagedMode && detail != null) {
      final pages = _mushafPages(detail);
      final current =
          pages.isEmpty ? 0 : _currentPageIndex.clamp(0, pages.length - 1);
      final pageNumber = pages.isEmpty ? 0 : pages[current].key;
      pillText = pageNumber > 0
          ? 'Page $pageNumber of 604  •  ${current + 1}/${pages.length} in surah'
          : '${current + 1}/${pages.length} in surah';
    } else {
      pillText = '${summary.ayahCount} verses';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_tealDark, _tealMid],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 8,
        16,
        14,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _roundAction(Icons.arrow_back_ios_new, _onBackPressed),
              const Spacer(),
              _roundAction(Icons.text_fields, _showFontSizeSheet),
              const SizedBox(width: 8),
              _roundAction(
                Icons.translate,
                _toggleTranslation,
                active: _showTranslation,
              ),
              const SizedBox(width: 8),
              _roundAction(
                _pagedMode ? Icons.auto_stories : Icons.view_day_outlined,
                _togglePagedMode,
                active: _pagedMode,
              ),
              const SizedBox(width: 8),
              _roundAction(
                _isSavedOffline ? Icons.bookmark : Icons.bookmark_border,
                _toggleSaveOffline,
                active: _isSavedOffline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${summary.number}. ${summary.nameEnglish}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              summary.nameArabic,
              style: const TextStyle(
                color: _goldAccent,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _goldAccent.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pillText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isSavedOffline) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.offline_pin, color: _goldAccent, size: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundAction(IconData icon, VoidCallback onTap, {bool active = false}) {
    return Material(
      color: Colors.white.withOpacity(active ? 0.22 : 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 19,
            color: active ? _goldAccent : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _playFullSurahCard() {
    final playing = _isFullSurahPlaying;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: _parchmentCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _toggleFullSurah,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: _tealMid,
                    shape: BoxShape.circle,
                  ),
                  child: _audioLoading && playing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          playing ? Icons.stop : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Play full surah',
                        style: TextStyle(
                          color: _inkText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _streamReciterName,
                        style: TextStyle(
                          color: _inkText.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Change reciter
                IconButton(
                  icon: const Icon(Icons.record_voice_over,
                      color: _goldAccent, size: 24),
                  tooltip: 'Choose reciter',
                  onPressed: _showReciterPicker,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playFullSurahSection() {
    final savedAyah = _savedAyahNumber;
    final showResume = savedAyah != null && savedAyah > 1 && !_isFullSurahPlaying;
    return Column(
      children: [
        _playFullSurahCard(),
        if (showResume)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            decoration: BoxDecoration(
              color: _goldAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _goldAccent.withOpacity(0.5)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _playFullSurahFrom(savedAyah),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline,
                          color: Color(0xFF9A7B2E), size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Start where you left off  •  Ayah $savedAyah',
                          style: const TextStyle(
                            color: _inkText,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: _goldAccent, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// English translation rendered word-by-word: hold any word to
  /// see its meaning and grammar.
  Widget _tappableTranslation(String translation, int ayahNumber) {
    final style = TextStyle(
      color: _inkText.withOpacity(0.75),
      fontSize: 16.5 * _fontScale,
      height: 1.55,
    );
    final words = translation.split(RegExp(r'\s+'));
    return Wrap(
      spacing: 5,
      runSpacing: 3,
      children: [
        for (var i = 0; i < words.length; i++)
          GestureDetector(
            // Hold a word to see its meaning and grammar
            onLongPress: () =>
                _showWordMeaning(words[i], ayahNumber: ayahNumber, wordIndex: i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: _heldWordAyah == ayahNumber && _heldWordIndex == i
                    ? _goldAccent.withOpacity(0.45)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(words[i], style: style),
            ),
          ),
      ],
    );
  }

  // Word currently held (highlighted while its meaning sheet is open)
  int? _heldWordAyah;
  int? _heldWordIndex;

  final Map<String, List<Map<String, String>>> _wordMeaningCache = {};

  Future<List<Map<String, String>>> _fetchWordMeaning(String word) async {
    final cached = _wordMeaningCache[word];
    if (cached != null) return cached;
    final resp = await http
        .get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/$word'))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('No definition found');
    }
    final data = jsonDecode(resp.body) as List<dynamic>;
    final results = <Map<String, String>>[];
    for (final entry in data) {
      final meanings =
          (entry as Map<String, dynamic>)['meanings'] as List<dynamic>? ?? [];
      for (final m in meanings) {
        final meaning = m as Map<String, dynamic>;
        final pos = meaning['partOfSpeech'] as String? ?? '';
        final defs = meaning['definitions'] as List<dynamic>? ?? [];
        for (final d in defs.take(2)) {
          final def = d as Map<String, dynamic>;
          results.add({
            'pos': pos,
            'def': def['definition'] as String? ?? '',
            'example': def['example'] as String? ?? '',
          });
          if (results.length >= 6) break;
        }
        if (results.length >= 6) break;
      }
      if (results.length >= 6) break;
    }
    if (results.isEmpty) throw Exception('No definition found');
    _wordMeaningCache[word] = results;
    return results;
  }

  Future<void> _showWordMeaning(String rawWord,
      {int? ayahNumber, int? wordIndex}) async {
    final word =
        rawWord.replaceAll(RegExp(r"[^A-Za-z'\-]"), '').toLowerCase();
    if (word.isEmpty) return;
    // Highlight the held word while the sheet is open
    setState(() {
      _heldWordAyah = ayahNumber;
      _heldWordIndex = wordIndex;
    });
    await showModalBottomSheet(
      context: context,
      backgroundColor: _parchmentCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book, color: _tealMid, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        word,
                        style: const TextStyle(
                          color: _inkText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: _fetchWordMeaning(word),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child:
                                  CircularProgressIndicator(color: _tealMid),
                            ),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No definition found for "$word".',
                              style: TextStyle(
                                  color: _inkText.withOpacity(0.7)),
                            ),
                          );
                        }
                        final meanings = snapshot.data!;
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: meanings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final m = meanings[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((m['pos'] ?? '').isNotEmpty)
                                  Text(
                                    m['pos']!,
                                    style: const TextStyle(
                                      color: Color(0xFF9A7B2E),
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  m['def'] ?? '',
                                  style: const TextStyle(
                                    color: _inkText,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                                if ((m['example'] ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '"${m['example']}"',
                                    style: TextStyle(
                                      color: _inkText.withOpacity(0.55),
                                      fontSize: 13.5,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
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
      },
    );
    if (mounted) {
      setState(() {
        _heldWordAyah = null;
        _heldWordIndex = null;
      });
    }
  }

  /// Lets the user pick among gapless reciters for full-surah playback.
  Future<void> _showReciterPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _parchmentCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.record_voice_over, color: _tealMid),
                      SizedBox(width: 8),
                      Text(
                        'Choose Reciter',
                        style: TextStyle(
                          color: _inkText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: FutureBuilder<List<GaplessReciter>>(
                    future: _client.fetchGaplessReciters(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: _tealMid),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Could not load reciters. Check your connection.',
                            style:
                                TextStyle(color: _inkText.withOpacity(0.7)),
                          ),
                        );
                      }
                      final reciters = snapshot.data!;
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: reciters.length,
                        itemBuilder: (context, index) {
                          final reciter = reciters[index];
                          final selected = reciter.id == _streamReciterId;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: selected
                                  ? _tealMid
                                  : _inkText.withOpacity(0.4),
                            ),
                            title: Text(
                              reciter.name,
                              style: TextStyle(
                                color: _inkText,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: reciter.style.isEmpty
                                ? null
                                : Text(
                                    reciter.style,
                                    style: TextStyle(
                                      color: _inkText.withOpacity(0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                            onTap: () => Navigator.of(context).pop(reciter),
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
      },
    ).then((picked) async {
      if (picked is! GaplessReciter || !mounted) return;
      if (_isFullSurahPlaying) await _stopAudio();
      setState(() {
        _streamReciterId = picked.id;
        _streamReciterName = picked.name;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('quran_reciter_id', picked.id);
      await prefs.setString('quran_reciter_name', picked.name);
    });
  }

  Future<void> _showFontSizeSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _parchmentCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.text_fields, color: _tealMid),
                      SizedBox(width: 8),
                      Text(
                        'Font Size',
                        style: TextStyle(
                          color: _inkText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: _inkText,
                      fontSize: 24 * _fontScale,
                      height: 1.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    value: _fontScale,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    activeColor: _tealMid,
                    label: '${(_fontScale * 100).round()}%',
                    onChanged: (value) {
                      setSheetState(() {});
                      setState(() => _fontScale = value);
                    },
                    onChangeEnd: (value) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('quran_font_scale', value);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Surahs that display a separate (unnumbered) Bismillah header.
  bool get _hasBismillahHeader =>
      widget.summary.number != 1 && widget.summary.number != 9;

  /// The API prepends the Bismillah to ayah 1's text; show it separately.
  String _displayArabic(SurahAyah ayah) {
    if (!_hasBismillahHeader || ayah.numberInSurah != 1) return ayah.arabic;
    final words = ayah.arabic.split(' ');
    if (words.length <= 4) return ayah.arabic;
    // Normalize first word (strip diacritics, alef wasla) and check it's بسم
    final normalized = words.first
        .replaceAll('\u0671', '\u0627')
        .replaceAll(
            RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'),
            '');
    if (normalized == 'بسم') {
      return words.sublist(4).join(' ');
    }
    return ayah.arabic;
  }

  Widget _bismillahHeader() {
    final active = _playingBismillah;
    return Container(
      key: _bismillahKey,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF3EC) : _parchmentCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? _tealMid : _goldAccent.withOpacity(0.4),
          width: active ? 1.6 : 1,
        ),
      ),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: const Color(0xFF9A7B2E),
          fontSize: 22 * _fontScale,
          fontWeight: FontWeight.w700,
          height: 1.6,
        ),
      ),
    );
  }

  /// The next surah's summary, if any (for the end-of-surah footer).
  SurahSummary? _nextSurahSummary() {
    if (widget.summary.number >= 114) return null;
    try {
      final surahs = context.read<QuranProvider>().surahs;
      for (final s in surahs) {
        if (s.number == widget.summary.number + 1) return s;
      }
    } catch (e) {
      debugPrint('Next surah lookup failed: $e');
    }
    return null;
  }

  Widget _nextSurahCard(SurahSummary next) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_tealDark, _tealMid],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _goldAccent.withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => QuranSurahScreen(summary: next),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Continue to next surah',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${next.number}. ${next.nameEnglish}  •  ${next.nameArabic}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: _goldAccent, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A single ayah card used by both scroll and page views.
  Widget _ayahCard(SurahAyah ayah, SurahSummary summary, {Key? key}) {
    final isPlaying = !_isFullSurahPlaying && _playingUrl == ayah.audioUrl;
    final isSaved = summary.number == _savedSurahNumber &&
        ayah.numberInSurah == _savedAyahNumber;
    final isRecited =
        _isFullSurahPlaying && ayah.numberInSurah == _playingAyahNumber;
    final isStopPoint =
        !_isFullSurahPlaying && ayah.numberInSurah == _stoppedAtAyahNumber;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _recordInteraction(ayah.numberInSurah),
      child: Container(
        key: key,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        decoration: BoxDecoration(
          color: isRecited || isStopPoint
              ? const Color(0xFFEAF3EC) // soft teal-tinted parchment
              : _parchmentCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRecited
                ? _tealMid
                : isStopPoint
                    ? _tealMid.withOpacity(0.55)
                    : isSaved
                        ? _goldAccent
                        : _goldAccent.withOpacity(0.25),
            width: isRecited || isStopPoint || isSaved ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Ayah number badge
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tealMid,
                    shape: BoxShape.circle,
                    border: Border.all(color: _goldAccent, width: 1.4),
                  ),
                  child: Text(
                    '${ayah.numberInSurah}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 24,
                  icon: _audioLoading && isPlaying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _tealMid,
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.stop_circle : Icons.play_circle_outline,
                          color: isPlaying ? _tealMid : _tealMid.withOpacity(0.55),
                        ),
                  onPressed: () => _toggleAudio(ayah),
                  tooltip: isPlaying ? 'Stop' : 'Play ayah',
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 22,
                  icon: Icon(
                    isSaved ? Icons.bookmark_added : Icons.bookmark_add_outlined,
                    color: isSaved ? _goldAccent : _tealMid.withOpacity(0.55),
                  ),
                  onPressed: () => _saveLastRead(ayah),
                  tooltip: 'Save and start here',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _displayArabic(ayah),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: _inkText,
                fontSize: 24 * _fontScale,
                fontWeight: FontWeight.w600,
                height: 2.0,
              ),
            ),
            if (_showTranslation && ayah.translation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                height: 0.6,
                color: _goldAccent.withOpacity(0.35),
                margin: const EdgeInsets.symmetric(horizontal: 30),
              ),
              const SizedBox(height: 10),
              _tappableTranslation(ayah.translation, ayah.numberInSurah),
            ],
          ],
        ),
      ),
    );
  }

  /// Mushaf-style page view: one standard (604-page) Quran page per swipe.
  Widget _buildPagedReader(SurahDetail detail, SurahSummary summary) {
    final pages = _mushafPages(detail);
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) => setState(() => _currentPageIndex = index),
      itemCount: pages.length,
      itemBuilder: (context, pageIndex) {
        final ayahs = pages[pageIndex].value;
        final showBismillah = _hasBismillahHeader && pageIndex == 0;
        final next =
            pageIndex == pages.length - 1 ? _nextSurahSummary() : null;
        final headerCount = showBismillah ? 1 : 0;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          itemCount: ayahs.length + headerCount + (next != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (showBismillah && index == 0) return _bismillahHeader();
            final ayahIndex = index - headerCount;
            if (ayahIndex >= ayahs.length) return _nextSurahCard(next!);
            final ayah = ayahs[ayahIndex];
            // Reuse the ayah keys so follow-along can scroll within the page
            return _ayahCard(ayah, summary,
                key: ayah.numberInSurah - 1 < _ayahKeys.length
                    ? _ayahKeys[ayah.numberInSurah - 1]
                    : null);
          },
        );
      },
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

  Future<bool> _handleExitAttempt() async {
    final candidateAyahNumber = _lastInteractedAyahNumber;
    // Only prompt when there is unsaved progress: no interaction, or the
    // spot is already saved (e.g. via the stop prompt), just leave quietly.
    if (candidateAyahNumber == null ||
        candidateAyahNumber == _savedAyahNumber) {
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
    }
    // 'discard' keeps any previously saved bookmark; it only skips saving
    // the new spot.

    return true;
  }
}
