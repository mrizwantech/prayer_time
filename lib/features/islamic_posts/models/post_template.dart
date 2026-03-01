import 'package:flutter/material.dart';

/// Represents a post template category
enum PostCategory {
  quranVerse,
  hadith,
  dua,
  islamicReminder,
  jummah,
  ramadan,
  eid,
  custom,
}

extension PostCategoryExtension on PostCategory {
  String get displayName {
    switch (this) {
      case PostCategory.quranVerse:
        return 'Quran Verse';
      case PostCategory.hadith:
        return 'Hadith';
      case PostCategory.dua:
        return 'Dua';
      case PostCategory.islamicReminder:
        return 'Islamic Reminder';
      case PostCategory.jummah:
        return 'Jummah';
      case PostCategory.ramadan:
        return 'Ramadan';
      case PostCategory.eid:
        return 'Eid';
      case PostCategory.custom:
        return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case PostCategory.quranVerse:
        return Icons.menu_book;
      case PostCategory.hadith:
        return Icons.format_quote;
      case PostCategory.dua:
        return Icons.front_hand;
      case PostCategory.islamicReminder:
        return Icons.lightbulb_outline;
      case PostCategory.jummah:
        return Icons.mosque;
      case PostCategory.ramadan:
        return Icons.nights_stay;
      case PostCategory.eid:
        return Icons.celebration;
      case PostCategory.custom:
        return Icons.edit;
    }
  }
}

/// Represents the aspect ratio for the post
enum PostAspectRatio {
  square,        // 1:1 - Instagram post
  portrait,      // 9:16 - Instagram story / WhatsApp status
  landscape,     // 16:9 - YouTube thumbnail
  wide,          // 4:5 - Instagram portrait
}

extension PostAspectRatioExtension on PostAspectRatio {
  String get displayName {
    switch (this) {
      case PostAspectRatio.square:
        return 'Square (1:1)';
      case PostAspectRatio.portrait:
        return 'Story (9:16)';
      case PostAspectRatio.landscape:
        return 'Landscape (16:9)';
      case PostAspectRatio.wide:
        return 'Portrait (4:5)';
    }
  }

  double get ratio {
    switch (this) {
      case PostAspectRatio.square:
        return 1.0;
      case PostAspectRatio.portrait:
        return 9 / 16;
      case PostAspectRatio.landscape:
        return 16 / 9;
      case PostAspectRatio.wide:
        return 4 / 5;
    }
  }

  IconData get icon {
    switch (this) {
      case PostAspectRatio.square:
        return Icons.crop_square;
      case PostAspectRatio.portrait:
        return Icons.crop_portrait;
      case PostAspectRatio.landscape:
        return Icons.crop_landscape;
      case PostAspectRatio.wide:
        return Icons.crop_din;
    }
  }
}

/// Background type for the post
enum BackgroundType {
  solidColor,
  gradient,
  pattern,
  image,
}

/// Gradient preset for backgrounds
class GradientPreset {
  final String name;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const GradientPreset({
    required this.name,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  LinearGradient toGradient() {
    return LinearGradient(
      colors: colors,
      begin: begin,
      end: end,
    );
  }

  static const List<GradientPreset> presets = [
    GradientPreset(
      name: 'Emerald',
      colors: [Color(0xFF134E5E), Color(0xFF71B280)],
    ),
    GradientPreset(
      name: 'Golden',
      colors: [Color(0xFFF7971E), Color(0xFFFFD200)],
    ),
    GradientPreset(
      name: 'Midnight',
      colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    ),
    GradientPreset(
      name: 'Royal Purple',
      colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
    ),
    GradientPreset(
      name: 'Ocean Blue',
      colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
    ),
    GradientPreset(
      name: 'Sunset',
      colors: [Color(0xFFee9ca7), Color(0xFFffdde1)],
    ),
    GradientPreset(
      name: 'Deep Teal',
      colors: [Color(0xFF00D9A5), Color(0xFF1a1d2e)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    GradientPreset(
      name: 'Night Sky',
      colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243e)],
    ),
    GradientPreset(
      name: 'Rose Gold',
      colors: [Color(0xFFB76E79), Color(0xFFE8B4B8)],
    ),
    GradientPreset(
      name: 'Islamic Green',
      colors: [Color(0xFF009432), Color(0xFF006400)],
    ),
  ];
}

/// Pattern preset for backgrounds
enum PatternType {
  geometric,
  arabesque,
  stars,
  mosaic,
  none,
}

extension PatternTypeExtension on PatternType {
  String get displayName {
    switch (this) {
      case PatternType.geometric:
        return 'Geometric';
      case PatternType.arabesque:
        return 'Arabesque';
      case PatternType.stars:
        return 'Stars';
      case PatternType.mosaic:
        return 'Mosaic';
      case PatternType.none:
        return 'None';
    }
  }
}

/// Post template with pre-configured styles
class PostTemplate {
  final String id;
  final String name;
  final PostCategory category;
  final BackgroundType backgroundType;
  final Color? backgroundColor;
  final GradientPreset? gradient;
  final PatternType patternType;
  final Color patternColor;
  final double patternOpacity;
  final TextStyle arabicStyle;
  final TextStyle translationStyle;
  final TextStyle referenceStyle;
  final EdgeInsets contentPadding;
  final bool showDecorations;

  const PostTemplate({
    required this.id,
    required this.name,
    required this.category,
    this.backgroundType = BackgroundType.gradient,
    this.backgroundColor,
    this.gradient,
    this.patternType = PatternType.none,
    this.patternColor = Colors.white,
    this.patternOpacity = 0.1,
    this.arabicStyle = const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      height: 1.8,
    ),
    this.translationStyle = const TextStyle(
      fontSize: 16,
      color: Colors.white70,
      height: 1.5,
      fontStyle: FontStyle.italic,
    ),
    this.referenceStyle = const TextStyle(
      fontSize: 14,
      color: Colors.white60,
    ),
    this.contentPadding = const EdgeInsets.all(32),
    this.showDecorations = true,
  });

  static List<PostTemplate> get templates => [
    PostTemplate(
      id: 'quran_emerald',
      name: 'Quran - Emerald',
      category: PostCategory.quranVerse,
      gradient: GradientPreset.presets[0],
      patternType: PatternType.geometric,
    ),
    PostTemplate(
      id: 'quran_midnight',
      name: 'Quran - Midnight',
      category: PostCategory.quranVerse,
      gradient: GradientPreset.presets[2],
      patternType: PatternType.stars,
    ),
    PostTemplate(
      id: 'hadith_golden',
      name: 'Hadith - Golden',
      category: PostCategory.hadith,
      gradient: GradientPreset.presets[1],
      patternType: PatternType.arabesque,
    ),
    PostTemplate(
      id: 'dua_purple',
      name: 'Dua - Royal',
      category: PostCategory.dua,
      gradient: GradientPreset.presets[3],
      patternType: PatternType.geometric,
    ),
    PostTemplate(
      id: 'jummah_teal',
      name: 'Jummah Mubarak',
      category: PostCategory.jummah,
      gradient: GradientPreset.presets[6],
      patternType: PatternType.mosaic,
    ),
    PostTemplate(
      id: 'ramadan_night',
      name: 'Ramadan - Night',
      category: PostCategory.ramadan,
      gradient: GradientPreset.presets[7],
      patternType: PatternType.stars,
    ),
    PostTemplate(
      id: 'eid_rosegold',
      name: 'Eid Mubarak',
      category: PostCategory.eid,
      gradient: GradientPreset.presets[8],
      patternType: PatternType.arabesque,
    ),
    PostTemplate(
      id: 'reminder_green',
      name: 'Islamic Green',
      category: PostCategory.islamicReminder,
      gradient: GradientPreset.presets[9],
      patternType: PatternType.geometric,
    ),
    PostTemplate(
      id: 'custom_ocean',
      name: 'Ocean Blue',
      category: PostCategory.custom,
      gradient: GradientPreset.presets[4],
      patternType: PatternType.none,
    ),
    PostTemplate(
      id: 'custom_sunset',
      name: 'Soft Sunset',
      category: PostCategory.custom,
      gradient: GradientPreset.presets[5],
      patternType: PatternType.none,
      arabicStyle: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4A4A4A),
        height: 1.8,
      ),
      translationStyle: TextStyle(
        fontSize: 16,
        color: Color(0xFF6B6B6B),
        height: 1.5,
        fontStyle: FontStyle.italic,
      ),
      referenceStyle: TextStyle(
        fontSize: 14,
        color: Color(0xFF8B8B8B),
      ),
    ),
  ];
}
