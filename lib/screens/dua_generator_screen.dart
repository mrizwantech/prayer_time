import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../core/prayer_time_service.dart';
import '../presentation/widgets/app_header.dart';

class DuaGeneratorScreen extends StatefulWidget {
  const DuaGeneratorScreen({super.key});

  @override
  State<DuaGeneratorScreen> createState() => _DuaGeneratorScreenState();
}

class _DuaGeneratorScreenState extends State<DuaGeneratorScreen> {
  String? _selectedCategory;
  final TextEditingController _situationController = TextEditingController();
  Map<String, dynamic>? _generatedDua;
  final _random = Random();

  // TTS variables
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isPaused = false;
  int _repeatCount = 1;
  int _currentRepeat = 0;
  double _speechRate = 0.4;

  final Map<String, DuaCategory> _duaDatabase = {
    'health': DuaCategory(
      icon: Icons.favorite_outline,
      color: const Color(0xFFFEE2E2),
      iconColor: const Color(0xFFDC2626),
      openings: [
        DuaPart(
          arabic: 'اللَّهُمَّ رَبَّ النَّاسِ',
          transliteration: 'Allahumma Rabban-nas',
          translation: 'O Allah, Lord of mankind',
        ),
        DuaPart(
          arabic: 'يَا شَافِي يَا كَافِي',
          transliteration: 'Ya Shafi Ya Kafi',
          translation: 'O Healer, O Sufficient One',
        ),
      ],
      bodies: [
        DuaPart(
          arabic: 'أَذْهِبِ الْبَأْسَ، اشْفِ أَنْتَ الشَّافِي',
          transliteration: 'Adhhib al-ba\'s, ishfi anta ash-Shafi',
          translation: 'Remove the hardship and cure, for You are the Healer',
        ),
        DuaPart(
          arabic: 'لاَ شِفَاءَ إِلاَّ شِفَاؤُكَ',
          transliteration: 'La shifa\'a illa shifa\'uk',
          translation: 'There is no cure except Your cure',
        ),
        DuaPart(
          arabic: 'اشْفِنِي وَعَافِنِي فِي بَدَنِي',
          transliteration: 'Ishfini wa \'aafini fi badani',
          translation: 'Heal me and grant me well-being in my body',
        ),
      ],
      closings: [
        DuaPart(
          arabic: 'شِفَاءً لاَ يُغَادِرُ سَقَمًا',
          transliteration: 'Shifa\'an la yughadiru saqaman',
          translation: 'A cure that leaves no illness behind',
        ),
        DuaPart(
          arabic: 'آمِين يَا رَبَّ الْعَالَمِينَ',
          transliteration: 'Ameen Ya Rabbal \'Alameen',
          translation: 'Ameen, O Lord of all worlds',
        ),
      ],
    ),
    'guidance': DuaCategory(
      icon: Icons.menu_book_outlined,
      color: const Color(0xFFDBEAFE),
      iconColor: const Color(0xFF2563EB),
      openings: [
        DuaPart(
          arabic: 'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ',
          transliteration: 'Allahumma inni astakhiruka bi\'ilmik',
          translation: 'O Allah, I seek Your guidance by Your knowledge',
        ),
        DuaPart(
          arabic: 'رَبَّنَا',
          transliteration: 'Rabbana',
          translation: 'Our Lord',
        ),
      ],
      bodies: [
        DuaPart(
          arabic: 'اهْدِنَا الصِّرَاطَ الْمُسْتَقِيمَ',
          transliteration: 'Ihdinas-siratal mustaqeem',
          translation: 'Guide us to the straight path',
        ),
        DuaPart(
          arabic: 'آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً',
          transliteration: 'Aatina fid-dunya hasanah wa fil-akhirati hasanah',
          translation: 'Grant us good in this world and good in the Hereafter',
        ),
        DuaPart(
          arabic: 'رَبِّ زِدْنِي عِلْمًا',
          transliteration: 'Rabbi zidni \'ilma',
          translation: 'My Lord, increase me in knowledge',
        ),
      ],
      closings: [
        DuaPart(
          arabic: 'وَقِنَا عَذَابَ النَّارِ',
          transliteration: 'Wa qina \'adhaban-nar',
          translation: 'And protect us from the punishment of the Fire',
        ),
        DuaPart(
          arabic: 'إِنَّكَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
          transliteration: 'Innaka \'ala kulli shay\'in Qadeer',
          translation: 'Indeed You have power over all things',
        ),
      ],
    ),
    'work': DuaCategory(
      icon: Icons.business_center_outlined,
      color: const Color(0xFFDCFCE7),
      iconColor: const Color(0xFF16A34A),
      openings: [
        DuaPart(
          arabic: 'اللَّهُمَّ يَا رَزَّاقُ',
          transliteration: 'Allahumma Ya Razzaq',
          translation: 'O Allah, O Provider',
        ),
        DuaPart(
          arabic: 'اللَّهُمَّ اكْفِنِي بِحَلاَلِكَ عَنْ حَرَامِكَ',
          transliteration: 'Allahumma-kfini bihalalika \'an haramik',
          translation:
              'O Allah, suffice me with what is lawful against what is unlawful',
        ),
      ],
      bodies: [
        DuaPart(
          arabic: 'بَارِكْ لِي فِيمَا رَزَقْتَنِي',
          transliteration: 'Barik li fima razaqtani',
          translation: 'Bless what You have provided me',
        ),
        DuaPart(
          arabic: 'وَارْزُقْنِي رِزْقًا حَلاَلاً طَيِّبًا',
          transliteration: 'Warzuqni rizqan halalan tayyiba',
          translation: 'And grant me lawful and pure provision',
        ),
        DuaPart(
          arabic: 'وَاجْعَلْ عَمَلِي صَالِحًا',
          transliteration: 'Waj\'al \'amali salihan',
          translation: 'And make my work righteous',
        ),
      ],
      closings: [
        DuaPart(
          arabic: 'وَأَغْنِنِي بِفَضْلِكَ عَمَّنْ سِوَاكَ',
          transliteration: 'Wa aghnini bifadlika \'amman siwak',
          translation:
              'And make me independent of all besides You through Your bounty',
        ),
        DuaPart(
          arabic: 'إِنَّكَ أَنْتَ الرَّزَّاقُ ذُو الْقُوَّةِ الْمَتِينُ',
          transliteration: 'Innaka anta ar-Razzaq dhul-Quwwatil-Mateen',
          translation:
              'Indeed You are the Provider, the Possessor of firm strength',
        ),
      ],
    ),
    'family': DuaCategory(
      icon: Icons.people_outline,
      color: const Color(0xFFF3E8FF),
      iconColor: const Color(0xFF9333EA),
      openings: [
        DuaPart(
          arabic: 'رَبَّنَا',
          transliteration: 'Rabbana',
          translation: 'Our Lord',
        ),
        DuaPart(
          arabic: 'اللَّهُمَّ أَصْلِحْ ذَاتَ بَيْنِنَا',
          transliteration: 'Allahumma aslih dhata baynina',
          translation: 'O Allah, reconcile our hearts',
        ),
      ],
      bodies: [
        DuaPart(
          arabic:
              'هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ',
          transliteration:
              'Hab lana min azwajina wa dhurriyatina qurrata a\'yun',
          translation:
              'Grant us from our spouses and offspring comfort to our eyes',
        ),
        DuaPart(
          arabic: 'رَبِّ اجْعَلْنِي مُقِيمَ الصَّلاَةِ وَمِن ذُرِّيَّتِي',
          transliteration: 'Rabbi-j\'alni muqimas-salati wa min dhurriyyati',
          translation:
              'My Lord, make me an establisher of prayer, and from my descendants',
        ),
        DuaPart(
          arabic: 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
          transliteration: 'Rabbi-rhamhuma kama rabbayani saghira',
          translation:
              'My Lord, have mercy upon them as they brought me up when I was small',
        ),
      ],
      closings: [
        DuaPart(
          arabic: 'وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
          transliteration: 'Waj\'alna lil-muttaqeena imama',
          translation: 'And make us leaders for the righteous',
        ),
        DuaPart(
          arabic: 'رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ سَمِيعُ الدُّعَاءِ',
          transliteration: 'Rabbana taqabbal minna innaka Samee\'ud-du\'a',
          translation:
              'Our Lord, accept from us. Indeed, You are the Hearer of prayer',
        ),
      ],
    ),
    'peace': DuaCategory(
      icon: Icons.spa_outlined,
      color: const Color(0xFFFEF9C3),
      iconColor: const Color(0xFFCA8A04),
      openings: [
        DuaPart(
          arabic: 'اللَّهُمَّ أَنْتَ السَّلاَمُ وَمِنْكَ السَّلاَمُ',
          transliteration: 'Allahumma anta as-Salam wa minka as-Salam',
          translation: 'O Allah, You are Peace and from You is peace',
        ),
        DuaPart(
          arabic: 'رَبِّ اشْرَحْ لِي صَدْرِي',
          transliteration: 'Rabbi-shrah li sadri',
          translation: 'My Lord, expand for me my chest',
        ),
      ],
      bodies: [
        DuaPart(
          arabic: 'وَيَسِّرْ لِي أَمْرِي',
          transliteration: 'Wa yassir li amri',
          translation: 'And ease for me my affair',
        ),
        DuaPart(
          arabic: 'اللَّهُمَّ اجْعَلْ فِي قَلْبِي نُورًا',
          transliteration: 'Allahumma-j\'al fi qalbi nura',
          translation: 'O Allah, place light in my heart',
        ),
        DuaPart(
          arabic: 'أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ',
          transliteration: 'A\'udhu bika minal-hammi wal-hazan',
          translation: 'I seek refuge in You from anxiety and sorrow',
        ),
      ],
      closings: [
        DuaPart(
          arabic: 'تَبَارَكْتَ يَا ذَا الْجَلاَلِ وَالإِكْرَامِ',
          transliteration: 'Tabarakta ya dhal-Jalali wal-Ikram',
          translation: 'Blessed are You, O Possessor of Majesty and Honor',
        ),
        DuaPart(
          arabic: 'آمِين',
          transliteration: 'Ameen',
          translation: 'Ameen',
        ),
      ],
    ),
  };

  final List<Map<String, String>> _categories = [
    {
      'id': 'health',
      'name': 'Health & Healing',
      'desc': 'Physical or mental health concerns',
    },
    {
      'id': 'guidance',
      'name': 'Guidance & Wisdom',
      'desc': 'Seeking direction in life',
    },
    {
      'id': 'work',
      'name': 'Work & Provision',
      'desc': 'Career, business, rizq',
    },
    {
      'id': 'family',
      'name': 'Family & Relationships',
      'desc': 'Family matters and loved ones',
    },
    {
      'id': 'peace',
      'name': 'Peace & Tranquility',
      'desc': 'Inner peace and calmness',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // Use English TTS for transliteration (most compatible)
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      _onTtsComplete();
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _currentRepeat = 0;
      });
    });
  }

  void _onTtsComplete() {
    if (_currentRepeat < _repeatCount) {
      // Continue with next repeat
      _speakDua();
    } else {
      // Finished all repeats
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
        _currentRepeat = 0;
      });
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _situationController.dispose();
    super.dispose();
  }

  void _generateDua() {
    if (_selectedCategory == null) return;

    final category = _duaDatabase[_selectedCategory]!;

    final opening =
        category.openings[_random.nextInt(category.openings.length)];
    final body = category.bodies[_random.nextInt(category.bodies.length)];
    final closing =
        category.closings[_random.nextInt(category.closings.length)];

    setState(() {
      _generatedDua = {
        'opening': opening,
        'body': body,
        'closing': closing,
        'category': _selectedCategory,
        'situation': _situationController.text.trim(),
      };
    });
  }

  void _reset() {
    // Stop any ongoing TTS
    _stopSpeaking();
    // Go back to home screen - user needs to watch another ad for new dua
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Watch another ad to generate a new dua'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _speakDua() async {
    if (_generatedDua == null) {
      debugPrint('TTS Error: No dua generated yet');
      return;
    }

    final opening = _generatedDua!['opening'] as DuaPart;
    final body = _generatedDua!['body'] as DuaPart;
    final closing = _generatedDua!['closing'] as DuaPart;

    // Use English TTS to read the English translation
    await _flutterTts.setLanguage('en-US');
    final textToSpeak =
        '${opening.translation}. ${body.translation}. ${closing.translation}';

    // Validate text before speaking
    if (textToSpeak.trim().isEmpty) {
      debugPrint('TTS Error: Text to speak is empty');
      return;
    }

    debugPrint('=== TTS Speaking ===');
    debugPrint('Text: $textToSpeak');

    _currentRepeat++;
    setState(() => _isSpeaking = true);

    // Speak the text
    await _flutterTts.speak(textToSpeak);
  }

  Future<void> _startSpeaking() async {
    _currentRepeat = 0;
    await _flutterTts.setSpeechRate(_speechRate);
    await _speakDua();
  }

  Future<void> _pauseSpeaking() async {
    if (_isSpeaking && !_isPaused) {
      await _flutterTts.pause();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _resumeSpeaking() async {
    // FlutterTts doesn't support true resume, so we restart
    if (_isPaused) {
      setState(() => _isPaused = false);
      await _speakDua();
    }
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _isPaused = false;
      _currentRepeat = 0;
    });
  }

  void _showTtsSettings() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = isDark ? const Color(0xFF252836) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reading Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close, color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // TTS uses English transliteration for better compatibility
            StatefulBuilder(
              builder: (context, setModalState) => Column(
                children: [
                  // Repeat Count
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Repeat Count',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_repeatCount > 1) {
                              setModalState(() => _repeatCount--);
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                          color: accentColor,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$_repeatCount×',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (_repeatCount < 100) {
                              setModalState(() => _repeatCount++);
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          color: accentColor,
                        ),
                        const SizedBox(width: 8),
                        // Quick presets
                        _buildQuickRepeat(
                          3,
                          setModalState,
                          accentColor,
                          isDark,
                        ),
                        _buildQuickRepeat(
                          7,
                          setModalState,
                          accentColor,
                          isDark,
                        ),
                        _buildQuickRepeat(
                          33,
                          setModalState,
                          accentColor,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Speech Rate
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Speed',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.slow_motion_video,
                        color: textColor.withOpacity(0.5),
                      ),
                      Expanded(
                        child: Slider(
                          value: _speechRate,
                          min: 0.2,
                          max: 0.8,
                          divisions: 6,
                          activeColor: accentColor,
                          onChanged: (value) {
                            setModalState(() => _speechRate = value);
                            setState(() {});
                          },
                        ),
                      ),
                      Icon(Icons.speed, color: textColor.withOpacity(0.5)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRepeat(
    int count,
    StateSetter setModalState,
    Color accentColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () {
          setModalState(() => _repeatCount = count);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _repeatCount == count
                ? accentColor
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count×',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _repeatCount == count
                  ? Colors.black
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }

  void _copyDua() {
    if (_generatedDua == null) return;

    final opening = _generatedDua!['opening'] as DuaPart;
    final body = _generatedDua!['body'] as DuaPart;
    final closing = _generatedDua!['closing'] as DuaPart;

    final text =
        '''
${opening.arabic}
${body.arabic}
${closing.arabic}

${opening.transliteration}
${body.transliteration}
${closing.transliteration}

${opening.translation}
${body.translation}
${closing.translation}
''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dua copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareDua() {
    if (_generatedDua == null) return;

    final opening = _generatedDua!['opening'] as DuaPart;
    final body = _generatedDua!['body'] as DuaPart;
    final closing = _generatedDua!['closing'] as DuaPart;
    final situation = _generatedDua!['situation'] as String;

    // Create branded Azanify share text
    final shareText =
        '''
✨ *My Personalized Dua* ✨

━━━━━━━━━━━━━━━━━━━━━

📿 *Arabic:*
${opening.arabic}
${body.arabic}
${closing.arabic}

📖 *Transliteration:*
${opening.transliteration}
${body.transliteration}
${closing.transliteration}

💬 *Translation:*
${opening.translation}
${body.translation}
${closing.translation}
${situation.isNotEmpty ? '\n🤲 _Specifically for: $situation' : ''}

━━━━━━━━━━━━━━━━━━━━━

🕌 Generated with *Azanify* - Your Islamic Companion
📲 Prayer Times • Quran • Duas • Qibla & More

Download now: https://play.google.com/store/apps/details?id=com.azanify.prayer_times

#Azanify #Dua #Islam #Prayer #Muslim
''';

    Share.share(shareText, subject: 'My Personalized Dua - Azanify');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final surfaceColor = theme.colorScheme.surface;
    final cardColor = isDark ? const Color(0xFF252836) : Colors.white;

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
                showBackButton: true,
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thank you message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1E3A5F),
                                  const Color(0xFF0D2137),
                                ]
                              : [
                                  const Color(0xFFECFDF5),
                                  const Color(0xFFD1FAE5),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.favorite,
                                color: Colors.red.shade400,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'JazakAllah Khair for watching the ad!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your support helps us maintain this app. We make dua from our hearts for you, and all our users pray that your duas are heard and accepted. May Allah bless you! 🤲',
                            style: TextStyle(
                              color: textColor.withOpacity(0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: accentColor,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dua Generator',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Personalized prayers for your specific needs',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Main content
                    _generatedDua == null
                        ? _buildSelectionView(
                            context,
                            isDark,
                            textColor,
                            cardColor,
                            accentColor,
                            surfaceColor,
                          )
                        : _buildResultView(
                            context,
                            isDark,
                            textColor,
                            cardColor,
                            accentColor,
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionView(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color cardColor,
    Color accentColor,
    Color surfaceColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Selection
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Your Need',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              ..._categories.map(
                (cat) =>
                    _buildCategoryTile(cat, isDark, textColor, accentColor),
              ),
            ],
          ),
        ),

        // Situation Input
        if (_selectedCategory != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Describe your specific situation (optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _situationController,
                  maxLines: 3,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText:
                        "E.g., 'recovering from surgery', 'starting new job', 'family conflict'...",
                    hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                    filled: true,
                    fillColor: isDark ? surfaceColor : const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: textColor.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _generateDua,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Generate My Personalized Dua',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryTile(
    Map<String, String> cat,
    bool isDark,
    Color textColor,
    Color accentColor,
  ) {
    final isSelected = _selectedCategory == cat['id'];
    final category = _duaDatabase[cat['id']]!;
    final cardBg = isDark ? const Color(0xFF252836) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = cat['id']),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.15) : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accentColor : textColor.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: category.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat['name']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat['desc']!,
                      style: TextStyle(
                        color: textColor.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: accentColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultView(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color cardColor,
    Color accentColor,
  ) {
    final category = _duaDatabase[_generatedDua!['category']]!;
    final opening = _generatedDua!['opening'] as DuaPart;
    final body = _generatedDua!['body'] as DuaPart;
    final closing = _generatedDua!['closing'] as DuaPart;
    final situation = _generatedDua!['situation'] as String;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Category Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: category.iconColor, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                'Your Personalized Dua',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),

              // Dua Content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1E3A5F), const Color(0xFF0D2137)]
                        : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accentColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // Arabic Text
                    _buildDuaArabicSection(opening, body, closing, textColor),

                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      height: 2,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),

                    // Transliteration
                    _buildDuaTransliterationSection(
                      opening,
                      body,
                      closing,
                      textColor,
                    ),

                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      height: 2,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),

                    // Translation
                    _buildDuaTranslationSection(
                      opening,
                      body,
                      closing,
                      textColor,
                    ),

                    // Situation
                    if (situation.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Specifically for: $situation',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // TTS Player Controls
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accentColor.withOpacity(0.1),
                      accentColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.record_voice_over,
                          color: accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Listen to Dua',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        // Settings button
                        InkWell(
                          onTap: _showTtsSettings,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_repeatCount×',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.settings,
                                  color: accentColor,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Play controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Stop button
                        if (_isSpeaking)
                          IconButton(
                            onPressed: _stopSpeaking,
                            icon: const Icon(Icons.stop_circle_outlined),
                            iconSize: 40,
                            color: Colors.red.shade400,
                          ),
                        const SizedBox(width: 8),
                        // Play/Pause button
                        InkWell(
                          onTap: () {
                            if (_isSpeaking && !_isPaused) {
                              _stopSpeaking();
                            } else {
                              _startSpeaking();
                            }
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isSpeaking && !_isPaused
                                  ? Icons.stop
                                  : Icons.play_arrow,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Progress indicator
                    if (_isSpeaking) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reading $_currentRepeat of $_repeatCount...',
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Note
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: accentColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'These duas are composed from authentic Quranic verses and Hadith. Recite with sincerity and trust in Allah\'s wisdom.',
                        style: TextStyle(
                          color: textColor.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons - Row 1: Generate & Copy
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.play_circle_outline, size: 18),
                      label: const Text('New Dua (Ad)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: textColor.withOpacity(0.3)),
                        foregroundColor: textColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _copyDua,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Share Button (Full Width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareDua,
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Dua'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDuaArabicSection(
    DuaPart opening,
    DuaPart body,
    DuaPart closing,
    Color textColor,
  ) {
    return Column(
      children: [
        Text(
          opening.arabic,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textColor,
            height: 1.8,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        Text(
          body.arabic,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textColor,
            height: 1.8,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        Text(
          closing.arabic,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: textColor,
            height: 1.8,
          ),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  Widget _buildDuaTransliterationSection(
    DuaPart opening,
    DuaPart body,
    DuaPart closing,
    Color textColor,
  ) {
    final translitColor = const Color(0xFF059669);
    return Column(
      children: [
        Text(
          opening.transliteration,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: translitColor,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body.transliteration,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: translitColor,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          closing.transliteration,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontStyle: FontStyle.italic,
            color: translitColor,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildDuaTranslationSection(
    DuaPart opening,
    DuaPart body,
    DuaPart closing,
    Color textColor,
  ) {
    return Column(
      children: [
        Text(
          opening.translation,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: textColor.withOpacity(0.8),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body.translation,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: textColor.withOpacity(0.8),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          closing.translation,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: textColor.withOpacity(0.8),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class DuaCategory {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final List<DuaPart> openings;
  final List<DuaPart> bodies;
  final List<DuaPart> closings;

  DuaCategory({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.openings,
    required this.bodies,
    required this.closings,
  });
}

class DuaPart {
  final String arabic;
  final String transliteration;
  final String translation;

  DuaPart({
    required this.arabic,
    required this.transliteration,
    required this.translation,
  });
}
