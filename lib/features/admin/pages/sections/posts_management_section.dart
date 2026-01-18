import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post_model.dart';
import '../../widgets/pagination_controls.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import '../../widgets/empty_state_widget.dart';
import '../../services/admin_post_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:fluttertoast/fluttertoast.dart';

class PostsManagementSection extends StatefulWidget {
  const PostsManagementSection({super.key});

  @override
  State<PostsManagementSection> createState() => _PostsManagementSectionState();
}

class _PostsManagementSectionState extends State<PostsManagementSection> {
  final AdminPostService _postService = AdminPostService();
  final int _itemsPerPage = 10;
  int _currentPage = 0;
  String _searchQuery = '';
  String _filterCategory = 'all';
  String _sortBy = 'recent';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header and Filters
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withOpacity(0.5),
            border: Border(bottom: BorderSide(color: AppTheme.darkDivider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.article,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '📝 Posts Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  StreamBuilder<List<PostModel>>(
                    stream: _postService.getPostsStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: Text(
                          'Total: $count posts',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    flex: 3,
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search posts by title or author...',
                        hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
                        prefixIcon: Icon(Icons.search, color: AppTheme.darkTextSecondary),
                        filled: true,
                        fillColor: AppTheme.darkSurfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Category Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: DropdownButton<String>(
                      value: _filterCategory,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.darkSurface,
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      icon: Icon(Icons.filter_list, color: AppTheme.darkTextSecondary),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Categories')),
                        DropdownMenuItem(value: 'Web Development', child: Text('Web Development')),
                        DropdownMenuItem(value: 'Mobile Development', child: Text('Mobile Development')),
                        DropdownMenuItem(value: 'DevOps', child: Text('DevOps')),
                        DropdownMenuItem(value: 'UI/UX Design', child: Text('UI/UX Design')),
                        DropdownMenuItem(value: 'Database', child: Text('Database')),
                        DropdownMenuItem(value: 'General', child: Text('General')),
                      ],
                      onChanged: (value) => setState(() {
                        _filterCategory = value!;
                        _currentPage = 0;
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Sort By
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.darkSurface,
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      icon: Icon(Icons.sort, color: AppTheme.darkTextSecondary),
                      items: const [
                        DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
                        DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                        DropdownMenuItem(value: 'popular', child: Text('Most Popular')),
                      ],
                      onChanged: (value) => setState(() => _sortBy = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Posts Table
        Expanded(
          child: StreamBuilder<List<PostModel>>(
            stream: _postService.getPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.article_outlined,
                  title: 'No Posts Found',
                  message: 'There are no posts in the system yet.',
                );
              }

              var posts = snapshot.data!;

              // Apply filters
              if (_searchQuery.isNotEmpty) {
                posts = posts.where((post) {
                  return post.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      post.authorName.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();
              }

              if (_filterCategory != 'all') {
                posts = posts.where((post) => post.category == _filterCategory).toList();
              }

              // Apply sorting
              if (_sortBy == 'recent') {
                posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              } else if (_sortBy == 'oldest') {
                posts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
              } else if (_sortBy == 'popular') {
                posts.sort((a, b) => b.upvotes.compareTo(a.upvotes));
              }

              final totalPages = (posts.length / _itemsPerPage).ceil();
              final startIndex = _currentPage * _itemsPerPage;
              final endIndex = (startIndex + _itemsPerPage).clamp(0, posts.length);
              final paginatedPosts = posts.sublist(startIndex, endIndex);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.darkPrimary.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 40), // Status icon space
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      'Title',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Author',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Category',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Stats',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Created',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Actions',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table Rows
                            ...paginatedPosts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final post = entry.value;
                              final isEven = index % 2 == 0;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isEven
                                      ? AppTheme.darkSurfaceVariant.withOpacity(0.3)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppTheme.darkDivider.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Pin Status Icon
                                    SizedBox(
                                      width: 40,
                                      child: post.isPinned
                                          ? Icon(
                                              Icons.push_pin,
                                              color: AppTheme.warningColor,
                                              size: 18,
                                            )
                                          : const SizedBox(),
                                    ),
                                    // Title
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        post.title,
                                        style: TextStyle(
                                          color: AppTheme.darkTextPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                    // Author
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        post.authorName,
                                        style: TextStyle(
                                          color: AppTheme.darkTextSecondary,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Category
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getCategoryColor(post.category).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: _getCategoryColor(post.category),
                                          ),
                                        ),
                                        child: Text(
                                          post.category,
                                          style: TextStyle(
                                            color: _getCategoryColor(post.category),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    // Stats
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        children: [
                                          _buildStatBadge(
                                            Icons.visibility,
                                            post.views,
                                            Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStatBadge(
                                            Icons.comment,
                                            post.commentCount,
                                            Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStatBadge(
                                            Icons.thumb_up,
                                            post.upvotes,
                                            Colors.green,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Created
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        timeago.format(post.createdAt),
                                        style: TextStyle(
                                          color: AppTheme.darkTextSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    // Actions
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                              size: 18,
                                            ),
                                            color: post.isPinned
                                                ? AppTheme.warningColor
                                                : AppTheme.darkTextSecondary,
                                            onPressed: () => _togglePin(post),
                                            tooltip: post.isPinned ? 'Unpin' : 'Pin',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.visibility, size: 18),
                                            color: AppTheme.darkPrimary,
                                            onPressed: () => _viewPost(post),
                                            tooltip: 'View Details',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18),
                                            color: AppTheme.errorColor,
                                            onPressed: () => _deletePost(post),
                                            tooltip: 'Delete Post',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (totalPages > 1)
                    PaginationControls(
                      currentPage: _currentPage,
                      totalPages: totalPages,
                      onPageChanged: (page) => setState(() => _currentPage = page),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Web Development':
        return Colors.blue;
      case 'Mobile Development':
        return Colors.green;
      case 'DevOps':
        return Colors.orange;
      case 'UI/UX Design':
        return Colors.purple;
      case 'Database':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatBadge(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _togglePin(PostModel post) async {
    try {
      await _postService.togglePinPost(post.id, !post.isPinned);
      Fluttertoast.showToast(
        msg: post.isPinned ? '📌 Post unpinned' : '📌 Post pinned',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to ${post.isPinned ? 'unpin' : 'pin'} post',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _viewPost(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.darkDivider),
        ),
        title: Text(
          'Post Details',
          style: TextStyle(
            color: AppTheme.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostDetail('Title', post.title),
              _buildPostDetail('Author', post.authorName),
              _buildPostDetail('Category', post.category),
              _buildPostDetail('Views', '${post.views}'),
              _buildPostDetail('Comments', '${post.commentCount}'),
              _buildPostDetail('Upvotes', '${post.upvotes}'),
              _buildPostDetail('Downvotes', '${post.downvotes}'),
              _buildPostDetail('Created', timeago.format(post.createdAt)),
              _buildPostDetail('Pinned', post.isPinned ? 'Yes' : 'No'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(PostModel post) async {
    final confirm = await DeleteConfirmationDialog.show(
      context,
      title: 'Delete Post',
      message:
          'Are you sure you want to delete "${post.title}"? This will also delete all comments. This action cannot be undone.',
    );

    if (confirm == true) {
      try {
        await _postService.deletePost(post.id);
        Fluttertoast.showToast(
          msg: '✅ Post deleted successfully',
          backgroundColor: AppTheme.successColor,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: '❌ Failed to delete post: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }
}