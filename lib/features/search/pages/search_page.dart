import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/widgets/post_card.dart';
import '../../posts/pages/post_detail_page.dart';
import 'dart:developer' as logger;
import '../../../shared/services/ai_summarizer_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
    
    // Auto-detect search type from initial query
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      if (widget.initialQuery!.startsWith('#')) {
        _searchType = 'tags';
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
      // Get all approved posts
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
            // Search in title and content
            matches = post.title.toLowerCase().contains(cleanQuery) ||
                     post.content.toLowerCase().contains(cleanQuery);
            break;

          case 'tags':
            // Search in tags array
            if (post.tags.isNotEmpty) {
              matches = post.tags.any((tag) => 
                tag.toLowerCase().contains(cleanQuery)
              );
            }
            break;

          case 'author':
            // Search by author name
            matches = post.authorName.toLowerCase().contains(cleanQuery);
            break;
        }

        if (matches) {
          results.add(post);
        }
      }

      // Sort by creation date (newest first)
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _generateAiSuggestions(String query) async {
    if (query.length < 3) {
      setState(() {
        _aiSuggestions = [];
        _showAiSuggestions = false;
      });
      return;
    }
    
    try {
      final suggestions = await _aiService.generateSearchSuggestions(query);
      if (mounted && suggestions.isNotEmpty) {
        setState(() {
          _aiSuggestions = suggestions;
          _showAiSuggestions = true;
        });
      }
    } catch (e) {
      print('AI suggestions error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Search Posts'),
        elevation: 1,
      ),
      body: Column(
        children: [
          // Search bar with filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.darkSurface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
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
                              _performSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.darkSurfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.darkPrimary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length > 2) {
                      _performSearch(value);
                      _generateAiSuggestions(value);
                    } else {
                      setState(() {
                        _searchResults = [];
                        _aiSuggestions = [];
                        _showAiSuggestions = false;
                      });
                    }
                  },
                  textInputAction: TextInputAction.search,
                  onSubmitted: _performSearch,
                ),
                const SizedBox(height: 12),
                // Search type filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Title & Content', 'title', Icons.title),
                      const SizedBox(width: 8),
                      _buildFilterChip('Tags', 'tags', Icons.tag),
                      const SizedBox(width: 8),
                      _buildFilterChip('Author', 'author', Icons.person),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Results count
          if (_searchController.text.isNotEmpty && !_isSearching)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.darkSurface,
              child: Row(
                children: [
                  Text(
                    '${_searchResults.length} result${_searchResults.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          
          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppTheme.darkTextSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.darkTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchController.text.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 64,
                                  color: AppTheme.darkTextSecondary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Start typing to search',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.darkTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Search by $_searchType',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: PostCard(
                                  post: _searchResults[index],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostDetailPage(
                                          postId: _searchResults[index].id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _getHintText() {
    switch (_searchType) {
      case 'tags':
        return 'Search by tags (e.g., flutter, dart)...';
      case 'author':
        return 'Search by author name...';
      default:
        return 'Search posts by title or content...';
    }
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _searchType == value;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 16, 
            color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _searchType = value;
          if (_searchController.text.isNotEmpty) {
            _performSearch(_searchController.text);
          }
        });
      },
      backgroundColor: AppTheme.darkSurfaceVariant,
      selectedColor: AppTheme.darkPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.darkTextPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      elevation: isSelected ? 2 : 0,
      pressElevation: 4,
    );
  }

  Widget _buildAiSuggestionsChips() {
    if (_aiSuggestions.isEmpty) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'AI Suggestions',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _aiSuggestions.map((suggestion) {
              return ActionChip(
                label: Text(suggestion),
                avatar: Icon(Icons.search, size: 16),
                onPressed: () {
                  _searchController.text = suggestion;
                  _performSearch(suggestion);
                },
                backgroundColor: Colors.purple.withOpacity(0.1),
                labelStyle: TextStyle(color: Colors.purple),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

Future<void> main() async {
  print('🔍 Testing Ollama AI Features...\n');
  
  // Test 1: Connection
  print('1️⃣ Testing connection...');
  try {
    final response = await http.get(
      Uri.parse('http://localhost:11434/api/tags'),
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      print('✅ Ollama is running!');
      final models = jsonDecode(response.body)['models'];
      print('Available models: ${models.map((m) => m['name']).join(', ')}');
    }
  } catch (e) {
    print('❌ Connection failed: $e');
    print('Make sure Ollama is running: ollama serve');
    return;
  }
  
  // Test 2: Tag generation
  print('\n2️⃣ Testing tag generation...');
  try {
    final response = await http.post(
      Uri.parse('http://localhost:11434/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'llama3.2',
        'prompt': '''Suggest 5 tags for this post: "Building a Flutter app with Firebase authentication"
Return only comma-separated tags:''',
        'stream': false,
      }),
    ).timeout(Duration(seconds: 30));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Generated tags: ${data['response']}');
    }
  } catch (e) {
    print('❌ Tag generation failed: $e');
  }
  
  // Test 3: Summary generation
  print('\n3️⃣ Testing summary generation...');
  try {
    final response = await http.post(
      Uri.parse('http://localhost:11434/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'llama3.2',
        'prompt': '''Summarize in 2 sentences: "Flutter is Google's UI toolkit for building natively compiled applications for mobile, web, and desktop from a single codebase."

Summary:''',
        'stream': false,
      }),
    ).timeout(Duration(seconds: 30));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Summary: ${data['response']}');
    }
  } catch (e) {
    print('❌ Summary generation failed: $e');
  }
  
  print('\n✨ Testing complete!');
}
