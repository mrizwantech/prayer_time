import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Spoken cues for the rakat tracker.
///
/// Each cue is a recorded clip in `assets/audio/coach/<fileName>.m4a`; replace
/// a file with a new recording of the same name to change the voice.
enum PrayerCue {
  missedRuku(
    'missed_ruku',
    'Ruku missed',
    'Please stand up and bow for ruku.',
  ),
  missedQawmah(
    'missed_qawmah',
    'Stand up after ruku',
    'Stand up straight before going down for sujood.',
  ),
  missedSecondSujood(
    'missed_sujood_2',
    'Second sujood missed',
    'Please go back down for sujood.',
  ),
  missedFirstTashahhud(
    'missed_first_tashahhud',
    'First tashahhud missed',
    'Continue your prayer and do sujood as-sahw at the end.',
  ),
  standForNextRakat(
    'stand_next_rakat',
    'Not the last rakat',
    'Please stand up for the next rakat.',
  ),
  extraRakat(
    'extra_rakat',
    'That was the last rakat',
    'Please sit for the final tashahhud.',
  ),
  lastRakat('last_rakat', 'Last rakat', 'This is the last rakat.'),
  rememberSahw(
    'remember_sahw',
    'Sujood as-sahw',
    'Remember to do sujood as-sahw.',
  );

  const PrayerCue(this.fileName, this.title, this.message);
  final String fileName;
  final String title;
  final String message;
}

class PrayerCoachAudio {
  static const maxAnnouncedRakat = 20;

  final AudioPlayer _player = AudioPlayer(playerId: 'prayer_coach');
  final Queue<String> _queue = Queue<String>();
  StreamSubscription<void>? _completeSub;
  bool _playing = false;
  bool _disposed = false;

  PrayerCoachAudio() {
    unawaited(
      _player.setAudioContext(
        AudioContextConfig(
          // Play even with the ringer switch on silent, ducking other audio.
          respectSilence: false,
          focus: AudioContextConfigFocus.duckOthers,
        ).build(),
      ),
    );
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
    _completeSub = _player.onPlayerComplete.listen((_) {
      _playing = false;
      _playNext();
    });
  }

  void say(PrayerCue cue) => _enqueue(cue.fileName);

  /// Announces "First rakat", "Second rakat", ... and adds "This is the last
  /// rakat" when [isLast].
  void announceRakat(int rakat, {required bool isLast}) {
    if (rakat >= 1 && rakat <= maxAnnouncedRakat) _enqueue('rakat_$rakat');
    if (isLast) _enqueue(PrayerCue.lastRakat.fileName);
  }

  void clear() {
    _queue.clear();
    _playing = false;
    unawaited(_player.stop());
  }

  void _enqueue(String fileName) {
    if (_disposed) return;
    _queue.add(fileName);
    _playNext();
  }

  void _playNext() {
    if (_disposed || _playing || _queue.isEmpty) return;
    final fileName = _queue.removeFirst();
    _playing = true;
    _player.play(AssetSource('audio/coach/$fileName.m4a')).catchError((
      Object e,
    ) {
      debugPrint('[PrayerCoach] could not play $fileName: $e');
      _playing = false;
      _playNext();
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _queue.clear();
    await _completeSub?.cancel();
    await _player.dispose();
  }
}
