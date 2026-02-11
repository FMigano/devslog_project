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
import '../../../shared/models/post_model.dart';

class CreatePostModal extends StatefulWidget {
  const CreatePostModal({super.key});

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> with SingleTickerProviderStateMixin {
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
  
  bool _showContentEnhancement = false;
  bool _isEnhancingContent = false;
  Map<String, dynamic>? _contentEnhancementResults;
  List<Map<String, dynamic>> _similarPosts = [];

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
    _checkAiAvailability();
  }

  Future<void> _checkAiAvailability() async {
    final available = await _aiService.isAvailable();
    if (mounted) {
      setState(() => _aiAvailable = available);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Center(
          child: Container(
            width: screenWidth > 1400 
                ? 1200
                : screenWidth > 1200 
                  ? 1000
                  : screenWidth > 900 
                    ? 900
                    : screenWidth > 600 
                      ? 700
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
                
                // Header with action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, color: AppTheme.darkPrimary, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Create New Post',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                      ),
                      const Spacer(),
                      // AI Tags Button
                      if (_aiAvailable)
                        _buildHeaderButton(
                          icon: _isGeneratingTags ? null : Icons.auto_awesome,
                          label: _isGeneratingTags ? 'Generating...' : 'AI Tags',
                          color: Colors.purple,
                          onTap: !_isGeneratingTags ? _generateAiTags : null,
                          isLoading: _isGeneratingTags,
                        ),
                      const SizedBox(width: 8),
                      // Enhance Button
                      if (_aiAvailable)
                        _buildHeaderButton(
                          icon: _isEnhancingContent ? null : Icons.auto_fix_high,
                          label: _isEnhancingContent ? 'Enhancing...' : 'Enhance',
                          color: Colors.blue,
                          onTap: !_isEnhancingContent ? _enhancePostWithAI : null,
                          isLoading: _isEnhancingContent,
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.close, color: AppTheme.darkTextPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),
                
                // Content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildTitleField(),
                        const SizedBox(height: 20),
                        _buildCategorySelector(),
                        const SizedBox(height: 20),
                        _buildTagsSection(),
                        const SizedBox(height: 20),
                        _buildImageSection(),
                        const SizedBox(height: 20),
                        _buildContentEditor(),
                        if (_showContentEnhancement && _contentEnhancementResults != null) ...[
                          const SizedBox(height: 20),
                          _buildContentEnhancementPanel(),
                        ],
                        const SizedBox(height: 20),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderButton({
    required IconData? icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                )
              else if (icon != null)
                Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
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
          fontSize: 18,
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
    );
  }

  Widget _buildCategorySelector() {
    return Container(
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
        value: _selectedCategory,
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
        dropdownColor: AppTheme.darkSurface,
        style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 16),
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
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            return InkWell(
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
                  color: isSelected ? null : AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.darkPrimary : AppTheme.darkDivider,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.white, size: 16),
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
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image, color: Colors.purple, size: 20),
            const SizedBox(width: 8),
            Text(
              'Attach Image (Optional)',
              style: TextStyle(
                color: Colors.purple,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                border: Border.all(color: Colors.purple.withOpacity(0.5), width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate, color: Colors.purple, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Click to attach an image',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Max size: 2MB',
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(_imageDataUrl!.split(',')[1]),
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: _removeImage,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildContentEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note, color: Colors.teal, size: 20),
            const SizedBox(width: 8),
            Text(
              'Content',
              style: TextStyle(
                color: Colors.teal,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal.withOpacity(0.3), width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HtmlEditor(
              controller: _htmlController,
              htmlEditorOptions: const HtmlEditorOptions(
                hint: '✍️ Share your thoughts...',
                darkMode: true,
              ),
              htmlToolbarOptions: HtmlToolbarOptions(
                toolbarPosition: ToolbarPosition.aboveEditor,
                toolbarType: ToolbarType.nativeScrollable,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentEnhancementPanel() {
    if (_contentEnhancementResults == null) {
      print('⚠️ Content enhancement results are null');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.sentiment_satisfied, 
                color: AppTheme.darkTextSecondary, size: 48),
              SizedBox(height: 12),
              Text(
                'Your post looks great!\nNo improvements needed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    print('📊 Enhancement results: $_contentEnhancementResults');
  
    final improvedTitle = _contentEnhancementResults?['improvedTitle']?.toString() ?? '';
    final suggestions = _contentEnhancementResults?['suggestions'];
  
    List<String> suggestionList = [];
    if (suggestions != null) {
      if (suggestions is List) {
        suggestionList = suggestions.map((s) => s.toString()).toList();
      }
    }

    print('📝 Improved title: $improvedTitle');
    print('💡 Suggestions: $suggestionList');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.darkSurface,
            AppTheme.darkSurface.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade400, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.blue.shade300, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'AI Enhancement Suggestions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkTextPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => _showContentEnhancement = false),
                icon: Icon(Icons.close, color: AppTheme.darkTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (improvedTitle.isNotEmpty && improvedTitle != _titleController.text) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.title, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Improved Title:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    improvedTitle,
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _titleController.text = improvedTitle);
                      Fluttertoast.showToast(
                        msg: '✨ Title updated!',
                        backgroundColor: AppTheme.successColor,
                      );
                    },
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Use This Title'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          if (suggestionList.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Text(
                  'Content Improvements:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestionList.map((suggestion) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          color: AppTheme.darkTextPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          
          if (improvedTitle.isEmpty && suggestionList.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.sentiment_satisfied, 
                      color: AppTheme.darkTextSecondary, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Your post looks great!\nNo improvements needed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimilarPostsWarning() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: AppTheme.warningColor),
              SizedBox(width: 8),
              Text(
                'Similar posts found',
                style: TextStyle(
                  color: AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ..._similarPosts.take(3).map((post) {
            return Text(
              '• ${post['title']}',
              style: TextStyle(color: AppTheme.darkTextPrimary),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _submitPost,
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(Icons.rocket_launch),
        label: Text(_isLoading ? 'Publishing...' : 'Publish Post'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      Fluttertoast.showToast(
        msg: '⚠️ Please fill in all required fields',
        backgroundColor: AppTheme.warningColor,
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

      if (user == null) throw Exception('User not found');

      String content = await _htmlController.getText();
      if (content.isEmpty || content == '<p></p>' || content == '<p><br></p>') {
        throw Exception('Content cannot be empty');
      }

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
        Navigator.pop(context);
        Fluttertoast.showToast(
          msg: '✨ Post submitted for approval!',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );
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

// Helper function
void showCreatePostModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    builder: (context) => const CreatePostModal(),
  );
}