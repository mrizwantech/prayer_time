import 'package:flutter/material.dart';
import '../models/post_template.dart';
import '../models/post_content.dart';
import '../providers/post_editor_provider.dart';

/// Widget for editing post text content
class TextEditorPanelWidget extends StatefulWidget {
  final PostEditorProvider editor;

  const TextEditorPanelWidget({
    super.key,
    required this.editor,
  });

  @override
  State<TextEditorPanelWidget> createState() => _TextEditorPanelWidgetState();
}

class _TextEditorPanelWidgetState extends State<TextEditorPanelWidget> {
  late TextEditingController _arabicController;
  late TextEditingController _translationController;
  late TextEditingController _transliterationController;
  late TextEditingController _referenceController;

  @override
  void initState() {
    super.initState();
    _arabicController = TextEditingController(text: widget.editor.content.arabicText);
    _translationController = TextEditingController(text: widget.editor.content.translationText);
    _transliterationController = TextEditingController(text: widget.editor.content.transliterationText);
    _referenceController = TextEditingController(text: widget.editor.content.referenceText);
  }

  @override
  void didUpdateWidget(TextEditorPanelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if content changed externally (e.g., sample loaded)
    if (_arabicController.text != widget.editor.content.arabicText) {
      _arabicController.text = widget.editor.content.arabicText;
    }
    if (_translationController.text != widget.editor.content.translationText) {
      _translationController.text = widget.editor.content.translationText;
    }
    if (_transliterationController.text != widget.editor.content.transliterationText) {
      _transliterationController.text = widget.editor.content.transliterationText;
    }
    if (_referenceController.text != widget.editor.content.referenceText) {
      _referenceController.text = widget.editor.content.referenceText;
    }
  }

  @override
  void dispose() {
    _arabicController.dispose();
    _translationController.dispose();
    _transliterationController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editor = widget.editor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sample content selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Content',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showSamplePicker(context),
                icon: const Icon(Icons.library_books, size: 18),
                label: const Text('Browse Samples'),
              ),
            ],
          ),
        ),

        // Arabic text field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _arabicController,
            textDirection: TextDirection.rtl,
            maxLines: 3,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Arabic Text',
              hintText: 'أدخل النص العربي هنا',
              hintTextDirection: TextDirection.rtl,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.text_fields),
            ),
            onChanged: (value) => editor.updateContent(arabicText: value),
          ),
        ),

        // Translation field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _translationController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Translation',
              hintText: 'Enter translation...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.translate),
            ),
            onChanged: (value) => editor.updateContent(translationText: value),
          ),
        ),

        // Transliteration field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _transliterationController,
            decoration: InputDecoration(
              labelText: 'Transliteration (Optional)',
              hintText: 'Enter transliteration...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.spellcheck),
            ),
            onChanged: (value) => editor.updateContent(transliterationText: value),
          ),
        ),

        // Reference field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _referenceController,
            decoration: InputDecoration(
              labelText: 'Reference (Optional)',
              hintText: 'e.g., Surah Al-Baqarah (2:153)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.bookmark),
            ),
            onChanged: (value) => editor.updateContent(referenceText: value),
          ),
        ),

        const SizedBox(height: 16),

        // Text display options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Display Options',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Toggle options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Arabic'),
                selected: editor.textStyle.showArabic,
                onSelected: (val) => editor.updateTextStyle(showArabic: val),
              ),
              FilterChip(
                label: const Text('Translation'),
                selected: editor.textStyle.showTranslation,
                onSelected: (val) => editor.updateTextStyle(showTranslation: val),
              ),
              FilterChip(
                label: const Text('Transliteration'),
                selected: editor.textStyle.showTransliteration,
                onSelected: (val) => editor.updateTextStyle(showTransliteration: val),
              ),
              FilterChip(
                label: const Text('Reference'),
                selected: editor.textStyle.showReference,
                onSelected: (val) => editor.updateTextStyle(showReference: val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Font size controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Font Size',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Arabic font size
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Arabic:'),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: editor.decreaseArabicFontSize,
              ),
              Text(
                '${editor.textStyle.arabicFontSize.round()}',
                style: theme.textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: editor.increaseArabicFontSize,
              ),
              const Spacer(),
              const Text('Translation:'),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: editor.decreaseTranslationFontSize,
              ),
              Text(
                '${editor.textStyle.translationFontSize.round()}',
                style: theme.textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: editor.increaseTranslationFontSize,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Text alignment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Alignment:'),
              const SizedBox(width: 16),
              _AlignmentButton(
                icon: Icons.format_align_left,
                isSelected: editor.textStyle.textAlignment == TextAlign.left,
                onTap: () => editor.updateTextStyle(textAlignment: TextAlign.left),
              ),
              _AlignmentButton(
                icon: Icons.format_align_center,
                isSelected: editor.textStyle.textAlignment == TextAlign.center,
                onTap: () => editor.updateTextStyle(textAlignment: TextAlign.center),
              ),
              _AlignmentButton(
                icon: Icons.format_align_right,
                isSelected: editor.textStyle.textAlignment == TextAlign.right,
                onTap: () => editor.updateTextStyle(textAlignment: TextAlign.right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSamplePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _SampleContentPicker(
        onSelect: (sample) {
          widget.editor.loadSampleContent(sample);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _AlignmentButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlignmentButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(
          icon,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: isSelected
              ? theme.colorScheme.primary.withOpacity(0.2)
              : null,
        ),
      ),
    );
  }
}

class _SampleContentPicker extends StatefulWidget {
  final Function(PostContent) onSelect;

  const _SampleContentPicker({required this.onSelect});

  @override
  State<_SampleContentPicker> createState() => _SampleContentPickerState();
}

class _SampleContentPickerState extends State<_SampleContentPicker> {
  PostCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final samples = _selectedCategory != null
        ? PostContent.getSamplesByCategory(_selectedCategory!)
        : PostContent.samples;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Sample Content',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Category filter
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      onSelected: (_) => setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...PostCategory.values.where((c) => c != PostCategory.custom).map(
                    (category) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(category.displayName),
                        selected: _selectedCategory == category,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = category),
                        avatar: Icon(category.icon, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Sample list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: samples.length,
                itemBuilder: (context, index) {
                  final sample = samples[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => widget.onSelect(sample),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  sample.category.icon,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sample.category.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sample.arabicText,
                              style: const TextStyle(
                                fontSize: 20,
                                height: 1.6,
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              sample.translationText,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            if (sample.referenceText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '— ${sample.referenceText}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
