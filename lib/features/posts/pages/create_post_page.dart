import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/storage_service.dart';
import '../../../shared/services/ai_summarizer_service.dart';
import '../../../shared/services/duplicate_detection_service.dart'; // ← ADD THIS LINE
import '../../../shared/models/post_model.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  final HtmlEditorController _htmlController = HtmlEditorController();
  final StorageService _storageService = StorageService();
  
  String _selectedCategory = AppConstants.postCategories[0];
  bool _isLoading = false;
  final List<String> _selectedTags = [];
  PlatformFile? _selectedImage;
  String? _imageDataUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final AiSummarizerService _aiService = AiSummarizerService();
  bool _isGeneratingTags = false;
  bool _aiAvailable = false;
  bool _showEnhancements = false;
  List<String> _contentSuggestions = [];
  String _improvedTitle = '';
  bool _isEnhancing = false;
  
  bool _showContentEnhancement = false;
  bool _isEnhancingContent = false;
  Map<String, dynamic>? _contentEnhancementResults;

  final DuplicateDetectionService _duplicateService = DuplicateDetectionService();
  List<Map<String, dynamic>> _similarPosts = [];
  bool _showSimilarPosts = false;
  bool _checkingDuplicates = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    // ⭐ ADD THIS LINE - You're missing this call!
    _checkAiAvailability();
  }

  Future<void> _checkAiAvailability() async {
    final available = await _aiService.isAvailable();
    if (mounted) {
      setState(() => _aiAvailable = available);
      if (!available) {
        print('💡 Tip: Start Ollama to enable AI features');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await _storageService.pickImage();
      if (result != null && result.bytes != null) {
        // Check file size (max 2MB for base64)
        if (result.size > 2 * 1024 * 1024) {
          Fluttertoast.showToast(
            msg: 'Image too large! Please select an image under 2MB',
            backgroundColor: AppTheme.warningColor,
            toastLength: Toast.LENGTH_LONG,
          );
          return;
        }

        setState(() {
          _selectedImage = result;
        });
        
        // Convert to base64 data URL with compression
        final dataUrl = _storageService.convertImageToBase64(
          result.bytes!,
          compress: true,
        );
        
        setState(() {
          _imageDataUrl = dataUrl;
        });
        
        Fluttertoast.showToast(
          msg: '✨ Image attached successfully!',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to attach image: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageDataUrl = null;
    });
    Fluttertoast.showToast(
      msg: 'Image removed',
      backgroundColor: AppTheme.darkTextSecondary,
    );
  }

  Future<void> _generateAiTags() async {
    if (_titleController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ Please enter a title first',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isGeneratingTags = true);

    try {
      final content = await _htmlController.getText();
      
      if (content.isEmpty || content == '<p></p>' || content == '<p><br></p>') {
        Fluttertoast.showToast(
          msg: '⚠️ Please add some content first',
          backgroundColor: AppTheme.warningColor,
        );
        setState(() => _isGeneratingTags = false);
        return;
      }

      Fluttertoast.showToast(
        msg: '🤖 AI is analyzing your post...',
        backgroundColor: Colors.purple,
      );

      final suggestions = await _aiService.generateTopicSuggestions(
        _titleController.text,
        content,
      );

      if (suggestions.isNotEmpty) {
        setState(() {
          // Add AI suggestions to existing tags
          for (var tag in suggestions) {
            if (!_selectedTags.contains(tag)) {
              _selectedTags.add(tag);
            }
          }
        });

        Fluttertoast.showToast(
          msg: '✨ Added ${suggestions.length} AI-suggested tags!',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );
      } else {
        Fluttertoast.showToast(
          msg: '⚠️ Could not generate tags. Is Ollama running?',
          backgroundColor: AppTheme.warningColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ AI error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      setState(() => _isGeneratingTags = false);
    }
  }

  Future<void> _enhancePostWithAI() async {
    if (_titleController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ Please enter a title first',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isEnhancingContent = true);

    try {
      final content = await _htmlController.getText();
      
      if (content.isEmpty || content == '<p></p>') {
        Fluttertoast.showToast(
          msg: '⚠️ Please add some content first',
          backgroundColor: AppTheme.warningColor,
        );
        setState(() => _isEnhancingContent = false);
        return;
      }

      Fluttertoast.showToast(
        msg: '🤖 AI is analyzing your post...',
        backgroundColor: Colors.purple,
      );

      final enhancement = await _aiService.enhancePostContent(
        _titleController.text,
        content,
      );

      if (enhancement != null) {
        setState(() {
          _contentEnhancementResults = enhancement;
          _showContentEnhancement = true;
        });

        Fluttertoast.showToast(
          msg: '✨ Enhancement suggestions ready!',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Enhancement error: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      setState(() => _isEnhancingContent = false);
    }
  }

  Future<void> _checkForDuplicates() async {
    if (_titleController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ Please enter a title first',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _checkingDuplicates = true);

    try {
      final content = await _htmlController.getText();
      
      if (content.isEmpty || content == '<p></p>') {
        Fluttertoast.showToast(
          msg: '⚠️ Please add some content first',
          backgroundColor: AppTheme.warningColor,
        );
        setState(() => _checkingDuplicates = false);
        return;
      }

      Fluttertoast.showToast(
        msg: '🔍 Checking for similar posts...',
        backgroundColor: Colors.blue,
      );

      final similar = await _duplicateService.findSimilarPosts(
        title: _titleController.text,
        content: content,
        tags: _selectedTags,
      );

      if (mounted) {
        setState(() {
          _similarPosts = similar;
          _showSimilarPosts = similar.isNotEmpty;
        });

        if (similar.isNotEmpty) {
          Fluttertoast.showToast(
            msg: '⚠️ Found ${similar.length} similar post(s)',
            backgroundColor: AppTheme.warningColor,
            toastLength: Toast.LENGTH_LONG,
          );
        } else {
          Fluttertoast.showToast(
            msg: '✅ No duplicates found',
            backgroundColor: AppTheme.successColor,
          );
        }
      }
    } catch (e) {
      print('Error checking duplicates: $e');
      Fluttertoast.showToast(
        msg: '❌ Error checking duplicates',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() => _checkingDuplicates = false);
      }
    }
  }


  Widget _buildContentEnhancementPanel() {
    final improvedTitle = _contentEnhancementResults?['improvedTitle'] ?? '';
    final suggestions = List<String>.from(_contentEnhancementResults?['suggestions'] ?? []);
    final readabilityScore = _contentEnhancementResults?['readabilityScore'] ?? 'Good';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // ✅ FIXED: Dark background with gradient
        gradient: LinearGradient(
          colors: [
            AppTheme.darkSurface,
            AppTheme.darkSurfaceVariant,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade400, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // ✅ FIXED: Brighter icon color
                  Icon(Icons.auto_fix_high, color: Colors.blue.shade300, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'AI Enhancement Suggestions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // ✅ FIXED: White text
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => _showContentEnhancement = false),
                icon: Icon(Icons.close, color: Colors.white70), // ✅ FIXED: Visible close button
              ),
            ],
          ),
          const SizedBox(height: 20),
        
          // Improved Title Suggestion
          if (improvedTitle.isNotEmpty && improvedTitle != _titleController.text) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ✅ FIXED: Dark green background
                color: Colors.green.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade400, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.title, color: Colors.green.shade300), // ✅ FIXED
                      SizedBox(width: 8),
                      Text(
                        'Improved Title:', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // ✅ FIXED
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    improvedTitle, 
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white, // ✅ FIXED: White text
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _titleController.text = improvedTitle;
                      });
                      Fluttertoast.showToast(msg: '✨ Title updated!');
                    },
                    icon: Icon(Icons.check),
                    label: Text('Use This Title'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600, // ✅ FIXED: Darker green
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        
          // Content Suggestions
          if (suggestions.isNotEmpty) ...[
            Text(
              'Content Improvements:',
              style: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: Colors.white, // ✅ FIXED: White text
              ),
            ),
            const SizedBox(height: 12),
            ...suggestions.map((suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb, color: Colors.blue.shade300, size: 20), // ✅ FIXED
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      suggestion, 
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70, // ✅ FIXED: Light white text
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        
          const SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade900.withOpacity(0.3), // ✅ FIXED: Dark blue background
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade400.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20), // ✅ FIXED
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'These are suggestions to make your post more engaging and clearer!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70, // ✅ FIXED: Light white text
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkPrimary.withOpacity(0.8),
                AppTheme.darkPrimary,
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.create, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create Post',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Publish button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitPost,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.rocket_launch, size: 20),
              label: const Text(
                'Publish',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.darkPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
          _buildAiTagSuggestions(),
          // Check Duplicates button
          if (_aiAvailable)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Check for duplicate posts',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: !_checkingDuplicates ? _checkForDuplicates : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.8),
                            Colors.orange.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _checkingDuplicates
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                            : const Icon(
                                Icons.content_copy,
                                color: Colors.white,
                                size: 20,
                              ),
                          const SizedBox(width: 8),
                          Text(
                            _checkingDuplicates ? 'Checking...' : 'Check Duplicates',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Review Code button
          if (_aiAvailable)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Review code for issues',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: !_isEnhancingContent ? _enhancePostWithAI : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.8),
                            Colors.blue.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isEnhancingContent
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                            : const Icon(
                                Icons.auto_fix_high,
                                color: Colors.white,
                                size: 20,
                              ),
                          const SizedBox(width: 8),
                          Text(
                            _isEnhancingContent ? 'Enhancing...' : 'Enhance Post',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header Section
              _buildSectionHeader(
                icon: Icons.article_outlined,
                title: 'Post Details',
                gradient: LinearGradient(
                  colors: [AppTheme.darkPrimary, AppTheme.darkPrimary.withOpacity(0.6)],
                ),
              ),
              const SizedBox(height: 16),

              // Title, Category, and Tags Card
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Field with fancy styling
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.darkPrimary.withOpacity(0.1),
                            AppTheme.darkPrimary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextFormField(
                        controller: _titleController,
                        style: TextStyle(
                          color: AppTheme.darkTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: '✨ Title',
                          labelStyle: TextStyle(
                            color: AppTheme.darkPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: 'What\'s on your mind?',
                          hintStyle: TextStyle(
                            color: AppTheme.darkTextSecondary.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(Icons.title, color: AppTheme.darkPrimary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          if (value.length < 10) {
                            return 'Title must be at least 10 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Category Dropdown with gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.darkPrimary.withOpacity(0.1),
                            AppTheme.darkPrimary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: '📂 Category',
                          labelStyle: TextStyle(
                            color: AppTheme.darkPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: Icon(Icons.category, color: AppTheme.darkPrimary),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(20),
                        ),
                        dropdownColor: AppTheme.darkSurfaceVariant,
                        style: TextStyle(
                          color: AppTheme.darkTextPrimary,
                          fontSize: 16,
                        ),
                        items: AppConstants.postCategories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                            _selectedTags.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tags Section
                    Row(
                      children: [
                        Icon(Icons.label, color: AppTheme.darkPrimary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tags (Select at least one)',
                          style: TextStyle(
                            color: AppTheme.darkPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppConstants.getTagsForCategory(_selectedCategory).map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedTags.remove(tag);
                                  } else {
                                    _selectedTags.add(tag);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            AppTheme.darkPrimary,
                                            AppTheme.darkPrimary.withOpacity(0.7),
                                          ],
                                        )
                                      : null,
                                  color: isSelected ? null : AppTheme.darkSurfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.darkPrimary : AppTheme.darkDivider,
                                    width: 2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.darkPrimary.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    if (isSelected) const SizedBox(width: 6),
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  ),
                                ),
                              ),
                            )
                            );
                        }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Image Attachment Section
              _buildSectionHeader(
                icon: Icons.image_outlined,
                title: 'Attach Image',
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.purple.withOpacity(0.6)],
                ),
              ),
              const SizedBox(height: 16),
              _buildImageAttachmentCard(),
              const SizedBox(height: 32),

              // Content Editor Section
              _buildSectionHeader(
                icon: Icons.edit_note_outlined,
                title: 'Content',
                gradient: LinearGradient(
                  colors: [Colors.teal, Colors.teal.withOpacity(0.6)],
                ),
              ),
              const SizedBox(height: 16),
              _buildContentEditor(),

              // ⭐ ADD THIS - Show code review results panel
              if (_showContentEnhancement && _contentEnhancementResults != null) ...[
                const SizedBox(height: 32),
                _buildContentEnhancementPanel(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkDivider.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkPrimary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildImageAttachmentCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedImage == null)
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.withOpacity(0.1),
                      Colors.purple.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate,
                        color: Colors.purple,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Click to attach an image',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Max size: 2MB (stored as base64)',
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image preview with gradient overlay
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.memory(
                          base64Decode(_imageDataUrl!.split(',')[1]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withOpacity(0.9),
                              Colors.red.withOpacity(0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _removeImage,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // File info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withOpacity(0.1),
                        Colors.purple.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check_circle, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedImage!.name,
                              style: TextStyle(
                                color: AppTheme.darkTextPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_selectedImage!.size / 1024).toStringAsFixed(2)} KB',
                              style: TextStyle(
                                color: AppTheme.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAiTagSuggestions() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: _aiAvailable 
            ? 'Generate tags using AI' 
            : 'AI offline. Start Ollama to enable.',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _aiAvailable && !_isGeneratingTags ? _generateAiTags : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: _aiAvailable
                    ? LinearGradient(
                        colors: [
                          Colors.purple.withOpacity(0.8),
                          Colors.purple.withOpacity(0.6),
                        ],
                      )
                    : null,
                color: _aiAvailable ? null : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _aiAvailable ? Colors.purple : Colors.grey,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _isGeneratingTags
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                    : Icon(
                        _aiAvailable ? Icons.auto_awesome : Icons.cloud_off,
                        color: Colors.white,
                        size: 20,
                      ),
                  const SizedBox(width: 8),
                  Text(
                    _isGeneratingTags 
                        ? 'Generating...' 
                        : (_aiAvailable ? 'AI Tags' : 'AI Offline'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentEditor() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 450,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal.withOpacity(0.3), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HtmlEditor(
                controller: _htmlController,
                htmlEditorOptions: const HtmlEditorOptions(
                  hint: '✍️ Share your thoughts, code, and ideas...',
                  shouldEnsureVisible: true,
                  darkMode: true,
                ),
                htmlToolbarOptions: HtmlToolbarOptions(
                  toolbarPosition: ToolbarPosition.aboveEditor,
                  toolbarType: ToolbarType.nativeScrollable,
                  defaultToolbarButtons: [
                    const StyleButtons(),
                    const FontSettingButtons(fontSizeUnit: false),
                    const FontButtons(clearAll: false),
                    const ColorButtons(),
                    const ListButtons(listStyles: false),
                    const ParagraphButtons(
                      textDirection: false,
                      lineHeight: false,
                      caseConverter: false,
                    ),
                    const InsertButtons(
                      video: true,
                      audio: false,
                      table: true,
                      hr: true,
                      otherFile: false,
                    ),
                    const OtherButtons(
                      fullscreen: false,
                      codeview: true,
                      undo: true,
                      redo: true,
                      help: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      Fluttertoast.showToast(
        msg: '⚠️ Please fill in all required fields',
        backgroundColor: AppTheme.warningColor,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    if (_selectedTags.isEmpty) {
      Fluttertoast.showToast(
        msg: '⚠️ Please select at least one tag',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null) {
        throw Exception('User not found');
      }

      String content = await _htmlController.getText();
      if (content.isEmpty || content == '<p></p>' || content == '<p><br></p>') {
        throw Exception('Content cannot be empty');
      }

      // Create post with image data URL
      final post = PostModel(
        id: '',
        title: _titleController.text.trim(),
        content: _imageDataUrl != null 
            ? '<img src="$_imageDataUrl" style="max-width:100%; height:auto;" /><br>$content'
            : content,
        authorId: user.uid,
        authorName: user.displayName,
        authorEmail: user.email,
        category: _selectedCategory,
        tags: _selectedTags,
        createdAt: DateTime.now(),
      );

      await FirestoreService().createPost(post);

      if (mounted) {
        Fluttertoast.showToast(
          msg: '✨ Post submitted for approval!',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );

        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to create post: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
