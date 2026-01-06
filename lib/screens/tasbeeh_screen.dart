import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/prayer_theme_provider.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> with SingleTickerProviderStateMixin {
  int _count = 0;
  int _targetCount = 33;
  int _totalCount = 0;
  int _selectedDhikrIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // Text to speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsEnabled = true;
  
  final List<Map<String, dynamic>> _dhikrList = [
    {
      'arabic': 'سُبْحَانَ اللّٰهِ',
      'transliteration': 'SubhanAllah',
      'meaning': 'Glory be to Allah',
      'target': 33,
      'speak': 'Subhan Allah',
    },
    {
      'arabic': 'الْحَمْدُ لِلّٰهِ',
      'transliteration': 'Alhamdulillah',
      'meaning': 'All praise is due to Allah',
      'target': 33,
      'speak': 'Al hamdu lillah',
    },
    {
      'arabic': 'اللّٰهُ أَكْبَرُ',
      'transliteration': 'Allahu Akbar',
      'meaning': 'Allah is the Greatest',
      'target': 34,
      'speak': 'Allahu Akbar',
    },
    {
      'arabic': 'لَا إِلٰهَ إِلَّا اللّٰهُ',
      'transliteration': 'La ilaha illallah',
      'meaning': 'There is no god but Allah',
      'target': 100,
      'speak': 'La ilaha illa Allah',
    },
    {
      'arabic': 'أَسْتَغْفِرُ اللّٰهَ',
      'transliteration': 'Astaghfirullah',
      'meaning': 'I seek forgiveness from Allah',
      'target': 100,
      'speak': 'Astaghfirullah',
    },
    {
      'arabic': 'سُبْحَانَ اللّٰهِ وَبِحَمْدِهِ',
      'transliteration': 'SubhanAllahi wa bihamdihi',
      'meaning': 'Glory be to Allah and praise Him',
      'target': 100,
      'speak': 'Subhan Allahi wa bihamdihi',
    },
    {
      'arabic': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللّٰهِ',
      'transliteration': 'La hawla wa la quwwata illa billah',
      'meaning': 'There is no power except with Allah',
      'target': 100,
      'speak': 'La hawla wa la quwwata illa billah',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTotalCount();
    _loadTtsPreference();
    _initTts();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4); // Slower for dhikr
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _flutterTts.stop();
    super.dispose();
  }
  
  Future<void> _loadTtsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ttsEnabled = prefs.getBool('tasbeeh_tts_enabled') ?? true;
    });
  }
  
  Future<void> _saveTtsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tasbeeh_tts_enabled', _ttsEnabled);
  }

  Future<void> _loadTotalCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _totalCount = prefs.getInt('tasbeeh_total_count') ?? 0;
    });
  }

  Future<void> _saveTotalCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tasbeeh_total_count', _totalCount);
  }
  
  Future<void> _speakDhikr() async {
    if (_ttsEnabled) {
      final text = _dhikrList[_selectedDhikrIndex]['speak'];
      await _flutterTts.speak(text);
    }
  }

  void _increment() async {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    // Vibrate
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 20);
    }
    
    setState(() {
      _count++;
      _totalCount++;
      
      // Check if target reached
      if (_count >= _targetCount) {
        _onTargetReached();
      }
    });
    
    _saveTotalCount();
  }

  void _onTargetReached() async {
    // Stronger vibration pattern
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 100]);
    }
    
    // Show completion dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1d2e),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '🎉 Completed!',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have completed $_targetCount ${_dhikrList[_selectedDhikrIndex]['transliteration']}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'May Allah accept your worship',
                style: TextStyle(color: Color(0xFF00D9A5), fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reset();
              },
              child: const Text('Reset', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Continue', style: TextStyle(color: Color(0xFF00D9A5))),
            ),
          ],
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      _count = 0;
    });
  }

  void _selectDhikr(int index) {
    setState(() {
      _selectedDhikrIndex = index;
      _targetCount = _dhikrList[index]['target'];
      _count = 0;
    });
    // Speak the selected dhikr
    _speakDhikr();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = PrayerThemeProvider();
    final currentTheme = themeProvider.getCurrentTheme('Isha'); // Use Isha theme for Tasbeeh
    final dhikr = _dhikrList[_selectedDhikrIndex];
    final progressPercent = (_count / _targetCount).clamp(0.0, 1.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: currentTheme.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Sound toggle button
                    IconButton(
                      icon: Icon(
                        _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                        color: _ttsEnabled ? const Color(0xFF00D9A5) : Colors.white54,
                      ),
                      onPressed: () {
                        setState(() {
                          _ttsEnabled = !_ttsEnabled;
                        });
                        _saveTtsPreference();
                        if (_ttsEnabled) {
                          // Speak current dhikr when enabling
                          _speakDhikr();
                        }
                      },
                      tooltip: _ttsEnabled ? 'Sound On' : 'Sound Off',
                    ),
                    const Expanded(
                      child: Text(
                        'Tasbeeh Counter',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: _reset,
                    ),
                  ],
                ),
              ),
              
              // Total count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.all_inclusive, color: Color(0xFF00D9A5), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Total: $_totalCount',
                      style: const TextStyle(
                        color: Color(0xFF00D9A5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Dhikr selector
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _dhikrList.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedDhikrIndex;
                    return GestureDetector(
                      onTap: () => _selectDhikr(index),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? const Color(0xFF00D9A5).withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected 
                                ? const Color(0xFF00D9A5)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _dhikrList[index]['transliteration'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_dhikrList[index]['target']}x',
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF00D9A5) : Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const Spacer(),
              
              // Arabic text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  dhikr['arabic'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'serif',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dhikr['transliteration'],
                style: const TextStyle(
                  color: Color(0xFF00D9A5),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dhikr['meaning'],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
              
              const Spacer(),
              
              // Counter circle - tap area
              GestureDetector(
                onTap: _increment,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Progress ring
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: progressPercent,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D9A5)),
                        ),
                      ),
                      // Counter
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$_count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'of $_targetCount',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              Text(
                'Tap to count',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
