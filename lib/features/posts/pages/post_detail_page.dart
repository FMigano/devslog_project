import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/comment_model.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/widgets/loading_widget.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  bool _isCommenting = false;
  bool _isBookmarked = false;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
    _incrementViewCount();
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
          IconButton(
            icon: Icon(Icons.share, color: AppTheme.darkTextSecondary),
            onPressed: () {},
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

  Widget _buildPostActions(PostModel post, bool? userVote) {
    return Row(
      children: [
        _buildVoteButton(true, post.upvotes, userVote),
        const SizedBox(width: 16),
        _buildVoteButton(false, post.downvotes, userVote),
        const SizedBox(width: 24),
        Icon(Icons.visibility_outlined, size: 20, color: AppTheme.darkTextSecondary),
        const SizedBox(width: 4),
        Text('${post.viewCount}', style: TextStyle(color: AppTheme.darkTextSecondary)),
        const Spacer(),
        IconButton(
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: _isBookmarked ? AppTheme.darkPrimary : AppTheme.darkTextSecondary,
          ),
          onPressed: _toggleBookmark,
        ),
      ],
    );
  }

  Widget _buildVoteButton(bool isUpvote, int count, bool? userVote) {
    final isVoted = userVote != null && userVote == isUpvote;
    final color = isUpvote 
        ? (isVoted ? AppTheme.successColor : AppTheme.darkTextSecondary)
        : (isVoted ? AppTheme.errorColor : AppTheme.darkTextSecondary);

    return InkWell(
      onTap: _isVoting ? null : () => _votePost(isUpvote),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isVoted 
              ? color.withOpacity(0.2)
              : AppTheme.darkSurfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isVoted ? color : AppTheme.darkDivider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isUpvote ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _votePost(bool isUpvote) async {
    if (_isVoting) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    
    if (userId == null) {
      Fluttertoast.showToast(
        msg: 'Please sign in to vote',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isVoting = true);

    try {
      await FirestoreService().votePost(widget.postId, userId, isUpvote);
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Vote recorded',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Failed to vote: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    
    if (userId == null) {
      Fluttertoast.showToast(
        msg: 'Please sign in to bookmark',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    try {
      await FirestoreService().toggleBookmark(widget.postId, userId);
      setState(() => _isBookmarked = !_isBookmarked);
      
      Fluttertoast.showToast(
        msg: _isBookmarked ? 'Post bookmarked' : 'Bookmark removed',
        backgroundColor: AppTheme.successColor,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Failed to bookmark: $e',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
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

    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.darkDivider),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.darkPrimary,
          backgroundImage: comment.authorPhotoURL != null
              ? NetworkImage(comment.authorPhotoURL!)
              : null,
          child: comment.authorPhotoURL == null
              ? Text(
                  comment.authorName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                )
              : null,
        ),
        title: Row(
          children: [
            Text(
              comment.authorName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeago.format(comment.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            comment.content,
            style: TextStyle(color: AppTheme.darkTextPrimary),
          ),
        ),
        trailing: isAuthor
            ? IconButton(
                icon: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                onPressed: () => _deleteComment(comment.id, comment.authorId),
              )
            : null,
      ),
    );
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter a comment',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    setState(() => _isCommenting = true);
    print('=== ADD COMMENT STARTED ===');

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUserData();

      if (user == null) {
        throw Exception('User not found');
      }

      print('Adding comment by: ${user.displayName}');
      print('Comment text: ${_commentController.text.trim()}');
      print('Post ID: ${widget.postId}');

      final comment = CommentModel(
        id: '',
        postId: widget.postId,
        authorId: user.uid,
        authorName: user.displayName,
        authorPhotoURL: user.photoURL,
        content: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      print('Saving comment to Firestore...');
      await FirestoreService().addComment(comment);
      print('Comment saved successfully');

      _commentController.clear();
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Comment added',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e, stackTrace) {
      print('ERROR adding comment: $e');
      print('STACK: $stackTrace');
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Failed to add comment: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCommenting = false);
      }
      print('=== ADD COMMENT ENDED ===');
    }
  }

  Future<void> _deleteComment(String commentId, String authorId) async {
    try {
      await FirestoreService().deleteComment(commentId, widget.postId, authorId);
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Comment deleted',
          backgroundColor: AppTheme.successColor,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: 'Failed to delete comment: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }
}
