import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/comment_model.dart';
import '../../../shared/models/reply_model.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/comment_reply_service.dart';
import '../../../shared/services/ai_summarizer_service.dart';
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
  final AiSummarizerService _aiService = AiSummarizerService();
  List<String> _commentSuggestions = [];
  bool _showCommentSuggestions = false;
  bool _loadingCommentSuggestions = false;
  final Map<String, bool> _commentLoadingStates = {};
  final Map<String, bool> _showReplyStates = {};
  final Map<String, List<String>> _aiSuggestionsCache = {};
  bool _aiAvailable = true; // Track if AI features are available

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

  Future<void> _generateCommentSuggestions(PostModel post) async {
    setState(() => _loadingCommentSuggestions = true);
    
    try {
      final suggestions = await _aiService.generateCommentSuggestions(
        post.title,
        post.content,
      );
      
      if (mounted && suggestions.isNotEmpty) {
        setState(() {
          _commentSuggestions = suggestions;
          _showCommentSuggestions = true;
        });
        
        Fluttertoast.showToast(
          msg: '✨ AI generated comment ideas!',
          backgroundColor: Colors.purple,
        );
      }
    } catch (e) {
      print('Error generating comment suggestions: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingCommentSuggestions = false);
      }
    }
  }

  Widget _buildCommentSuggestionsButton(PostModel post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: _loadingCommentSuggestions ? null : () => _generateCommentSuggestions(post),
        icon: _loadingCommentSuggestions
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome, size: 18),
        label: Text(_loadingCommentSuggestions ? 'Generating...' : 'Get AI Comment Ideas'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCommentSuggestionsCard() {
    if (!_showCommentSuggestions || _commentSuggestions.isEmpty) {
      return const SizedBox();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.purple.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Comment Suggestions',
                style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _showCommentSuggestions = false),
                color: AppTheme.darkTextSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._commentSuggestions.asMap().entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _commentController.text = entry.value;
                  setState(() => _showCommentSuggestions = false);
                  Fluttertoast.showToast(
                    msg: '📝 Comment template added',
                    backgroundColor: AppTheme.successColor,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkDivider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.purple),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
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
          if (currentUser != null) ...[
            StreamBuilder<PostModel?>(
              stream: FirestoreService().getPostStream(widget.postId),
              builder: (context, postSnapshot) {
                if (postSnapshot.hasData) {
                  return Column(
                    children: [
                      _buildCommentSuggestionsButton(postSnapshot.data!),
                      _buildCommentSuggestionsCard(),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
            _buildCommentInput(currentUser),
          ],
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
                      style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
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

  Widget _buildCommentCard(CommentModel comment, User? currentUser) {
    // Initialize state ONCE per comment
    _commentLoadingStates[comment.id] ??= false;
    _showReplyStates[comment.id] ??= false;
    _aiSuggestionsCache[comment.id] ??= [];
    _replyControllers[comment.id] ??= TextEditingController();

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setCommentState) {
        final isLoadingAI = _commentLoadingStates[comment.id] ?? false;
        final showReply = _showReplyStates[comment.id] ?? false;
        final aiSuggestions = _aiSuggestionsCache[comment.id] ?? [];
        final replyController = _replyControllers[comment.id]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.darkDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Comment header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.darkPrimary,
                    child: Text(
                      comment.authorName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
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
                            fontWeight: FontWeight.bold,
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
                  if (currentUser?.uid == comment.authorId)
                    IconButton(
                      icon: Icon(Icons.delete, color: AppTheme.errorColor),
                      onPressed: () => _deleteComment(comment.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Comment content
              Text(
                comment.content,
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              
              const SizedBox(height: 12),
              
              // Action buttons
              Row(
                children: [
                  // Reply button
                  TextButton.icon(
                    onPressed: () {
                      // ✅ Update ONLY this comment's state
                      setCommentState(() {
                        _showReplyStates[comment.id] = !showReply;
                      });
                    },
                    icon: Icon(
                      showReply ? Icons.expand_less : Icons.reply,
                      size: 18,
                    ),
                    label: Text(showReply ? 'Hide Reply' : 'Reply'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.darkPrimary,
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // AI suggestions button
                  if (_aiAvailable && showReply)
                    TextButton.icon(
                      onPressed: isLoadingAI 
                          ? null 
                          : () => _getAIReplySuggestionsLocal(
                              comment.id, 
                              comment.content, 
                              setCommentState,
                            ),
                      icon: isLoadingAI
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(AppTheme.darkPrimary),
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(isLoadingAI ? 'Thinking...' : 'AI Ideas'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.purple,
                      ),
                    ),
                ],
              ),
              
              // Reply input
              if (showReply) ...[
                const SizedBox(height: 12),
                
                // AI suggestions chips (NO animation, instant show)
                if (aiSuggestions.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: aiSuggestions.map((suggestion) {
                      return ActionChip(
                        label: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: AppTheme.darkSurface,
                        side: BorderSide(color: AppTheme.darkPrimary),
                        onPressed: () {
                          replyController.text = suggestion;
                        },
                      );
                    }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              
              // Reply text field
              TextField(
                controller: replyController,
                style: TextStyle(color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Write a reply...',
                  hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
                  filled: true,
                  fillColor: AppTheme.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkPrimary),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send, color: AppTheme.darkPrimary),
                    onPressed: () => _submitReply(comment.id, replyController),
                  ),
                ),
                maxLines: 3,
              ),
            ],
            
              // Replies section
              StreamBuilder<List<ReplyModel>>(
                stream: _replyService.getRepliesStream(widget.postId, comment.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
  
                  return Padding(
                    padding: const EdgeInsets.only(left: 40, top: 12),
                    child: Column(
                      children: snapshot.data!.map((reply) {
                        return _buildReplyCard(reply, currentUser);
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Updated method with local state setter
  Future<void> _getAIReplySuggestionsLocal(
    String commentId, 
    String commentText,
    StateSetter setCommentState,
  ) async {
    // Update loading state LOCALLY
    setCommentState(() {
      _commentLoadingStates[commentId] = true;
    });

    try {
      final suggestions = await _aiService.generateCommentSuggestions(
        'Reply to: $commentText',
        commentText,
      );
      
      // Update suggestions LOCALLY (no full rebuild)
      setCommentState(() {
        _aiSuggestionsCache[commentId] = suggestions;
        _commentLoadingStates[commentId] = false;
      });
      
      if (suggestions.isEmpty) {
        _showToast('No suggestions available', Colors.orange);
      }
    } catch (e) {
      setCommentState(() {
        _commentLoadingStates[commentId] = false;
      });
      _showToast('AI error: $e', AppTheme.errorColor);
    }
  }

  // ✅ Submit reply
  Future<void> _submitReply(String commentId, TextEditingController controller) async {
    if (controller.text.trim().isEmpty) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();
      
      if (user == null) return;

      final reply = ReplyModel(
        id: '',
        commentId: commentId,
        postId: widget.postId,
        content: controller.text.trim(),
        authorId: user.uid,
        authorName: user.displayName,
        authorEmail: user.email,
        createdAt: DateTime.now(),
      );

      await _replyService.addReply(
        postId: widget.postId,
        commentId: commentId,
        reply: reply,
      );
      
      // Clear controller and hide reply section
      controller.clear();
      setState(() {
        _showReplyStates[commentId] = false;
        _aiSuggestionsCache[commentId] = []; // Clear suggestions
      });
      
      _showToast('Reply posted!', AppTheme.successColor);
    } catch (e) {
      _showToast('Error posting reply', AppTheme.errorColor);
    }
  }

  Widget _buildReplyCard(ReplyModel reply, User? currentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkDivider),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
              if (currentUser?.uid == reply.authorId)
                IconButton(
                  icon: Icon(Icons.delete, color: AppTheme.errorColor, size: 18),
                  onPressed: () => _deleteReply(reply.id, reply.commentId),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reply.content,
            style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReply(String replyId, String commentId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      
      if (userId == null) {
        _showToast('User not authenticated', AppTheme.errorColor);
        return;
      }
      
      await _replyService.deleteReply(
        postId: widget.postId,
        commentId: commentId,
        replyId: replyId,
        authorId: userId,
      );
      _showToast('Reply deleted', AppTheme.successColor);
    } catch (e) {
      _showToast('Error deleting reply', AppTheme.errorColor);
    }
  }

  void _showToast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
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
