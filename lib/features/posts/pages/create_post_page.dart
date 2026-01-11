import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/services/storage_service.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _tagsController = TextEditingController();
  final HtmlEditorController _editorController = HtmlEditorController();
  final StorageService _storageService = StorageService();
  
  String _selectedCategory = AppConstants.postCategories[0];
  bool _isLoading = false;
  Uint8List? _imageData;

  @override
  void dispose() {
    _titleController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _storageService.pickImage();
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _imageData = bytes);
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();
      
      if (user == null) throw Exception('User not found');

      // Upload image if selected
      String? imageUrl;
      if (_imageData != null) {
        imageUrl = await _storageService.uploadPostImage(
          _imageData!,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      final content = await _editorController.getText();
      
      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final post = PostModel(
        id: '',
        authorId: user.uid,
        authorName: user.displayName,
        authorPhotoURL: user.photoURL,
        title: _titleController.text.trim(),
        content: imageUrl != null ? '$content<br><img src="$imageUrl" />' : content,
        category: _selectedCategory,
        tags: tags,
        createdAt: DateTime.now(),
      );

      await FirestoreService().createPost(post);
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Post created successfully!',
          backgroundColor: AppTheme.successColor,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publish'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter post title',
                    ),
                    style: Theme.of(context).textTheme.headlineSmall,
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
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: AppConstants.postCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'flutter, firebase, dart (comma separated)',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_imageData != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_imageData!, height: 200, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => setState(() => _imageData = null),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Add Image'),
                  ),
                  const SizedBox(height: 24),
                  Text('Content', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: HtmlEditor(
                      controller: _editorController,
                      htmlEditorOptions: const HtmlEditorOptions(
                        hint: 'Write your post content here...',
                        shouldEnsureVisible: true,
                      ),
                      htmlToolbarOptions: const HtmlToolbarOptions(
                        defaultToolbarButtons: [
                          StyleButtons(),
                          FontSettingButtons(),
                          ListButtons(),
                          InsertButtons(
                            otherFile: false,
                            video: false,
                            audio: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warningColor.withAlpha(51)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.warningColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Make sure your post follows community guidelines',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
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
}
