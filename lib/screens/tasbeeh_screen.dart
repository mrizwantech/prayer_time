import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../presentation/widgets/app_header.dart';
import '../core/prayer_time_service.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen>
    with SingleTickerProviderStateMixin {
  int _count = 0;
  int _targetCount = 33;
  int _selectedDhikrIndex = 0;

  // Calculate total from all saved counts
  int get _totalCount =>
      _savedCounts.values.fold(0, (sum, count) => sum + count);
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Text to speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsEnabled = true;

  // Custom dhikr list (will include both preset and custom)
  List<Map<String, dynamic>> _dhikrList = [];

  // Preset dhikrs
  final List<Map<String, dynamic>> _presetDhikrList = [
    {
      'arabic': 'سُبْحَانَ اللّٰهِ',
      'transliteration': 'SubhanAllah',
      'meaning': 'Glory be to Allah',
      'target': 33,
      'speak': 'Subhan Allah',
      'isCustom': false,
    },
    {
      'arabic': 'الْحَمْدُ لِلّٰهِ',
      'transliteration': 'Alhamdulillah',
      'meaning': 'All praise is due to Allah',
      'target': 33,
      'speak': 'Al hamdu lillah',
      'isCustom': false,
    },
    {
      'arabic': 'اللّٰهُ أَكْبَرُ',
      'transliteration': 'Allahu Akbar',
      'meaning': 'Allah is the Greatest',
      'target': 34,
      'speak': 'Allahu Akbar',
      'isCustom': false,
    },
    {
      'arabic': 'لَا إِلٰهَ إِلَّا اللّٰهُ',
      'transliteration': 'La ilaha illallah',
      'meaning': 'There is no god but Allah',
      'target': 100,
      'speak': 'La ilaha illa Allah',
      'isCustom': false,
    },
    {
      'arabic': 'أَسْتَغْفِرُ اللّٰهَ',
      'transliteration': 'Astaghfirullah',
      'meaning': 'I seek forgiveness from Allah',
      'target': 100,
      'speak': 'Astaghfirullah',
      'isCustom': false,
    },
    {
      'arabic': 'سُبْحَانَ اللّٰهِ وَبِحَمْدِهِ',
      'transliteration': 'SubhanAllahi wa bihamdihi',
      'meaning': 'Glory be to Allah and praise Him',
      'target': 100,
      'speak': 'Subhan Allahi wa bihamdihi',
      'isCustom': false,
    },
    {
      'arabic': 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللّٰهِ',
      'transliteration': 'La hawla wa la quwwata illa billah',
      'meaning': 'There is no power except with Allah',
      'target': 100,
      'speak': 'La hawla wa la quwwata illa billah',
      'isCustom': false,
    },
  ];

  // Saved counts for each dhikr (key: transliteration, value: count)
  Map<String, int> _savedCounts = {};

  @override
  void initState() {
    super.initState();
    _initDhikrList();
    _loadTtsPreference();
    _loadSavedCounts();
    _loadCustomDhikrs();
    _initTts();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _initDhikrList() {
    _dhikrList = List.from(_presetDhikrList);
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

  Future<void> _loadSavedCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCountsJson = prefs.getString('tasbeeh_saved_counts');
    if (savedCountsJson != null) {
      setState(() {
        _savedCounts = Map<String, int>.from(json.decode(savedCountsJson));
      });
    }
  }

  Future<void> _saveSavedCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasbeeh_saved_counts', json.encode(_savedCounts));
  }

  Future<void> _loadCustomDhikrs() async {
    final prefs = await SharedPreferences.getInstance();
    final customDhikrsJson = prefs.getString('tasbeeh_custom_dhikrs');
    if (customDhikrsJson != null) {
      final customDhikrs = List<Map<String, dynamic>>.from(
        json.decode(customDhikrsJson).map((x) => Map<String, dynamic>.from(x)),
      );
      setState(() {
        _dhikrList = [..._presetDhikrList, ...customDhikrs];
      });
    }
  }

  Future<void> _saveCustomDhikrs() async {
    final prefs = await SharedPreferences.getInstance();
    final customDhikrs = _dhikrList
        .where((d) => d['isCustom'] == true)
        .toList();
    await prefs.setString('tasbeeh_custom_dhikrs', json.encode(customDhikrs));
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

      // Save count for this dhikr
      final dhikrKey = _dhikrList[_selectedDhikrIndex]['transliteration'];
      _savedCounts[dhikrKey] = _count;

      // Check if target reached (only if not unlimited)
      if (_targetCount > 0 && _count >= _targetCount) {
        _onTargetReached();
      }
    });

    _saveSavedCounts();
  }

  void _onTargetReached() async {
    // Only show completion for non-unlimited targets
    if (_targetCount <= 0) return;

    // Stronger vibration pattern
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 100]);
    }

    // Show completion dialog
    if (mounted) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '🎉 Completed!',
            style: TextStyle(color: theme.colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You have completed $_targetCount ${_dhikrList[_selectedDhikrIndex]['transliteration']}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'May Allah accept your worship',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
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
              child: Text(
                'Reset',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Continue',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
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
    // Clear saved count for this dhikr
    final dhikrKey = _dhikrList[_selectedDhikrIndex]['transliteration'];
    _savedCounts.remove(dhikrKey);
    _saveSavedCounts();
  }

  void _selectDhikr(int index) {
    // Save current count before switching
    if (_count > 0) {
      final currentDhikrKey =
          _dhikrList[_selectedDhikrIndex]['transliteration'];
      _savedCounts[currentDhikrKey] = _count;
      _saveSavedCounts();
    }

    setState(() {
      _selectedDhikrIndex = index;
      _targetCount = _dhikrList[index]['target'];
      // Load saved count for this dhikr
      final dhikrKey = _dhikrList[index]['transliteration'];
      _count = _savedCounts[dhikrKey] ?? 0;
    });
    // Speak the selected dhikr
    _speakDhikr();
  }

  void _showAddCustomDhikrDialog() {
    final arabicController = TextEditingController();
    final transliterationController = TextEditingController();
    final meaningController = TextEditingController();
    bool isUnlimited = true;
    int customTarget = 100;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Add Custom Dhikr',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: arabicController,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'Arabic Text (optional)',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    hintText: 'سُبْحَانَ اللّٰهِ',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: transliterationController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Dhikr Name / Text *',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    hintText: 'e.g., SubhanAllah',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: meaningController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Meaning (optional)',
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    hintText: 'e.g., Glory be to Allah',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Unlimited toggle
                Row(
                  children: [
                    Text(
                      'Unlimited Count',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: isUnlimited,
                      onChanged: (value) {
                        setDialogState(() {
                          isUnlimited = value;
                        });
                      },
                      activeThumbColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
                if (!isUnlimited) ...[
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    onChanged: (value) {
                      customTarget = int.tryParse(value) ?? 100;
                    },
                    decoration: InputDecoration(
                      labelText: 'Target Count',
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      hintText: '100',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.onSurface.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                if (transliterationController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a dhikr name/text'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newDhikr = {
                  'arabic': arabicController.text.trim().isEmpty
                      ? transliterationController.text.trim()
                      : arabicController.text.trim(),
                  'transliteration': transliterationController.text.trim(),
                  'meaning': meaningController.text.trim().isEmpty
                      ? 'Custom Dhikr'
                      : meaningController.text.trim(),
                  'target': isUnlimited
                      ? -1
                      : customTarget, // -1 means unlimited
                  'speak': transliterationController.text.trim(),
                  'isCustom': true,
                };

                setState(() {
                  _dhikrList.add(newDhikr);
                  _selectedDhikrIndex = _dhikrList.length - 1;
                  _targetCount = newDhikr['target'] as int;
                  _count = 0;
                });

                _saveCustomDhikrs();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Added "${transliterationController.text.trim()}"',
                    ),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              },
              child: Text(
                'Add',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCustomDhikrDialog(int index) {
    final dhikr = _dhikrList[index];
    if (dhikr['isCustom'] != true) return;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Custom Dhikr?',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to delete "${dhikr['transliteration']}"?',
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                // Remove saved count
                _savedCounts.remove(dhikr['transliteration']);
                // Remove dhikr
                _dhikrList.removeAt(index);
                // Reset selection if needed
                if (_selectedDhikrIndex >= _dhikrList.length) {
                  _selectedDhikrIndex = 0;
                  _targetCount = _dhikrList[0]['target'];
                  _count = _savedCounts[_dhikrList[0]['transliteration']] ?? 0;
                }
              });
              _saveCustomDhikrs();
              _saveSavedCounts();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;

    final dhikr = _dhikrList[_selectedDhikrIndex];
    final isUnlimited = _targetCount <= 0;
    final progressPercent = isUnlimited
        ? 0.0
        : (_count / _targetCount).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // App Header - same as home screen
            Consumer<PrayerTimeService>(
              builder: (context, prayerService, _) => AppHeader(
                city: prayerService.city,
                state: prayerService.state,
                isLoading: prayerService.isLoading,
                onRefresh: () => prayerService.refresh(),
                showLocation: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dhikr dropdown selector with add button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Add custom dhikr button
                          GestureDetector(
                            onTap: _showAddCustomDhikrDialog,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accentColor.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Icon(Icons.add, color: accentColor, size: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Dropdown selector
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: textColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: textColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedDhikrIndex,
                                  isExpanded: true,
                                  dropdownColor: surfaceColor,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: accentColor,
                                  ),
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  items: List.generate(_dhikrList.length, (index) {
                                    final item = _dhikrList[index];
                                    final target = item['target'] as int;
                                    final isCustom = item['isCustom'] == true;
                                    final savedCount =
                                        _savedCounts[item['transliteration']] ?? 0;
                                    return DropdownMenuItem<int>(
                                      value: index,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['transliteration'],
                                              style: TextStyle(color: textColor),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (savedCount > 0)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: accentColor,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                savedCount > 999
                                                    ? '999+'
                                                    : '$savedCount',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.black
                                                      : Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          Text(
                                            target <= 0 ? '∞' : '${target}x',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 12,
                                              fontWeight: target <= 0
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          if (isCustom)
                                            GestureDetector(
                                              onTap: () {
                                                // Close dropdown first by navigating back
                                                Navigator.of(context).pop();
                                                // Then show delete dialog with captured index
                                                Future.delayed(
                                                  const Duration(milliseconds: 100),
                                                  () => _showDeleteCustomDhikrDialog(
                                                    index,
                                                  ),
                                                );
                                              },
                                              child: const Padding(
                                                padding: EdgeInsets.only(left: 8),
                                                child: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                  onChanged: (index) {
                                    if (index != null) _selectDhikr(index);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sound toggle button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _ttsEnabled = !_ttsEnabled;
                              });
                              _saveTtsPreference();
                              if (_ttsEnabled) {
                                _speakDhikr();
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _ttsEnabled
                                    ? accentColor.withOpacity(0.2)
                                    : textColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                                color: _ttsEnabled
                                    ? accentColor
                                    : textColor.withOpacity(0.5),
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Arabic text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        dhikr['arabic'],
                        style: TextStyle(
                          color: textColor,
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
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dhikr['meaning'],
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                              child: isUnlimited
                                  ? Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: accentColor.withOpacity(0.3),
                                          width: 8,
                                        ),
                                      ),
                                    )
                                  : CircularProgressIndicator(
                                      value: progressPercent,
                                      strokeWidth: 8,
                                      backgroundColor: textColor.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        accentColor,
                                      ),
                                    ),
                            ),
                            // Counter
                            Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: textColor.withOpacity(0.1),
                                border: Border.all(
                                  color: textColor.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$_count',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 64,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    isUnlimited ? '∞ unlimited' : 'of $_targetCount',
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.6),
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
                      style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    // Reset button and total count
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Total count
                          Row(
                            children: [
                              Icon(Icons.all_inclusive, color: accentColor, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Total: $_totalCount',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 24),
                          // Reset button
                          ElevatedButton.icon(
                            onPressed: _reset,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reset'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: textColor.withOpacity(0.1),
                              foregroundColor: textColor.withOpacity(0.7),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: textColor.withOpacity(0.2)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
