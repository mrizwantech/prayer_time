import 'package:flutter/material.dart';
import 'post_template.dart';

/// Content for the Islamic post
class PostContent {
  final String arabicText;
  final String translationText;
  final String transliterationText;
  final String referenceText;
  final PostCategory category;

  const PostContent({
    this.arabicText = '',
    this.translationText = '',
    this.transliterationText = '',
    this.referenceText = '',
    this.category = PostCategory.custom,
  });

  PostContent copyWith({
    String? arabicText,
    String? translationText,
    String? transliterationText,
    String? referenceText,
    PostCategory? category,
  }) {
    return PostContent(
      arabicText: arabicText ?? this.arabicText,
      translationText: translationText ?? this.translationText,
      transliterationText: transliterationText ?? this.transliterationText,
      referenceText: referenceText ?? this.referenceText,
      category: category ?? this.category,
    );
  }

  bool get isEmpty => 
      arabicText.isEmpty && 
      translationText.isEmpty && 
      transliterationText.isEmpty;

  /// Pre-defined content samples
  static const List<PostContent> samples = [
    // Quran Verses
    PostContent(
      arabicText: 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
      translationText: 'Indeed, Allah is with the patient.',
      transliterationText: 'Inna Allaha ma\'a as-sabireen',
      referenceText: 'Surah Al-Baqarah (2:153)',
      category: PostCategory.quranVerse,
    ),
    PostContent(
      arabicText: 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
      translationText: 'For indeed, with hardship comes ease.',
      transliterationText: 'Fa inna ma\'al usri yusra',
      referenceText: 'Surah Ash-Sharh (94:5)',
      category: PostCategory.quranVerse,
    ),
    PostContent(
      arabicText: 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
      translationText: 'And say: "My Lord, increase me in knowledge."',
      transliterationText: 'Wa qul Rabbi zidni ilma',
      referenceText: 'Surah Ta-Ha (20:114)',
      category: PostCategory.quranVerse,
    ),
    PostContent(
      arabicText: 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
      translationText: 'And whoever relies upon Allah - then He is sufficient for him.',
      transliterationText: 'Wa man yatawakkal \'ala Allahi fahuwa hasbuhu',
      referenceText: 'Surah At-Talaq (65:3)',
      category: PostCategory.quranVerse,
    ),
    PostContent(
      arabicText: 'إِنَّ رَحْمَتَ اللَّهِ قَرِيبٌ مِّنَ الْمُحْسِنِينَ',
      translationText: 'Indeed, the mercy of Allah is near to the doers of good.',
      transliterationText: 'Inna rahmata Allahi qareebun minal muhsineen',
      referenceText: 'Surah Al-A\'raf (7:56)',
      category: PostCategory.quranVerse,
    ),
    
    // Hadith
    PostContent(
      arabicText: 'تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ صَدَقَةٌ',
      translationText: 'Your smile for your brother is charity.',
      transliterationText: 'Tabasumuka fi wajhi akhika sadaqa',
      referenceText: 'Jami\' at-Tirmidhi',
      category: PostCategory.hadith,
    ),
    PostContent(
      arabicText: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
      translationText: 'The best among you are those who learn the Quran and teach it.',
      transliterationText: 'Khairukum man ta\'allama al-Qurana wa \'allamahu',
      referenceText: 'Sahih al-Bukhari',
      category: PostCategory.hadith,
    ),
    PostContent(
      arabicText: 'الدُّعَاءُ هُوَ الْعِبَادَةُ',
      translationText: 'Supplication (dua) is worship itself.',
      transliterationText: 'Ad-du\'a huwa al-\'ibadah',
      referenceText: 'Jami\' at-Tirmidhi',
      category: PostCategory.hadith,
    ),
    
    // Duas
    PostContent(
      arabicText: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      translationText: 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the punishment of the Fire.',
      transliterationText: 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan waqina \'adhaban-nar',
      referenceText: 'Surah Al-Baqarah (2:201)',
      category: PostCategory.dua,
    ),
    PostContent(
      arabicText: 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي',
      translationText: 'My Lord, expand for me my chest and ease for me my task.',
      transliterationText: 'Rabbi ishrah li sadri wa yassir li amri',
      referenceText: 'Surah Ta-Ha (20:25-26)',
      category: PostCategory.dua,
    ),
    
    // Jummah
    PostContent(
      arabicText: 'جُمُعَة مُبَارَكَة',
      translationText: 'Blessed Friday',
      transliterationText: 'Jumu\'ah Mubarak',
      referenceText: '',
      category: PostCategory.jummah,
    ),
    PostContent(
      arabicText: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ',
      translationText: 'O Allah, send blessings upon Muhammad and upon the family of Muhammad.',
      transliterationText: 'Allahumma salli \'ala Muhammadin wa \'ala ali Muhammad',
      referenceText: 'Durood Shareef',
      category: PostCategory.jummah,
    ),
    
    // Ramadan
    PostContent(
      arabicText: 'رَمَضَان كَرِيم',
      translationText: 'Ramadan Kareem - May this holy month be generous to you.',
      transliterationText: 'Ramadan Kareem',
      referenceText: '',
      category: PostCategory.ramadan,
    ),
    PostContent(
      arabicText: 'اللَّهُمَّ بَلِّغْنَا رَمَضَان',
      translationText: 'O Allah, let us reach Ramadan.',
      transliterationText: 'Allahumma ballighna Ramadan',
      referenceText: '',
      category: PostCategory.ramadan,
    ),
    
    // Eid
    PostContent(
      arabicText: 'عِيد مُبَارَك',
      translationText: 'Eid Mubarak - May Allah accept your good deeds.',
      transliterationText: 'Eid Mubarak',
      referenceText: '',
      category: PostCategory.eid,
    ),
    PostContent(
      arabicText: 'تَقَبَّلَ اللهُ مِنَّا وَمِنكُم',
      translationText: 'May Allah accept from us and from you.',
      transliterationText: 'Taqabbal Allahu minna wa minkum',
      referenceText: '',
      category: PostCategory.eid,
    ),
    
    // Islamic Reminders
    PostContent(
      arabicText: 'اسْتَغْفِرُ اللهَ',
      translationText: 'I seek forgiveness from Allah.',
      transliterationText: 'Astaghfirullah',
      referenceText: '',
      category: PostCategory.islamicReminder,
    ),
    PostContent(
      arabicText: 'الْحَمْدُ لِلَّهِ عَلَى كُلِّ حَالٍ',
      translationText: 'All praise is due to Allah in every circumstance.',
      transliterationText: 'Alhamdulillah \'ala kulli hal',
      referenceText: '',
      category: PostCategory.islamicReminder,
    ),
    PostContent(
      arabicText: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
      translationText: 'There is no might nor power except with Allah.',
      transliterationText: 'La hawla wa la quwwata illa billah',
      referenceText: '',
      category: PostCategory.islamicReminder,
    ),
  ];

  /// Get samples by category
  static List<PostContent> getSamplesByCategory(PostCategory category) {
    return samples.where((s) => s.category == category).toList();
  }
}

/// Text style configuration for the post
class PostTextStyle {
  final double arabicFontSize;
  final double translationFontSize;
  final double transliterationFontSize;
  final double referenceFontSize;
  final Color textColor;
  final Color secondaryTextColor;
  final TextAlign textAlignment;
  final bool showArabic;
  final bool showTranslation;
  final bool showTransliteration;
  final bool showReference;
  final bool arabicBold;
  final bool translationItalic;

  const PostTextStyle({
    this.arabicFontSize = 28,
    this.translationFontSize = 16,
    this.transliterationFontSize = 14,
    this.referenceFontSize = 12,
    this.textColor = Colors.white,
    this.secondaryTextColor = Colors.white70,
    this.textAlignment = TextAlign.center,
    this.showArabic = true,
    this.showTranslation = true,
    this.showTransliteration = false,
    this.showReference = true,
    this.arabicBold = true,
    this.translationItalic = true,
  });

  PostTextStyle copyWith({
    double? arabicFontSize,
    double? translationFontSize,
    double? transliterationFontSize,
    double? referenceFontSize,
    Color? textColor,
    Color? secondaryTextColor,
    TextAlign? textAlignment,
    bool? showArabic,
    bool? showTranslation,
    bool? showTransliteration,
    bool? showReference,
    bool? arabicBold,
    bool? translationItalic,
  }) {
    return PostTextStyle(
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      transliterationFontSize: transliterationFontSize ?? this.transliterationFontSize,
      referenceFontSize: referenceFontSize ?? this.referenceFontSize,
      textColor: textColor ?? this.textColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      textAlignment: textAlignment ?? this.textAlignment,
      showArabic: showArabic ?? this.showArabic,
      showTranslation: showTranslation ?? this.showTranslation,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      showReference: showReference ?? this.showReference,
      arabicBold: arabicBold ?? this.arabicBold,
      translationItalic: translationItalic ?? this.translationItalic,
    );
  }
}

/// Background configuration for the post
class PostBackground {
  final BackgroundType type;
  final Color solidColor;
  final GradientPreset? gradient;
  final PatternType patternType;
  final Color patternColor;
  final double patternOpacity;
  final String? imagePath;

  const PostBackground({
    this.type = BackgroundType.gradient,
    this.solidColor = const Color(0xFF1a1d2e),
    this.gradient,
    this.patternType = PatternType.none,
    this.patternColor = Colors.white,
    this.patternOpacity = 0.1,
    this.imagePath,
  });

  PostBackground copyWith({
    BackgroundType? type,
    Color? solidColor,
    GradientPreset? gradient,
    PatternType? patternType,
    Color? patternColor,
    double? patternOpacity,
    String? imagePath,
  }) {
    return PostBackground(
      type: type ?? this.type,
      solidColor: solidColor ?? this.solidColor,
      gradient: gradient ?? this.gradient,
      patternType: patternType ?? this.patternType,
      patternColor: patternColor ?? this.patternColor,
      patternOpacity: patternOpacity ?? this.patternOpacity,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
