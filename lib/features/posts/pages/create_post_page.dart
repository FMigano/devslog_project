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
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBackground,
              AppTheme.darkSurface.withOpacity(0.3),
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                    ),
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
                    ],
                  ),
                ),
              ),
            ),
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
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.darkPrimary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkPrimary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
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
        throw Exception('Please add some content to your post');
      }

      // Insert image into content if available (stored as base64)
      if (_imageDataUrl != null) {
        content = '<div style="text-align: center; margin: 20px 0;"><img src="$_imageDataUrl" style="max-width: 100%; height: auto; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.2);" /></div>$content';
      }

      final tags = List<String>.from(_selectedTags);

      final post = PostModel(
        id: '',
        authorId: user.uid,
        authorName: user.displayName,
        authorPhotoURL: user.photoURL,
        title: _titleController.text.trim(),
        content: content,
        category: _selectedCategory,
        tags: tags,
        upvotes: 0,
        downvotes: 0,
        commentCount: 0,
        viewCount: 0,
        views: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await FirestoreService().createPost(post);

      if (mounted) {
        Fluttertoast.showToast(
          msg: '🚀 Post published successfully!',
          backgroundColor: AppTheme.successColor,
          toastLength: Toast.LENGTH_LONG,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to publish: ${e.toString()}',
          backgroundColor: AppTheme.errorColor,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
