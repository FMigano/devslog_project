import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/comment_model.dart';
import '../../../shared/models/reply_model.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/comment_reply_service.dart';
import '../../../shared/widgets/loading_widget.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  final CommentReplyService _replyService = CommentReplyService();
  final Map<String, TextEditingController> _replyControllers = {};
  bool _isCommenting = false;
  bool _isBookmarked = false;
  bool _isVoting = false;
  String? _replyingToCommentId; // Which comment is being replied to
  final Map<String, bool> _expandedReplies = {}; // Which comment's replies are visible

  @override
  void initState() {
    super.initState();
    _checkBookmark();
    _incrementViewCount();
    _debugCheckComments(); // Add this
  }

  // Add this debug method
  Future<void> _debugCheckComments() async {
    print('🔍 Checking comments location for post: ${widget.postId}');

    // Check subcollection
    final subCollectionDocs = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .get();
    print('📁 Subcollection comments: ${subCollectionDocs.docs.length}');

    // Check root collection
    final rootDocs = await FirebaseFirestore.instance
        .collection('comments')
        .where('postId', isEqualTo: widget.postId)
        .get();
    print('📁 Root collection comments: ${rootDocs.docs.length}');

    if (rootDocs.docs.isNotEmpty) {
      print('⚠️ Comments are in ROOT collection, not subcollection!');
      for (var doc in rootDocs.docs) {
        print('Comment: ${doc.data()}');
      }
    }
  }

  Future<void> _checkBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      final isBookmarked = await FirestoreService().isBookmarked(widget.postId, userId);
      if (mounted) {
        setState(() => _isBookmarked = isBookmarked);
      }
    }
  }

  Future<void> _incrementViewCount() async {
    await FirestoreService().incrementPostView(widget.postId);
  }

  Future<void> _toggleBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    
    if (userId == null) {
      Fluttertoast.showToast(
        msg: 'Please login to bookmark',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    try {
      if (_isBookmarked) {
        await FirestoreService().removeBookmark(widget.postId, userId);
        if (mounted) {
          setState(() => _isBookmarked = false);
          Fluttertoast.showToast(
            msg: '✅ Bookmark removed',
            backgroundColor: AppTheme.successColor,
          );
        }
      } else {
        await FirestoreService().addBookmark(widget.postId, userId);
        if (mounted) {
          setState(() => _isBookmarked = true);
          Fluttertoast.showToast(
            msg: '✅ Post bookmarked',
            backgroundColor: AppTheme.successColor,
          );
        }
      }
    } catch (e) {
      print('❌ Error toggling bookmark: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to toggle bookmark: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getReplyController(String commentId) {
    if (!_replyControllers.containsKey(commentId)) {
      _replyControllers[commentId] = TextEditingController();
    }
    return _replyControllers[commentId]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: Text('Post Details', style: TextStyle(color: AppTheme.darkTextPrimary)),
        iconTheme: IconThemeData(color: AppTheme.darkTextPrimary),
        actions: [
          // Show delete button only for post author
          StreamBuilder<PostModel?>(
            stream: FirestoreService().getPostStream(widget.postId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              
              final post = snapshot.data!;
              final authService = Provider.of<AuthService>(context, listen: false);
              final currentUserId = authService.currentUser?.uid;
              
              // Only show delete button if current user is the post author
              if (currentUserId == post.authorId) {
                return IconButton(
                  icon: Icon(Icons.delete, color: AppTheme.errorColor),
                  onPressed: () => _showDeleteConfirmation(post),
                  tooltip: 'Delete Post',
                );
              }
              
              // For other users, show nothing
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<PostModel?>(
        stream: FirestoreService().getPostStream(widget.postId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingWidget();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                'Post not found',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
            );
          }

          final post = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostContent(post),
                Divider(color: AppTheme.darkDivider, height: 1),
                _buildCommentsSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.darkDivider),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorColor),
            const SizedBox(width: 12),
            Text(
              'Delete Post?',
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${post.title}"? This action cannot be undone.',
          style: TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deletePost(post.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    try {
      await FirestoreService().deletePost(postId);
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: '✅ Post deleted successfully',
          backgroundColor: AppTheme.successColor,
        );
        
        // Navigate back to home
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error deleting post: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to delete post: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Widget _buildPostContent(PostModel post) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid;

    return Container(
      color: AppTheme.darkSurface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostHeader(post),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.darkPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.darkPrimary.withOpacity(0.3)),
            ),
            child: Text(
              post.category,
              style: TextStyle(
                color: AppTheme.darkPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            post.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: HtmlWidget(
              post.content,
              textStyle: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<bool?>(
            stream: FirestoreService().getUserVoteStream(widget.postId, userId ?? ''),
            builder: (context, voteSnapshot) {
              return _buildPostActions(post, voteSnapshot.data);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader(PostModel post) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.darkPrimary,
          backgroundImage: post.authorPhotoURL != null
              ? NetworkImage(post.authorPhotoURL!)
              : null,
          child: post.authorPhotoURL == null
              ? Text(
                  post.authorName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkTextPrimary,
                ),
              ),
              Text(
                timeago.format(post.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Add this method to handle voting
  Future<void> _handleVote(bool isUpvote) async {
    if (_isVoting) return;
    
    setState(() => _isVoting = true);
    
    try {
      await _votePost(isUpvote);
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  Future<void> _votePost(bool isUpvote) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        Fluttertoast.showToast(
          msg: 'Please login to vote',
          backgroundColor: AppTheme.errorColor,
        );
        return;
      }

      await FirestoreService().votePost(widget.postId, userId, isUpvote);
    } catch (e) {
      print('❌ Error voting: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to vote: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  // Fix the _buildVoteButton method - change signature to positional parameters
  Widget _buildVoteButton(bool isUpvote, int count, bool? userVote) {
    final isActive = userVote != null && userVote == isUpvote;
    final color = isUpvote ? Colors.green : Colors.red;
    
    return InkWell(
      onTap: _isVoting ? null : () => _handleVote(isUpvote),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : AppTheme.darkDivider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUpvote ? Icons.arrow_upward : Icons.arrow_downward,
              color: isActive ? color : AppTheme.darkTextSecondary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                color: isActive ? color : AppTheme.darkTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the _buildPostActions to call with correct positional arguments
  Widget _buildPostActions(PostModel post, bool? userVote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(
          top: BorderSide(color: AppTheme.darkDivider),
          bottom: BorderSide(color: AppTheme.darkDivider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Upvote button - positional arguments
          _buildVoteButton(true, post.upvotes, userVote),
          
          // Downvote button - positional arguments
          _buildVoteButton(false, post.downvotes, userVote),
          
          // Comment count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkDivider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.comment_outlined,
                  color: AppTheme.darkTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${post.commentCount}',
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Bookmark button
          InkWell(
            onTap: _toggleBookmark,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isBookmarked 
                    ? AppTheme.darkPrimary.withValues(alpha: 0.2) 
                    : AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isBookmarked ? AppTheme.darkPrimary : AppTheme.darkDivider,
                ),
              ),
              child: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? AppTheme.darkPrimary : AppTheme.darkTextSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Remove the unused _buildPostCard method if it exists
  Widget _buildCommentsSection() {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    return Container(
      color: AppTheme.darkBackground,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
          ),
          const SizedBox(height: 16),
          if (currentUser != null) _buildCommentInput(currentUser),
          const SizedBox(height: 20),
          StreamBuilder<List<CommentModel>>(
            stream: FirestoreService().getComments(widget.postId),
            builder: (context, snapshot) {
              // Add debug logging
              print('Comments snapshot state: ${snapshot.connectionState}');
              print('Comments snapshot hasData: ${snapshot.hasData}');
              print('Comments data: ${snapshot.data}');
              print('Comments error: ${snapshot.error}');

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Error loading comments: ${snapshot.error}',
                      style: TextStyle(color: AppTheme.errorColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: AppTheme.darkTextSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final comments = snapshot.data!;
              print('Number of comments: ${comments.length}');
              
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  print('Building comment $index: ${comments[index].content}');
                  return _buildCommentCard(comments[index], currentUser);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(dynamic currentUser) {
    return Card(
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.darkDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: TextStyle(color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
                  border: InputBorder.none,
                ),
                maxLines: null,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _commentController.text.isEmpty
                    ? AppTheme.darkTextSecondary
                    : AppTheme.darkPrimary,
              ),
              onPressed: _isCommenting ? null : _submitComment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(CommentModel comment, dynamic currentUser) {
    final isAuthor = currentUser?.uid == comment.authorId;
    final isReplying = _replyingToCommentId == comment.id;
    final isExpanded = _expandedReplies[comment.id] ?? false;

    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comment Header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.darkPrimary,
                  child: Text(
                    comment.authorName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: TextStyle(
                          color: AppTheme.darkTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        timeago.format(comment.createdAt),
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAuthor)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                    onPressed: () => _deleteComment(comment.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Comment Content
            Text(
              comment.content,
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
            const SizedBox(height: 8),
            
            // Action Buttons with REAL-TIME reply count
            Row(
              children: [
                // Reply Button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _replyingToCommentId = isReplying ? null : comment.id;
                    });
                  },
                  icon: Icon(
                    Icons.reply,
                    size: 16,
                    color: AppTheme.darkPrimary,
                  ),
                  label: Text(
                    'Reply',
                    style: TextStyle(color: AppTheme.darkPrimary),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Show Replies Button with REAL-TIME count
                StreamBuilder<List<ReplyModel>>(
                  stream: _replyService.getRepliesStream(widget.postId, comment.id),
                  builder: (context, snapshot) {
                    final replyCount = snapshot.data?.length ?? 0;
                    
                    if (replyCount == 0) return const SizedBox();
                    
                    return TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _expandedReplies[comment.id] = !isExpanded;
                        });
                      },
                      icon: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: AppTheme.darkTextSecondary,
                      ),
                      label: Text(
                        '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                        style: TextStyle(color: AppTheme.darkTextSecondary),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                      ),
                    );
                  },
                ),
              ],
            ),
            
            // Reply Input
            if (isReplying) ...[
              const SizedBox(height: 12),
              _buildReplyInput(comment.id, currentUser),
            ],
            
            // Replies List with REAL-TIME updates
            if (isExpanded) ...[
              const SizedBox(height: 12),
              _buildRepliesList(comment.id, currentUser),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput(String commentId, dynamic currentUser) {
    final controller = _getReplyController(commentId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            style: TextStyle(color: AppTheme.darkTextPrimary),
            decoration: InputDecoration(
              hintText: 'Write a reply...',
              hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
              border: InputBorder.none,
              isDense: true,
            ),
            maxLines: 3,
            minLines: 2,
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _replyingToCommentId = null;
                    controller.clear();
                  });
                },
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.darkTextSecondary),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return ElevatedButton.icon(
                    onPressed: value.text.trim().isEmpty 
                        ? null 
                        : () => _submitReply(commentId, controller),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Reply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.darkPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.darkSurfaceVariant,
                      disabledForegroundColor: AppTheme.darkTextSecondary,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRepliesList(String commentId, dynamic currentUser) {
    return StreamBuilder<List<ReplyModel>>(
      stream: _replyService.getRepliesStream(widget.postId, commentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: AppTheme.darkPrimary,
                strokeWidth: 2,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Error loading replies: ${snapshot.error}',
              style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No replies yet',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          );
        }

        final replies = snapshot.data!;
        
        return Container(
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppTheme.darkDivider,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: replies.map((reply) {
              final isAuthor = currentUser?.uid == reply.authorId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.darkPrimary,
                          child: Text(
                            reply.authorName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reply.authorName,
                                style: TextStyle(
                                  color: AppTheme.darkTextPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                timeago.format(reply.createdAt),
                                style: TextStyle(
                                  color: AppTheme.darkTextSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isAuthor || currentUser?.isAdmin == true)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 16),
                            color: Colors.red,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteReply(commentId, reply.id, reply.authorId),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reply.content,
                      style: TextStyle(
                        color: AppTheme.darkTextPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _submitReply(String commentId, TextEditingController controller) async {
    if (controller.text.trim().isEmpty) return;

    final replyContent = controller.text.trim();

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null) {
        throw Exception('User not found');
      }

      final reply = ReplyModel(
        id: '',
        postId: widget.postId,
        commentId: commentId,
        authorId: user.uid,
        authorName: user.displayName,
        authorEmail: user.email,
        content: replyContent,
        createdAt: DateTime.now(),
      );

      // Send to Firestore
      await _replyService.addReply(
        postId: widget.postId,
        commentId: commentId,
        reply: reply,
      );

      // Clear and hide reply box AFTER successful send
      if (mounted) {
        controller.clear();
        setState(() {
          _replyingToCommentId = null;
          _expandedReplies[commentId] = true; // Auto-expand to show new reply
        });

        Fluttertoast.showToast(
          msg: '✅ Reply added',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      print('❌ Error adding reply: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: '❌ Failed to add reply: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }

  Future<void> _deleteReply(String commentId, String replyId, String authorId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text('Delete Reply', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Text(
          'Are you sure you want to delete this reply?',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _replyService.deleteReply(
          postId: widget.postId,
          commentId: commentId,
          replyId: replyId,
          authorId: authorId,
        );

        if (mounted) {
          Fluttertoast.showToast(
            msg: '✅ Reply deleted',
            backgroundColor: AppTheme.successColor,
          );
        }
      } catch (e) {
        print('❌ Error deleting reply: $e');
        if (mounted) {
          Fluttertoast.showToast(
            msg: '❌ Failed to delete reply: $e',
            backgroundColor: AppTheme.errorColor,
          );
        }
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isCommenting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null) {
        throw Exception('User not found');
      }

      final comment = CommentModel(
        id: '',
        postId: widget.postId,
        authorId: user.uid,
        authorName: user.displayName,
        authorEmail: user.email,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await FirestoreService().addComment(comment);

      _commentController.clear();

      Fluttertoast.showToast(
        msg: '✅ Comment added',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to add comment: $e',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isCommenting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text('Delete Comment', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = authService.currentUser;

        await FirestoreService().deleteComment(commentId, widget.postId, user!.uid);

        Fluttertoast.showToast(
          msg: '✅ Comment deleted',
          backgroundColor: AppTheme.successColor,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: '❌ Failed to delete comment: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }
}
