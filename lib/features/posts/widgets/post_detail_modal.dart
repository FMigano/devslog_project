import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/comment_model.dart';
import '../../../shared/models/reply_model.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/comment_reply_service.dart';
import '../../../shared/services/ai_summarizer_service.dart';

class PostDetailModal extends StatefulWidget {
  final PostModel post;

  const PostDetailModal({super.key, required this.post});

  @override
  State<PostDetailModal> createState() => _PostDetailModalState();
}

class _PostDetailModalState extends State<PostDetailModal> {
  final TextEditingController _commentController = TextEditingController();
  final CommentReplyService _replyService = CommentReplyService();
  final Map<String, TextEditingController> _replyControllers = {};
  final AiSummarizerService _aiService = AiSummarizerService();
  
  bool _isCommenting = false;
  bool _isBookmarked = false;
  bool _isVoting = false;
  bool? _userVote;
  final Map<String, bool> _showReplyStates = {};
  final Map<String, List<String>> _aiSuggestionsCache = {};
  List<String> _commentSuggestions = [];
  bool _showCommentSuggestions = false;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
    _loadUserVote();
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (var controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      final isBookmarked = await FirestoreService().isBookmarked(widget.post.id, userId);
      if (mounted) {
        setState(() => _isBookmarked = isBookmarked);
      }
    }
  }

  Future<void> _loadUserVote() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      final vote = await FirestoreService().getUserVote(widget.post.id, userId);
      if (mounted) {
        setState(() => _userVote = vote);
      }
    }
  }

  TextEditingController _getReplyController(String commentId) {
    if (!_replyControllers.containsKey(commentId)) {
      _replyControllers[commentId] = TextEditingController();
    }
    return _replyControllers[commentId]!;
  }

  Future<void> _generateCommentSuggestions(PostModel post) async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.6,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Center(
          child: Container(
            // ✅ Added 300px to each breakpoint
            width: screenWidth > 1400 
                ? 1500  // Extra large desktop - was 1200, now 1500
                : screenWidth > 1200 
                  ? 1300  // Large desktop - was 1000, now 1300
                  : screenWidth > 900 
                    ? 1150  // Desktop - was 850, now 1150
                    : screenWidth > 600 
                      ? 1050  // Tablet - was 750, now 1050
                      : screenWidth * 0.98, // Mobile - 98% width
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
                      Text(
                        'Post Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                      ),
                      const Spacer(),
                      if (currentUser?.uid == widget.post.authorId)
                        IconButton(
                          icon: Icon(Icons.delete, color: AppTheme.errorColor),
                          onPressed: () => _showDeleteConfirmation(),
                        ),
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
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildPostContent(widget.post, currentUser),
                      const SizedBox(height: 24),
                      _buildCommentsSection(currentUser),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostContent(PostModel post, User? currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author info
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.darkPrimary,
              backgroundImage: post.authorPhotoURL != null
                  ? NetworkImage(post.authorPhotoURL!)
                  : null,
              child: post.authorPhotoURL == null
                  ? Text(post.authorName[0].toUpperCase())
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
        ),
        const SizedBox(height: 16),
        
        // Category
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.darkPrimary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
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
        const SizedBox(height: 12),
        
        // Title
        Text(
          post.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
        ),
        const SizedBox(height: 12),
        
        // Tags
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
        const SizedBox(height: 16),
        
        // Content
        HtmlWidget(
          post.content,
          textStyle: TextStyle(
            color: AppTheme.darkTextPrimary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        
        // Action buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildVoteButton(true, post.upvotes),
            _buildVoteButton(false, post.downvotes),
            Row(
              children: [
                Icon(Icons.comment_outlined, color: AppTheme.darkTextSecondary, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? AppTheme.darkPrimary : AppTheme.darkTextSecondary,
              ),
              onPressed: _toggleBookmark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoteButton(bool isUpvote, int count) {
    final isActive = _userVote != null && _userVote == isUpvote;
    final color = isUpvote ? Colors.green : Colors.red;
    
    return InkWell(
      onTap: _isVoting ? null : () => _handleVote(isUpvote),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isUpvote ? Icons.arrow_upward : Icons.arrow_downward,
              color: isActive ? color : AppTheme.darkTextSecondary,
              size: 20,
            ),
            const SizedBox(width: 4),
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

  Future<void> _handleVote(bool isUpvote) async {
    if (_isVoting) return;
    
    setState(() => _isVoting = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      
      if (userId == null) throw Exception('User not logged in');
      
      await FirestoreService().votePost(widget.post.id, userId, isUpvote);
      
      if (mounted) {
        setState(() {
          _userVote = isUpvote;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to vote',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Widget _buildCommentsSection(User? currentUser) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
        ),
        const SizedBox(height: 16),
        
        if (currentUser != null) ...[
          // AI Comment Suggestions Button
          ElevatedButton.icon(
            onPressed: () => _generateCommentSuggestions(widget.post),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Get AI Comment Ideas'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          
          // AI Suggestions Card
          if (_showCommentSuggestions && _commentSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'AI Suggestions',
                        style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: Colors.purple),
                        onPressed: () {
                          setState(() => _showCommentSuggestions = false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._commentSuggestions.map((suggestion) {
                    return InkWell(
                      onTap: () {
                        _commentController.text = suggestion;
                        setState(() => _showCommentSuggestions = false);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          suggestion,
                          style: TextStyle(color: AppTheme.darkTextPrimary),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          
          _buildCommentInput(currentUser),
          const SizedBox(height: 16),
        ],
        
        StreamBuilder<List<CommentModel>>(
          stream: FirestoreService().getComments(widget.post.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No comments yet. Be the first!',
                    style: TextStyle(color: AppTheme.darkTextSecondary),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildCommentCard(snapshot.data![index], currentUser);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentInput(User currentUser) {
    return TextField(
      controller: _commentController,
      style: TextStyle(color: AppTheme.darkTextPrimary),
      decoration: InputDecoration(
        hintText: 'Add a comment...',
        hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
        filled: true,
        fillColor: AppTheme.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.darkDivider),
        ),
        suffixIcon: IconButton(
          icon: Icon(Icons.send, color: AppTheme.darkPrimary),
          onPressed: _isCommenting ? null : _submitComment,
        ),
      ),
      maxLines: 3,
    );
  }

  Widget _buildCommentCard(CommentModel comment, User? currentUser) {
    final showReply = _showReplyStates[comment.id] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.darkPrimary,
                child: Text(comment.authorName[0].toUpperCase()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      style: TextStyle(
                        color: AppTheme.darkTextPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentUser?.uid == comment.authorId)
                IconButton(
                  icon: Icon(Icons.delete, size: 18, color: AppTheme.errorColor),
                  onPressed: () => _deleteComment(comment.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showReplyStates[comment.id] = !showReply;
                  });
                },
                icon: Icon(Icons.reply, size: 16),
                label: Text('Reply'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.darkPrimary,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          
          // Stream to display replies
          StreamBuilder<List<ReplyModel>>(
            stream: _replyService.getRepliesStream(widget.post.id, comment.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(left: 24, top: 12),
                child: Column(
                  children: snapshot.data!.map((reply) {
                    return _buildReplyCard(reply, currentUser);
                  }).toList(),
                ),
              );
            },
          ),
          
          if (showReply) _buildReplyInput(comment.id, currentUser!),
        ],
      ),
    );
  }

  Widget _buildReplyCard(ReplyModel reply, User? currentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkDivider.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.darkPrimary.withOpacity(0.7),
                child: Text(
                  reply.authorName[0].toUpperCase(),
                  style: TextStyle(fontSize: 10),
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
              if (currentUser?.uid == reply.authorId)
                IconButton(
                  icon: Icon(Icons.delete, size: 16, color: AppTheme.errorColor),
                  onPressed: () => _deleteReply(reply.id, reply.commentId),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reply.content,
            style: TextStyle(
              color: AppTheme.darkTextPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyInput(String commentId, User currentUser) {
    final controller = _getReplyController(commentId);
    
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 12),
      child: TextField(
        controller: controller,
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
          suffixIcon: IconButton(
            icon: Icon(Icons.send, color: AppTheme.darkPrimary, size: 18),
            onPressed: () => _submitReply(commentId, controller),
          ),
        ),
        maxLines: 2,
      ),
    );
  }

  Future<void> _submitReply(String commentId, TextEditingController controller) async {
    if (controller.text.trim().isEmpty) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null) throw Exception('User not found');

      final reply = ReplyModel(
        id: '',
        postId: widget.post.id,
        commentId: commentId,
        authorId: user.uid,
        authorName: user.displayName,
        authorEmail: user.email,
        content: controller.text.trim(),
        createdAt: DateTime.now(),
      );

      await _replyService.addReply(
        postId: widget.post.id,
        commentId: commentId,
        reply: reply,
      );
      controller.clear();
      setState(() => _showReplyStates[commentId] = false);

      Fluttertoast.showToast(
        msg: '✅ Reply added',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to add reply',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _deleteReply(String replyId, String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text('Delete Reply', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Text('Are you sure you want to delete this reply?', 
          style: TextStyle(color: AppTheme.darkTextPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      
      if (userId == null) throw Exception('User not found');
      
      await _replyService.deleteReply(
        postId: widget.post.id,
        commentId: commentId,
        replyId: replyId,
        authorId: userId,
      );
      
      Fluttertoast.showToast(
        msg: '✅ Reply deleted',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to delete reply: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isCommenting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null) throw Exception('User not found');

      final comment = CommentModel(
        id: '',
        postId: widget.post.id,
        authorId: user.uid,
        authorName: user.displayName,
        authorEmail: user.email,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      await FirestoreService().addComment(comment);
      _commentController.clear();
      setState(() => _showCommentSuggestions = false);

      Fluttertoast.showToast(
        msg: '✅ Comment added',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to add comment',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) setState(() => _isCommenting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text('Delete Comment', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Text('Are you sure you want to delete this comment?', 
          style: TextStyle(color: AppTheme.darkTextPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      
      if (userId == null) throw Exception('User not found');
      
      await FirestoreService().deleteComment(commentId, widget.post.id, userId);
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

  Future<void> _toggleBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    
    if (userId == null) return;

    try {
      if (_isBookmarked) {
        await FirestoreService().removeBookmark(widget.post.id, userId);
      } else {
        await FirestoreService().addBookmark(widget.post.id, userId);
      }
      
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to toggle bookmark',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text('Delete Post', style: TextStyle(color: AppTheme.darkTextPrimary)),
        content: Text('Are you sure you want to delete this post?', 
          style: TextStyle(color: AppTheme.darkTextPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _deletePost();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      await FirestoreService().deletePost(widget.post.id);
      if (mounted) {
        Navigator.pop(context); // Close modal
        Fluttertoast.showToast(
          msg: '✅ Post deleted',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ Failed to delete post',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }
}

// Helper function to show the modal
void showPostDetailModal(BuildContext context, PostModel post) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PostDetailModal(post: post),
  );
}