import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/post_template.dart';
import '../providers/post_editor_provider.dart';

/// Widget that renders the post preview with all styling applied
class PostPreviewWidget extends StatelessWidget {
  final PostEditorProvider editor;
  final GlobalKey? repaintKey;

  const PostPreviewWidget({
    super.key,
    required this.editor,
    this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: AspectRatio(
        aspectRatio: editor.aspectRatio.ratio,
        child: Container(
          decoration: _buildBackgroundDecoration(),
          child: Stack(
            children: [
              // Pattern overlay
              if (editor.background.patternType != PatternType.none)
                Positioned.fill(
                  child: CustomPaint(
                    painter: IslamicPatternPainter(
                      patternType: editor.background.patternType,
                      color: editor.background.patternColor
                          .withOpacity(editor.background.patternOpacity),
                    ),
                  ),
                ),

              // Decorative elements
              if (editor.showDecorations) ...[
                // Top decoration
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildDecorativeLine(editor.textStyle.textColor),
                  ),
                ),
                // Bottom decoration
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildDecorativeLine(editor.textStyle.textColor),
                  ),
                ),
              ],

              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Arabic text
                    if (editor.textStyle.showArabic && 
                        editor.content.arabicText.isNotEmpty)
                      Flexible(
                        child: Text(
                          editor.content.arabicText,
                          style: TextStyle(
                            fontSize: editor.textStyle.arabicFontSize,
                            fontWeight: editor.textStyle.arabicBold
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: editor.textStyle.textColor,
                            height: 1.8,
                          ),
                          textAlign: editor.textStyle.textAlignment,
                          textDirection: TextDirection.rtl,
                        ),
                      ),

                    if (editor.textStyle.showArabic && 
                        editor.content.arabicText.isNotEmpty)
                      const SizedBox(height: 20),

                    // Transliteration
                    if (editor.textStyle.showTransliteration &&
                        editor.content.transliterationText.isNotEmpty) ...[
                      Text(
                        editor.content.transliterationText,
                        style: TextStyle(
                          fontSize: editor.textStyle.transliterationFontSize,
                          color: editor.textStyle.secondaryTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: editor.textStyle.textAlignment,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Translation
                    if (editor.textStyle.showTranslation &&
                        editor.content.translationText.isNotEmpty)
                      Text(
                        editor.content.translationText,
                        style: TextStyle(
                          fontSize: editor.textStyle.translationFontSize,
                          fontStyle: editor.textStyle.translationItalic
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: editor.textStyle.secondaryTextColor,
                          height: 1.5,
                        ),
                        textAlign: editor.textStyle.textAlignment,
                      ),

                    // Reference
                    if (editor.textStyle.showReference &&
                        editor.content.referenceText.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        '— ${editor.content.referenceText}',
                        style: TextStyle(
                          fontSize: editor.textStyle.referenceFontSize,
                          color: editor.textStyle.secondaryTextColor
                              .withOpacity(0.8),
                        ),
                        textAlign: editor.textStyle.textAlignment,
                      ),
                    ],
                  ],
                ),
              ),

              // Watermark
              if (editor.showWatermark)
                Positioned(
                  bottom: 8,
                  right: 12,
                  child: Text(
                    editor.watermarkText,
                    style: TextStyle(
                      fontSize: 10,
                      color: editor.textStyle.textColor.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    switch (editor.background.type) {
      case BackgroundType.gradient:
        return BoxDecoration(
          gradient: editor.background.gradient?.toGradient() ??
              GradientPreset.presets[0].toGradient(),
          borderRadius: BorderRadius.circular(12),
        );
      case BackgroundType.solidColor:
        return BoxDecoration(
          color: editor.background.solidColor,
          borderRadius: BorderRadius.circular(12),
        );
      case BackgroundType.pattern:
        return BoxDecoration(
          color: editor.background.solidColor,
          borderRadius: BorderRadius.circular(12),
        );
      case BackgroundType.image:
        if (editor.background.imagePath != null) {
          return BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: AssetImage(editor.background.imagePath!),
              fit: BoxFit.cover,
            ),
          );
        }
        return BoxDecoration(
          color: editor.background.solidColor,
          borderRadius: BorderRadius.circular(12),
        );
    }
  }

  Widget _buildDecorativeLine(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 1,
          color: color.withOpacity(0.3),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.auto_awesome,
          size: 12,
          color: color.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Container(
          width: 30,
          height: 1,
          color: color.withOpacity(0.3),
        ),
      ],
    );
  }
}

/// Custom painter for Islamic geometric patterns
class IslamicPatternPainter extends CustomPainter {
  final PatternType patternType;
  final Color color;

  IslamicPatternPainter({
    required this.patternType,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    switch (patternType) {
      case PatternType.geometric:
        _drawGeometricPattern(canvas, size, paint);
        break;
      case PatternType.arabesque:
        _drawArabesquePattern(canvas, size, paint);
        break;
      case PatternType.stars:
        _drawStarsPattern(canvas, size, paint);
        break;
      case PatternType.mosaic:
        _drawMosaicPattern(canvas, size, paint);
        break;
      case PatternType.none:
        break;
    }
  }

  void _drawGeometricPattern(Canvas canvas, Size size, Paint paint) {
    const spacing = 40.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        // Draw octagon
        final path = Path();
        final radius = spacing * 0.35;
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) - math.pi / 8;
          final px = x + radius * math.cos(angle);
          final py = y + radius * math.sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawArabesquePattern(Canvas canvas, Size size, Paint paint) {
    const spacing = 60.0;
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        // Draw curved flourish
        final path = Path();
        path.moveTo(x, y);
        path.quadraticBezierTo(
          x + spacing * 0.5,
          y - spacing * 0.3,
          x + spacing,
          y,
        );
        path.quadraticBezierTo(
          x + spacing * 0.5,
          y + spacing * 0.3,
          x,
          y,
        );
        canvas.drawPath(path, paint);
      }
    }
  }

  void _drawStarsPattern(Canvas canvas, Size size, Paint paint) {
    const spacing = 50.0;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        // Offset every other row
        final offsetX = (y ~/ spacing) % 2 == 0 ? 0.0 : spacing / 2;
        _drawStar(canvas, Offset(x + offsetX, y), 8, fillPaint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    const points = 8;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.4;
      final angle = (i * math.pi / points) - math.pi / 2;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawMosaicPattern(Canvas canvas, Size size, Paint paint) {
    const spacing = 30.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        // Draw diamond
        final path = Path()
          ..moveTo(x, y - spacing * 0.4)
          ..lineTo(x + spacing * 0.4, y)
          ..lineTo(x, y + spacing * 0.4)
          ..lineTo(x - spacing * 0.4, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant IslamicPatternPainter oldDelegate) {
    return oldDelegate.patternType != patternType || oldDelegate.color != color;
  }
}
