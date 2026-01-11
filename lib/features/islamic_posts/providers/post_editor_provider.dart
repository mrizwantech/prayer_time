import 'package:flutter/material.dart';
import '../models/post_template.dart';
import '../models/post_content.dart';

/// Provider for managing the post editor state
class PostEditorProvider extends ChangeNotifier {
  // Content
  PostContent _content = const PostContent();
  PostContent get content => _content;

  // Text styling
  PostTextStyle _textStyle = const PostTextStyle();
  PostTextStyle get textStyle => _textStyle;

  // Background
  PostBackground _background = PostBackground(
    gradient: GradientPreset.presets[0],
  );
  PostBackground get background => _background;

  // Aspect ratio
  PostAspectRatio _aspectRatio = PostAspectRatio.square;
  PostAspectRatio get aspectRatio => _aspectRatio;

  // Selected template
  PostTemplate? _selectedTemplate;
  PostTemplate? get selectedTemplate => _selectedTemplate;

  // Decorations
  bool _showDecorations = true;
  bool get showDecorations => _showDecorations;

  // Watermark
  bool _showWatermark = true;
  bool get showWatermark => _showWatermark;

  // App name for watermark
  String _watermarkText = 'Azanify';
  String get watermarkText => _watermarkText;

  // Reset to initial state
  void reset() {
    _content = const PostContent();
    _textStyle = const PostTextStyle();
    _background = PostBackground(gradient: GradientPreset.presets[0]);
    _aspectRatio = PostAspectRatio.square;
    _selectedTemplate = null;
    _showDecorations = true;
    _showWatermark = true;
    notifyListeners();
  }

  // Apply a template
  void applyTemplate(PostTemplate template) {
    _selectedTemplate = template;
    
    // Apply template's background
    _background = PostBackground(
      type: template.backgroundType,
      solidColor: template.backgroundColor ?? const Color(0xFF1a1d2e),
      gradient: template.gradient,
      patternType: template.patternType,
      patternColor: template.patternColor,
      patternOpacity: template.patternOpacity,
    );

    // Apply template's text style from the template
    final isDarkBg = _isBackgroundDark();
    _textStyle = PostTextStyle(
      textColor: isDarkBg ? Colors.white : const Color(0xFF1a1d2e),
      secondaryTextColor: isDarkBg ? Colors.white70 : const Color(0xFF4a4a4a),
    );

    _showDecorations = template.showDecorations;
    
    notifyListeners();
  }

  // Load sample content
  void loadSampleContent(PostContent sample) {
    _content = sample;
    notifyListeners();
  }

  // Update content
  void updateContent({
    String? arabicText,
    String? translationText,
    String? transliterationText,
    String? referenceText,
    PostCategory? category,
  }) {
    _content = _content.copyWith(
      arabicText: arabicText,
      translationText: translationText,
      transliterationText: transliterationText,
      referenceText: referenceText,
      category: category,
    );
    notifyListeners();
  }

  // Update text style
  void updateTextStyle({
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
    _textStyle = _textStyle.copyWith(
      arabicFontSize: arabicFontSize,
      translationFontSize: translationFontSize,
      transliterationFontSize: transliterationFontSize,
      referenceFontSize: referenceFontSize,
      textColor: textColor,
      secondaryTextColor: secondaryTextColor,
      textAlignment: textAlignment,
      showArabic: showArabic,
      showTranslation: showTranslation,
      showTransliteration: showTransliteration,
      showReference: showReference,
      arabicBold: arabicBold,
      translationItalic: translationItalic,
    );
    notifyListeners();
  }

  // Update background
  void updateBackground({
    BackgroundType? type,
    Color? solidColor,
    GradientPreset? gradient,
    PatternType? patternType,
    Color? patternColor,
    double? patternOpacity,
    String? imagePath,
  }) {
    _background = _background.copyWith(
      type: type,
      solidColor: solidColor,
      gradient: gradient,
      patternType: patternType,
      patternColor: patternColor,
      patternOpacity: patternOpacity,
      imagePath: imagePath,
    );
    
    // Auto-adjust text color based on background brightness
    if (type != null || solidColor != null || gradient != null) {
      _autoAdjustTextColor();
    }
    
    notifyListeners();
  }

  // Update aspect ratio
  void setAspectRatio(PostAspectRatio ratio) {
    _aspectRatio = ratio;
    notifyListeners();
  }

  // Toggle decorations
  void setShowDecorations(bool show) {
    _showDecorations = show;
    notifyListeners();
  }

  // Toggle watermark
  void setShowWatermark(bool show) {
    _showWatermark = show;
    notifyListeners();
  }

  // Set watermark text
  void setWatermarkText(String text) {
    _watermarkText = text;
    notifyListeners();
  }

  // Check if background is dark
  bool _isBackgroundDark() {
    if (_background.type == BackgroundType.gradient && _background.gradient != null) {
      // Check the average luminance of gradient colors
      final colors = _background.gradient!.colors;
      double totalLuminance = 0;
      for (final color in colors) {
        totalLuminance += color.computeLuminance();
      }
      return (totalLuminance / colors.length) < 0.5;
    } else if (_background.type == BackgroundType.solidColor) {
      return _background.solidColor.computeLuminance() < 0.5;
    }
    return true; // Default to dark
  }

  // Auto-adjust text color based on background
  void _autoAdjustTextColor() {
    final isDark = _isBackgroundDark();
    _textStyle = _textStyle.copyWith(
      textColor: isDark ? Colors.white : const Color(0xFF1a1d2e),
      secondaryTextColor: isDark ? Colors.white70 : const Color(0xFF4a4a4a),
    );
  }

  // Quick preset methods
  void setGradientPreset(int index) {
    if (index >= 0 && index < GradientPreset.presets.length) {
      updateBackground(
        type: BackgroundType.gradient,
        gradient: GradientPreset.presets[index],
      );
    }
  }

  void setSolidColor(Color color) {
    updateBackground(
      type: BackgroundType.solidColor,
      solidColor: color,
    );
  }

  void setPatternType(PatternType type) {
    updateBackground(patternType: type);
  }

  // Increase/decrease font sizes
  void increaseArabicFontSize() {
    if (_textStyle.arabicFontSize < 60) {
      updateTextStyle(arabicFontSize: _textStyle.arabicFontSize + 2);
    }
  }

  void decreaseArabicFontSize() {
    if (_textStyle.arabicFontSize > 14) {
      updateTextStyle(arabicFontSize: _textStyle.arabicFontSize - 2);
    }
  }

  void increaseTranslationFontSize() {
    if (_textStyle.translationFontSize < 36) {
      updateTextStyle(translationFontSize: _textStyle.translationFontSize + 1);
    }
  }

  void decreaseTranslationFontSize() {
    if (_textStyle.translationFontSize > 10) {
      updateTextStyle(translationFontSize: _textStyle.translationFontSize - 1);
    }
  }

  // Color presets for solid backgrounds
  static const List<Color> solidColorPresets = [
    Color(0xFF1a1d2e),  // Dark blue
    Color(0xFF0F2027),  // Midnight
    Color(0xFF134E5E),  // Teal
    Color(0xFF009432),  // Islamic green
    Color(0xFF4A00E0),  // Purple
    Color(0xFFB76E79),  // Rose
    Color(0xFFF7971E),  // Orange
    Color(0xFF2193b0),  // Blue
    Color(0xFFFFFFFF),  // White
    Color(0xFFF5F5F5),  // Light gray
    Color(0xFFffdde1),  // Light pink
    Color(0xFF6dd5ed),  // Light blue
  ];
}
