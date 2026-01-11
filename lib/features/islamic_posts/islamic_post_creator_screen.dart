import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../presentation/widgets/app_header.dart';
import '../../core/prayer_time_service.dart';
import 'models/post_template.dart';
import 'models/post_content.dart';
import 'models/dua_library.dart';
import 'providers/post_editor_provider.dart';
import 'widgets/post_preview_widget.dart';

class IslamicPostCreatorScreen extends StatefulWidget {
  const IslamicPostCreatorScreen({super.key});

  @override
  State<IslamicPostCreatorScreen> createState() => _IslamicPostCreatorScreenState();
}

class _IslamicPostCreatorScreenState extends State<IslamicPostCreatorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final PostEditorProvider _editor = PostEditorProvider();
  bool _isSaving = false;
  bool _showMoreOptions = false;

  @override
  void initState() {
    super.initState();
    _editor.applyTemplate(PostTemplate.templates.first);
    _editor.addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _editor.removeListener(_onEditorChanged);
    _editor.dispose();
    super.dispose();
  }

  Future<void> _sharePost() async {
    if (_isSaving) return;
    if (_editor.content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select content first')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      
      if (boundary == null) throw Exception('Could not capture image');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/islamic_post_$timestamp.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Created with Azanify',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showContentPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _QuickContentPicker(
        onSelectDua: (dua, lang) {
          _editor.updateContent(
            arabicText: dua.arabic,
            translationText: dua.getTranslation(lang),
            transliterationText: dua.transliteration,
            referenceText: dua.source ?? '',
          );
          Navigator.pop(context);
        },
        onSelectSample: (sample) {
          _editor.loadSampleContent(sample);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showStylePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _QuickStylePicker(
        editor: _editor,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prayerService = Provider.of<PrayerTimeService>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            AppHeader(
              city: prayerService.city,
              state: prayerService.state,
              isLoading: prayerService.isLoading,
              onRefresh: () => prayerService.refresh(),
              showLocation: false,
              title: 'Create Post',
            ),

            // Main content area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Preview - takes most space
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: Center(
                        child: PostPreviewWidget(
                          editor: _editor,
                          repaintKey: _repaintKey,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Simple 2-button action row
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.menu_book,
                            label: 'Pick Content',
                            sublabel: _editor.content.isEmpty 
                                ? 'Duas & Quotes' 
                                : 'Content selected ✓',
                            onTap: _showContentPicker,
                            isPrimary: _editor.content.isEmpty,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.palette,
                            label: 'Change Style',
                            sublabel: 'Colors & Layout',
                            onTap: _showStylePicker,
                            isPrimary: false,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quick style presets (horizontal scroll)
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: PostTemplate.templates.length,
                        itemBuilder: (context, index) {
                          final template = PostTemplate.templates[index];
                          final isSelected = _editor.selectedTemplate?.id == template.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _editor.applyTemplate(template),
                              child: Container(
                                width: 70,
                                decoration: BoxDecoration(
                                  gradient: template.gradient?.toGradient() ?? 
                                      GradientPreset.presets[0].toGradient(),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(color: theme.colorScheme.primary, width: 3)
                                      : null,
                                  boxShadow: isSelected
                                      ? [BoxShadow(
                                          color: theme.colorScheme.primary.withAlpha(80),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )]
                                      : null,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.check,
                                    color: isSelected ? Colors.white : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // More options toggle
                    if (_showMoreOptions) ...[
                      const SizedBox(height: 16),
                      _MoreOptionsSection(editor: _editor),
                    ],

                    TextButton.icon(
                      onPressed: () => setState(() => _showMoreOptions = !_showMoreOptions),
                      icon: Icon(_showMoreOptions ? Icons.expand_less : Icons.expand_more),
                      label: Text(_showMoreOptions ? 'Less Options' : 'More Options'),
                    ),
                  ],
                ),
              ),
            ),

            // Share button - always visible at bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _editor.content.isEmpty || _isSaving ? null : _sharePost,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share),
                    label: Text(
                      _isSaving ? 'Creating...' : 'Share Post',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: theme.colorScheme.primary.withAlpha(100),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple action button widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: isPrimary 
          ? theme.colorScheme.primary.withAlpha(30)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick content picker - combines Duas and Samples
class _QuickContentPicker extends StatefulWidget {
  final Function(DuaItem, TranslationLanguage) onSelectDua;
  final Function(PostContent) onSelectSample;

  const _QuickContentPicker({
    required this.onSelectDua,
    required this.onSelectSample,
  });

  @override
  State<_QuickContentPicker> createState() => _QuickContentPickerState();
}

class _QuickContentPickerState extends State<_QuickContentPicker> {
  int _selectedTab = 0; // 0 = Popular, 1 = Duas, 2 = Custom
  TranslationLanguage _selectedLang = TranslationLanguage.english;
  final _customController = TextEditingController();

  // Popular/featured duas for quick access
  List<DuaItem> get _popularDuas => [
    DuaLibrary.duas.firstWhere((d) => d.id == 'bismillah'),
    DuaLibrary.duas.firstWhere((d) => d.id == 'alhamdulillah'),
    DuaLibrary.duas.firstWhere((d) => d.id == 'subhanallah'),
    DuaLibrary.duas.firstWhere((d) => d.id == 'allahu_akbar'),
    ...DuaLibrary.getDuasByCategory(DuaCategory.daily).take(4),
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                color: theme.colorScheme.onSurface.withAlpha(75),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.menu_book),
                  const SizedBox(width: 8),
                  const Text(
                    'Pick Content',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Simple tabs
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _TabChip(
                    label: '⭐ Popular',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: '📖 All Duas',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: '✏️ Custom',
                    isSelected: _selectedTab == 2,
                    onTap: () => setState(() => _selectedTab = 2),
                  ),
                ],
              ),
            ),

            // Language selector (for duas)
            if (_selectedTab != 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Translation: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: TranslationLanguage.values.map((lang) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ChoiceChip(
                                label: Text(lang.displayName, style: const TextStyle(fontSize: 11)),
                                selected: _selectedLang == lang,
                                onSelected: (_) => setState(() => _selectedLang = lang),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Content based on tab
            Expanded(
              child: _selectedTab == 2
                  ? _buildCustomInput()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _selectedTab == 0 
                          ? _popularDuas.length 
                          : DuaLibrary.duas.length,
                      itemBuilder: (context, index) {
                        final dua = _selectedTab == 0 
                            ? _popularDuas[index] 
                            : DuaLibrary.duas[index];
                        return _DuaQuickCard(
                          dua: dua,
                          language: _selectedLang,
                          onTap: () => widget.onSelectDua(dua, _selectedLang),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your own text:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Type Arabic text, a quote, or any message...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _customController.text.isEmpty ? null : () {
                widget.onSelectSample(PostContent(
                  arabicText: _customController.text,
                  translationText: '',
                  transliterationText: '',
                  referenceText: '',
                  category: PostCategory.custom,
                ));
              },
              child: const Text('Use This Text'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _DuaQuickCard extends StatelessWidget {
  final DuaItem dua;
  final TranslationLanguage language;
  final VoidCallback onTap;

  const _DuaQuickCard({
    required this.dua,
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dua.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dua.arabic,
                      style: const TextStyle(fontSize: 16),
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      dua.getTranslation(language),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.add_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick style picker
class _QuickStylePicker extends StatelessWidget {
  final PostEditorProvider editor;
  final VoidCallback onClose;

  const _QuickStylePicker({
    required this.editor,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.7,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(75),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.palette),
                    const SizedBox(width: 8),
                    const Text(
                      'Choose Style',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: onClose),
                  ],
                ),
              ),

              // Size options
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Size', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: PostAspectRatio.values.map((ratio) {
                          final isSelected = editor.aspectRatio == ratio;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(ratio.icon, size: 16),
                              label: Text(ratio.displayName),
                              selected: isSelected,
                              onSelected: (_) => editor.setAspectRatio(ratio),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Color themes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Color Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: PostTemplate.templates.length,
                      itemBuilder: (context, index) {
                        final template = PostTemplate.templates[index];
                        final isSelected = editor.selectedTemplate?.id == template.id;
                        return GestureDetector(
                          onTap: () => editor.applyTemplate(template),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: template.gradient?.toGradient() ?? 
                                  GradientPreset.presets[0].toGradient(),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: theme.colorScheme.primary, width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Display toggles
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Show', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Arabic'),
                          selected: editor.textStyle.showArabic,
                          onSelected: (v) => editor.updateTextStyle(showArabic: v),
                        ),
                        FilterChip(
                          label: const Text('Translation'),
                          selected: editor.textStyle.showTranslation,
                          onSelected: (v) => editor.updateTextStyle(showTranslation: v),
                        ),
                        FilterChip(
                          label: const Text('Transliteration'),
                          selected: editor.textStyle.showTransliteration,
                          onSelected: (v) => editor.updateTextStyle(showTransliteration: v),
                        ),
                        FilterChip(
                          label: const Text('Decorations'),
                          selected: editor.showDecorations,
                          onSelected: editor.setShowDecorations,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// More options section (collapsed by default)
class _MoreOptionsSection extends StatelessWidget {
  final PostEditorProvider editor;

  const _MoreOptionsSection({required this.editor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        
        // Font size controls
        Row(
          children: [
            const Text('Arabic Size: '),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: editor.decreaseArabicFontSize,
              iconSize: 20,
            ),
            Text('${editor.textStyle.arabicFontSize.round()}'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: editor.increaseArabicFontSize,
              iconSize: 20,
            ),
            const Spacer(),
            const Text('Translation: '),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: editor.decreaseTranslationFontSize,
              iconSize: 20,
            ),
            Text('${editor.textStyle.translationFontSize.round()}'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: editor.increaseTranslationFontSize,
              iconSize: 20,
            ),
          ],
        ),

        // Pattern toggle
        SwitchListTile(
          title: const Text('Pattern Overlay'),
          value: editor.background.patternType != PatternType.none,
          onChanged: (v) {
            if (v) {
              editor.updateBackground(patternType: PatternType.geometric);
            } else {
              editor.updateBackground(patternType: PatternType.none);
            }
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
