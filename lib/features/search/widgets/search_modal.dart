import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/post_card.dart';
import '../../posts/widgets/post_detail_modal.dart';
import '../../../shared/services/ai_summarizer_service.dart';

class SearchModal extends StatefulWidget {
  final String? initialQuery;
  
  const SearchModal({super.key, this.initialQuery});

  @override
  State<SearchModal> createState() => _SearchModalState();
}

class _SearchModalState extends State<SearchModal> {
  late TextEditingController _searchController;
  List<PostModel> _searchResults = [];
  bool _isSearching = false;
  String _searchType = 'title'; // title, tags, author
  final AiSummarizerService _aiService = AiSummarizerService();
  List<String> _aiSuggestions = [];
  bool _showAiSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      if (widget.initialQuery!.startsWith('#')) {
        _searchType = 'tags';
      } else if (widget.initialQuery!.startsWith('@')) {
        _searchType = 'author';
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(_searchController.text);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('isApproved', isEqualTo: true)
          .get();

      List<PostModel> results = [];
      final searchQuery = query.toLowerCase().trim();
      final cleanQuery = searchQuery.startsWith('#') 
          ? searchQuery.substring(1) 
          : searchQuery;

      for (var doc in snapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        bool matches = false;

        switch (_searchType) {
          case 'title':
            matches = post.title.toLowerCase().contains(cleanQuery);
            break;
          case 'tags':
            matches = post.tags.any((tag) => 
                tag.toLowerCase().contains(cleanQuery));
            break;
          case 'author':
            final authorQuery = cleanQuery.startsWith('@') 
                ? cleanQuery.substring(1) 
                : cleanQuery;
            matches = post.authorName.toLowerCase().contains(authorQuery);
            break;
        }

        if (matches) {
          results.add(post);
        }
      }

      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.6,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Center(
          child: Container(
            width: screenWidth > 1400 
                ? 1500
                : screenWidth > 1200 
                  ? 1300
                  : screenWidth > 900 
                    ? 1150
                    : screenWidth > 600 
                      ? 1050
                      : screenWidth * 0.98,
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.darkDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: AppTheme.darkPrimary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Search Posts',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: AppTheme.darkTextPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Search bar and filters
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: TextStyle(color: AppTheme.darkTextPrimary),
                        decoration: InputDecoration(
                          hintText: _getHintText(),
                          hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
                          prefixIcon: Icon(Icons.search, color: AppTheme.darkPrimary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: AppTheme.darkTextSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.darkDivider),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isEmpty) {
                            setState(() => _searchResults = []);
                          }
                        },
                        onSubmitted: _performSearch,
                      ),
                      const SizedBox(height: 16),
                      
                      // Filter chips
                      Row(
                        children: [
                          _buildFilterChip('Title', 'title', Icons.title),
                          const SizedBox(width: 8),
                          _buildFilterChip('Tags', 'tags', Icons.tag),
                          const SizedBox(width: 8),
                          _buildFilterChip('Author', 'author', Icons.person),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () => _performSearch(_searchController.text),
                            icon: const Icon(Icons.search, size: 20),
                            label: const Text('Search'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.darkPrimary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Results
                Expanded(
                  child: _isSearching
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.darkPrimary,
                          ),
                        )
                      : _searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: AppTheme.darkTextSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'Start typing to search'
                                        : 'No results found',
                                    style: TextStyle(
                                      color: AppTheme.darkTextSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.all(20),
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final post = _searchResults[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: PostCard(
                                    post: post,
                                    onTap: () {
                                      showPostDetailModal(context, post);
                                    },
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getHintText() {
    switch (_searchType) {
      case 'title':
        return 'Search by title...';
      case 'tags':
        return 'Search by tags (e.g., #flutter)...';
      case 'author':
        return 'Search by author (e.g., @username)...';
      default:
        return 'Search posts...';
    }
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _searchType == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.darkTextSecondary),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _searchType = value);
      },
      backgroundColor: AppTheme.darkSurface,
      selectedColor: AppTheme.darkPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
      ),
    );
  }
}

// Helper function to show the modal
void showSearchModal(BuildContext context, {String? initialQuery}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SearchModal(initialQuery: initialQuery),
  );
}