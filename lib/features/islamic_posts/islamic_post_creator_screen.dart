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
import 'providers/post_editor_provider.dart';
import 'widgets/post_preview_widget.dart';
import 'widgets/template_selector_widget.dart';
import 'widgets/background_picker_widget.dart';
import 'widgets/text_editor_panel_widget.dart';

class IslamicPostCreatorScreen extends StatefulWidget {
  const IslamicPostCreatorScreen({super.key});

  @override
  State<IslamicPostCreatorScreen> createState() => _IslamicPostCreatorScreenState();
}

class _IslamicPostCreatorScreenState extends State<IslamicPostCreatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _repaintKey = GlobalKey();
  final PostEditorProvider _editor = PostEditorProvider();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Apply default template
    _editor.applyTemplate(PostTemplate.templates.first);
    _editor.addListener(_onEditorChanged);
  }

  void _onEditorChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editor.removeListener(_onEditorChanged);
    _editor.dispose();
    super.dispose();
  }

  Future<void> _saveAndShare() async {
    if (_isSaving) return;
    if (_editor.content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content first')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Capture the widget as image
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      
      if (boundary == null) {
        throw Exception('Could not capture image');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/islamic_post_$timestamp.png');
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Created with Azanify',
      );
    } catch (e) {
      debugPrint('Error saving/sharing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    if (_editor.content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content first')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      
      if (boundary == null) {
        throw Exception('Could not capture image');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      // Save to downloads/pictures directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/islamic_post_$timestamp.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.shareXFiles([XFile(file.path)]),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

            // Preview
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: Center(
                  child: PostPreviewWidget(
                    editor: _editor,
                    repaintKey: _repaintKey,
                  ),
                ),
              ),
            ),

            // Aspect ratio selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: PostAspectRatio.values.map((ratio) {
                  final isSelected = _editor.aspectRatio == ratio;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Tooltip(
                      message: ratio.displayName,
                      child: InkWell(
                        onTap: () => _editor.setAspectRatio(ratio),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
                          child: Icon(
                            ratio.icon,
                            size: 20,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard), text: 'Templates'),
                  Tab(icon: Icon(Icons.edit), text: 'Content'),
                  Tab(icon: Icon(Icons.palette), text: 'Style'),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Templates tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        TemplateSelectorWidget(editor: _editor),
                        const SizedBox(height: 16),
                        // Quick options
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SwitchListTile(
                            title: const Text('Decorations'),
                            subtitle: const Text('Show decorative elements'),
                            value: _editor.showDecorations,
                            onChanged: _editor.setShowDecorations,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextEditorPanelWidget(editor: _editor),
                  ),
                  // Style tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: BackgroundPickerWidget(editor: _editor),
                  ),
                ],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _saveToGallery,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveAndShare,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.share),
                        label: Text(_isSaving ? 'Processing...' : 'Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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
}
