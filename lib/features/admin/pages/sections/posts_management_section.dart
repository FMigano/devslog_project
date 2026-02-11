import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart'; // Add this import
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post_model.dart';
import '../../widgets/pagination_controls.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import '../../widgets/empty_state_widget.dart';
import '../../services/admin_post_service.dart';
import '../../services/post_approval_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/ai_summarizer_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:developer' as developer;

class PostsManagementSection extends StatefulWidget {
  const PostsManagementSection({super.key});

  @override
  State<PostsManagementSection> createState() => _PostsManagementSectionState();
}

class _PostsManagementSectionState extends State<PostsManagementSection> {
  final AdminPostService _postService = AdminPostService();
  final PostApprovalService _approvalService = PostApprovalService();
  final int _itemsPerPage = 10;
  int _currentPage = 0;
  String _searchQuery = '';
  String _filterCategory = 'all';
  String _sortBy = 'recent';
  String _filterType = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header and Filters
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withValues(alpha: 0.5),
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
                          color: Colors.orange.withValues(alpha: 0.2),
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
                ],
              ),
              const SizedBox(height: 24),
              // Search and Filters
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() {
                        _searchQuery = value;
                        _currentPage = 0;
                      }),
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search posts...',
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
                        DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                        DropdownMenuItem(value: 'views', child: Text('Most Viewed')),
                        DropdownMenuItem(value: 'upvotes', child: Text('Most Upvoted')),
                      ],
                      onChanged: (value) => setState(() => _sortBy = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Filter Chips
              Wrap(
                spacing: 8,
                children: [
                  _buildFilterChip('All Posts', _filterType == 'all'),
                  _buildFilterChip('Pending Approval', _filterType == 'pending'),
                  _buildFilterChip('Approved', _filterType == 'approved'),
                  _buildFilterChip('Rejected', _filterType == 'rejected'),
                ],
              ),
            ],
          ),
        ),

        // Posts Table
        Expanded(
          child: StreamBuilder<List<PostModel>>(
            stream: _getPostsStream(),
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

              // Apply filters IN CODE (not in Firestore query)
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
              switch (_sortBy) {
                case 'oldest':
                  posts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                  break;
                case 'views':
                  posts.sort((a, b) => b.views.compareTo(a.views));
                  break;
                case 'upvotes':
                  posts.sort((a, b) => b.upvotes.compareTo(a.upvotes));
                  break;
                default:
                  posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }

              // Pagination
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
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.darkSurfaceVariant.withValues(alpha: 0.5),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Title',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
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
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 200),
                                ],
                              ),
                            ),
                            // Table Body
                            ...paginatedPosts.asMap().entries.map((entry) {
                              final index = entry.key;
                              final post = entry.value;
                              final isLast = index == paginatedPosts.length - 1;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: isLast
                                        ? BorderSide.none
                                        : BorderSide(color: AppTheme.darkDivider),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Title
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.title,
                                            style: TextStyle(
                                              color: AppTheme.darkTextPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeago.format(post.createdAt),
                                            style: TextStyle(
                                              color: AppTheme.darkTextSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
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
                                          color: _getCategoryColor(post.category).withValues(alpha: 0.2),
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
                                          _buildStatBadge(Icons.visibility, post.views, Colors.blue),
                                          const SizedBox(width: 8),
                                          _buildStatBadge(Icons.thumb_up, post.upvotes, Colors.green),
                                        ],
                                      ),
                                    ),
                                    // Status
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: post.isApproved
                                              ? Colors.green.withValues(alpha: 0.2)
                                              : post.isRejected
                                                  ? Colors.red.withValues(alpha: 0.2)
                                                  : Colors.orange.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          post.isApproved
                                              ? '✅ Approved'
                                              : post.isRejected
                                                  ? '❌ Rejected'
                                                  : '⏳ Pending',
                                          style: TextStyle(
                                            color: post.isApproved
                                                ? Colors.green
                                                : post.isRejected
                                                    ? Colors.red
                                                    : Colors.orange,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    // Actions
                                    SizedBox(
                                      width: 200,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_red_eye, size: 18),
                                            onPressed: () => _viewPost(post),
                                            tooltip: 'View Details',
                                            color: AppTheme.darkTextSecondary,
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                              size: 18,
                                            ),
                                            onPressed: () => _togglePin(post),
                                            tooltip: post.isPinned ? 'Unpin' : 'Pin',
                                            color: post.isPinned ? AppTheme.warningColor : AppTheme.darkTextSecondary,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            onPressed: () => _deletePost(post),
                                            tooltip: 'Delete Post',
                                          ),
                                          // Approval Actions
                                          if (!post.isApproved && !post.isRejected) ...[
                                            IconButton(
                                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                              onPressed: () => _approvePost(post),
                                              tooltip: 'Approve Post',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                              onPressed: () => _rejectPost(post),
                                              tooltip: 'Reject Post',
                                            ),
                                          ],
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

  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (label == 'All Posts') {
            _filterType = 'all';
          } else if (label == 'Pending Approval') {
            _filterType = 'pending';
          } else if (label == 'Approved') {
            _filterType = 'approved';
          } else if (label == 'Rejected') {
            _filterType = 'rejected';
          }
          _currentPage = 0;
        });
      },
      backgroundColor: AppTheme.darkSurfaceVariant,
      selectedColor: AppTheme.darkPrimary.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.darkTextPrimary : AppTheme.darkTextSecondary,
      ),
    );
  }

  // ⭐ FIXED: Simple query - no compound index needed
  Stream<List<PostModel>> _getPostsStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      var posts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
      
      // Filter in code instead of Firestore query
      if (_filterType == 'pending') {
        posts = posts.where((post) => !post.isApproved && !post.isRejected).toList();
      } else if (_filterType == 'approved') {
        posts = posts.where((post) => post.isApproved).toList();
      } else if (_filterType == 'rejected') {
        posts = posts.where((post) => post.isRejected).toList();
      }
      
      return posts;
    });
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

  // ⭐ UPDATED: Enhanced view post dialog with full content
  void _viewPost(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.darkDivider),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceVariant,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.darkDivider),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.article,
                        color: AppTheme.darkPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Post Preview',
                            style: TextStyle(
                              color: AppTheme.darkTextPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Posted by ${post.authorName} • ${timeago.format(post.createdAt)}',
                            style: TextStyle(
                              color: AppTheme.darkTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.darkTextSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content (Scrollable)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        post.title,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metadata Row
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildMetadataChip(
                            Icons.category,
                            post.category,
                            _getCategoryColor(post.category),
                          ),
                          _buildMetadataChip(
                            Icons.visibility,
                            '${post.views} views',
                            Colors.blue,
                          ),
                          _buildMetadataChip(
                            Icons.thumb_up,
                            '${post.upvotes} upvotes',
                            Colors.green,
                          ),
                          _buildMetadataChip(
                            Icons.comment,
                            '${post.commentCount} comments',
                            Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      if (post.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: post.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.darkPrimary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.darkPrimary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  color: AppTheme.darkPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Divider
                      Divider(color: AppTheme.darkDivider),
                      const SizedBox(height: 24),

                      // Post Content (HTML with images)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: HtmlWidget(
                          post.content,
                          textStyle: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 16,
                            height: 1.6,
                          ),
                          customStylesBuilder: (element) {
                            // Style images
                            if (element.localName == 'img') {
                              return {
                                'border-radius': '8px',
                                'margin': '16px 0',
                                'max-width': '100%',
                                'height': 'auto',
                                'display': 'block',
                              };
                            }
                            // Style code blocks
                            if (element.localName == 'pre' || element.localName == 'code') {
                              return {
                                'background-color': AppTheme.darkSurfaceVariant.value.toRadixString(16),
                                'padding': '12px',
                                'border-radius': '8px',
                                'overflow-x': 'auto',
                                'font-family': 'monospace',
                              };
                            }
                            // Style links
                            if (element.localName == 'a') {
                              return {
                                'color': AppTheme.darkPrimary.value.toRadixString(16),
                                'text-decoration': 'underline',
                              };
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Status Information
                      if (post.isApproved || post.isRejected) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: post.isApproved
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: post.isApproved ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    post.isApproved ? Icons.check_circle : Icons.cancel,
                                    color: post.isApproved ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    post.isApproved ? 'Approved' : 'Rejected',
                                    style: TextStyle(
                                      color: post.isApproved ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              if (post.adminFeedback != null || post.rejectionReason != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  post.isApproved
                                      ? post.adminFeedback ?? ''
                                      : post.rejectionReason ?? '',
                                  style: TextStyle(
                                    color: AppTheme.darkTextSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              if (post.approverName != null || post.rejecterName != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'By ${post.isApproved ? post.approverName : post.rejecterName} • ${timeago.format(post.isApproved ? post.approvedAt! : post.rejectedAt!)}',
                                  style: TextStyle(
                                    color: AppTheme.darkTextSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceVariant,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(color: AppTheme.darkDivider),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!post.isApproved && !post.isRejected) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _approvePost(post);
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _rejectPost(post);
                        },
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for metadata chips
  Widget _buildMetadataChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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

  Future<void> _approvePost(PostModel post) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final adminData = await authService.getCurrentUserData();
    
    try {
      await _approvalService.approvePost(
        postId: post.id,
        adminId: adminData!.uid,
        adminName: adminData.displayName,
        feedback: 'Post approved',
      );
      
      Fluttertoast.showToast(
        msg: '✅ Post approved successfully',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to approve post: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _rejectPost(PostModel post) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final adminData = await authService.getCurrentUserData();
    
    final TextEditingController reasonController = TextEditingController();
    
    // Show rejection reason dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Reject Post'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      try {
        await _approvalService.rejectPost(
          postId: post.id,
          adminId: adminData!.uid,
          adminName: adminData.displayName,
          reason: reason,
        );
        
        Fluttertoast.showToast(
          msg: '❌ Post rejected',
          backgroundColor: AppTheme.errorColor,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: '❌ Failed to reject post: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  // Add AI categorization in the approval dialog
  Future<void> _showApprovalDialog(PostModel post) async {
    final aiService = AiSummarizerService();
    final suggestedTags = await aiService.generateTopicSuggestions(
      post.title,
      post.content,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('AI Suggested Tags:'),
            Wrap(
              spacing: 8,
              children: suggestedTags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
            // ...existing approval UI...
          ],
        ),
        actions: [
          // ...existing actions...
        ],
      ),
    );
  }
}