import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/adhan_sound_service.dart';

class AdhanPlayerScreen extends StatefulWidget {
  final String prayerName;

  const AdhanPlayerScreen({
    Key? key,
    required this.prayerName,
  }) : super(key: key);

  @override
  State<AdhanPlayerScreen> createState() => _AdhanPlayerScreenState();
}

class _AdhanPlayerScreenState extends State<AdhanPlayerScreen> {
  final _soundService = AdhanSoundService();
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    debugPrint('🎵 AdhanPlayerScreen opened for ${widget.prayerName}');
    // Don't auto-start playback - it should already be playing from notification
    // The user can tap Play if they want to start it
  }
  
  Future<void> _playAdhan() async {
    try {
      debugPrint('🔊 Starting adhan playback...');
      await _soundService.playAdhan(widget.prayerName);
      debugPrint('✅ Adhan playback started');
    } catch (e) {
      debugPrint('❌ Error starting adhan: $e');
    }
  }

  @override
  void dispose() {
    // Do not auto-stop on dispose; allow foreground service to keep playing
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      // Pause playing
      await _soundService.pauseAdhan();
      setState(() {
        _isPlaying = false;
      });
    } else {
      // Resume playing
      await _soundService.resumeAdhan();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _stop() async {
    await _soundService.stopAdhan();
    // Small delay to ensure native service stops
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent accidental back button - require explicit Stop button
        debugPrint('⚠️ Back button pressed - use Stop button to close');
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a237e), // Deep blue
        body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Prayer icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mosque,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              
              // Prayer name
              Text(
                widget.prayerName,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Prayer Time',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 60),
              
              // Playing indicator with animation
              if (_isPlaying) ...[
                const Icon(
                  Icons.graphic_eq,
                  size: 48,
                  color: Colors.greenAccent,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Playing Adhan',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.pause_circle_outline,
                  size: 48,
                  color: Colors.white70,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paused',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 60),
              
              // Control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/Pause button
                  ElevatedButton(
                    onPressed: _togglePlayPause,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1a237e),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        const SizedBox(width: 8),
                        Text(
                          _isPlaying ? 'PAUSE' : 'PLAY',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  
                  // Stop button
                  ElevatedButton(
                    onPressed: _stop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.stop),
                        SizedBox(width: 8),
                        Text(
                          'STOP',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Hint text
              const Text(
                'Press Stop to dismiss',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
