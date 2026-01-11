import 'package:flutter/material.dart';
import '../models/post_template.dart';
import '../providers/post_editor_provider.dart';

/// Widget for customizing background settings
class BackgroundPickerWidget extends StatelessWidget {
  final PostEditorProvider editor;

  const BackgroundPickerWidget({
    super.key,
    required this.editor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Background',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Background type selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _BackgroundTypeButton(
                icon: Icons.gradient,
                label: 'Gradient',
                isSelected: editor.background.type == BackgroundType.gradient,
                onTap: () => editor.updateBackground(type: BackgroundType.gradient),
              ),
              const SizedBox(width: 8),
              _BackgroundTypeButton(
                icon: Icons.format_color_fill,
                label: 'Solid',
                isSelected: editor.background.type == BackgroundType.solidColor,
                onTap: () => editor.updateBackground(type: BackgroundType.solidColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Gradient presets
        if (editor.background.type == BackgroundType.gradient) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Gradient Presets',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: GradientPreset.presets.length,
              itemBuilder: (context, index) {
                final preset = GradientPreset.presets[index];
                final isSelected = editor.background.gradient?.name == preset.name;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => editor.setGradientPreset(index),
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        gradient: preset.toGradient(),
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        // Solid color presets
        if (editor.background.type == BackgroundType.solidColor) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Color Presets',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: PostEditorProvider.solidColorPresets.length,
              itemBuilder: (context, index) {
                final color = PostEditorProvider.solidColorPresets[index];
                final isSelected = editor.background.solidColor.value == color.value;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => editor.setSolidColor(color),
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : Border.all(
                                color: color == Colors.white
                                    ? Colors.grey.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Pattern selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Pattern Overlay',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            children: PatternType.values.map((pattern) {
              final isSelected = editor.background.patternType == pattern;
              return ChoiceChip(
                label: Text(pattern.displayName),
                selected: isSelected,
                onSelected: (_) => editor.setPatternType(pattern),
                selectedColor: theme.colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),

        // Pattern opacity slider
        if (editor.background.patternType != PatternType.none) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Pattern Opacity',
                  style: theme.textTheme.bodySmall,
                ),
                Expanded(
                  child: Slider(
                    value: editor.background.patternOpacity,
                    min: 0.05,
                    max: 0.5,
                    onChanged: (value) =>
                        editor.updateBackground(patternOpacity: value),
                  ),
                ),
                Text(
                  '${(editor.background.patternOpacity * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BackgroundTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BackgroundTypeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.2)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
