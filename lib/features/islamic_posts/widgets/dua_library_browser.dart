import 'package:flutter/material.dart';
import '../models/dua_library.dart';
import '../providers/post_editor_provider.dart';

/// Widget for browsing and selecting duas with multi-language support
class DuaLibraryBrowser extends StatefulWidget {
  final PostEditorProvider editor;
  final VoidCallback onSelect;

  const DuaLibraryBrowser({
    super.key,
    required this.editor,
    required this.onSelect,
  });

  @override
  State<DuaLibraryBrowser> createState() => _DuaLibraryBrowserState();
}

class _DuaLibraryBrowserState extends State<DuaLibraryBrowser> {
  DuaCategory? _selectedCategory;
  TranslationLanguage _selectedLanguage = TranslationLanguage.english;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<DuaItem> get _filteredDuas {
    List<DuaItem> duas;
    
    if (_searchQuery.isNotEmpty) {
      duas = DuaLibrary.searchDuas(_searchQuery);
    } else if (_selectedCategory != null) {
      duas = DuaLibrary.getDuasByCategory(_selectedCategory!);
    } else {
      duas = DuaLibrary.duas;
    }
    
    return duas;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
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
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Dua Library',
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

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search duas...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Language selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Translation:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TranslationLanguage>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          items: TranslationLanguage.values.map((lang) {
                            return DropdownMenuItem(
                              value: lang,
                              child: Text(lang.displayName),
                            );
                          }).toList(),
                          onChanged: (lang) {
                            if (lang != null) {
                              setState(() => _selectedLanguage = lang);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null && _searchQuery.isEmpty,
                      onSelected: (_) => setState(() {
                        _selectedCategory = null;
                        _searchQuery = '';
                        _searchController.clear();
                      }),
                    ),
                  ),
                  ...DuaLibrary.availableCategories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        avatar: Icon(category.icon, size: 16),
                        label: Text(category.displayName),
                        selected: _selectedCategory == category,
                        onSelected: (_) => setState(() {
                          _selectedCategory = category;
                          _searchQuery = '';
                          _searchController.clear();
                        }),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(color: theme.dividerColor),

            // Duas list
            Expanded(
              child: _filteredDuas.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No duas found',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredDuas.length,
                      itemBuilder: (context, index) {
                        final dua = _filteredDuas[index];
                        return _DuaCard(
                          dua: dua,
                          selectedLanguage: _selectedLanguage,
                          onSelect: () {
                            widget.editor.updateContent(
                              arabicText: dua.arabic,
                              translationText: dua.getTranslation(_selectedLanguage),
                              transliterationText: dua.transliteration,
                              referenceText: dua.source ?? '',
                            );
                            widget.onSelect();
                          },
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

class _DuaCard extends StatelessWidget {
  final DuaItem dua;
  final TranslationLanguage selectedLanguage;
  final VoidCallback onSelect;

  const _DuaCard({
    required this.dua,
    required this.selectedLanguage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translation = dua.getTranslation(selectedLanguage);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      dua.category.icon,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dua.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (dua.occasion != null)
                          Text(
                            dua.occasion!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.add_circle,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Arabic text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dua.arabic,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.8,
                    fontFamily: 'Arial',
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),

              // Transliteration
              Text(
                dua.transliteration,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Translation in selected language
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.translate,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedLanguage.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      translation,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4,
                      ),
                      textDirection: selectedLanguage.isRTL
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                  ],
                ),
              ),

              // Source
              if (dua.source != null) ...[
                const SizedBox(height: 8),
                Text(
                  '— ${dua.source}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
