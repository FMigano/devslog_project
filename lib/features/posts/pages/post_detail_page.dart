import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/comment_model.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../shared/widgets/share_button.dart';
import '../../../shared/services/notification_service.dart';

class PostDetailPage extends StatefulWidget {
  final PostModel post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _commentController = TextEditingController();
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _incrementView();
    _checkBookmark();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _incrementView() async {
    await _firestoreService.incrementPostView(widget.post.id);
  }

  Future<void> _checkBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      final isBookmarked = await _firestoreService.isBookmarked(widget.post.id, userId);
      setState(() => _isBookmarked = isBookmarked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        actions: [
          IconButton(
            icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleBookmark,
          ),
          ShareButton(
            title: widget.post.title,
            text: widget.post.content,
            url: 'https://devslog.app/post/${widget.post.id}',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(child: ListTile(leading: Icon(Icons.flag), title: Text('Report'))),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildPostHeader(),
              const SizedBox(height: 24),
              _buildPostContent(),
              const SizedBox(height: 24),
              _buildVotingSection(),
              const Divider(height: 48),
              _buildCommentsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: Text(widget.post.category),
          backgroundColor: AppTheme.primaryColor.withAlpha(26),
        ),
        const SizedBox(height: 16),
        Text(widget.post.title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.post.authorPhotoURL != null
                  ? NetworkImage(widget.post.authorPhotoURL!)
                  : null,
              child: widget.post.authorPhotoURL == null
                  ? Text(widget.post.authorName[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.post.authorName, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  timeago.format(widget.post.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.post.tags.map((tag) {
              return Chip(
                label: Text('#$tag'),
                backgroundColor: AppTheme.backgroundColor,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPostContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: HtmlWidget(widget.post.content),
      ),
    );
  }

  Widget _buildVotingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildVoteButton(true, widget.post.upvotes),
            _buildVoteButton(false, widget.post.downvotes),
            Row(
              children: [
                const Icon(Icons.comment_outlined),
                const SizedBox(width: 8),
                Text('${widget.post.commentCount} comments'),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.visibility_outlined),
                const SizedBox(width: 8),
                Text('${widget.post.viewCount} views'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(bool isUpvote, int count) {
    return ElevatedButton.icon(
      onPressed: () => _votePost(isUpvote),
      icon: Icon(isUpvote ? Icons.arrow_upward : Icons.arrow_downward),
      label: Text('$count'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isUpvote ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comments', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _buildCommentInput(),
        const SizedBox(height: 24),
        StreamBuilder<List<CommentModel>>(
          stream: _firestoreService.getComments(widget.post.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final comments = snapshot.data ?? [];

            if (comments.isEmpty) {
              return const Center(child: Text('No comments yet. Be the first to comment!'));
            }

            return Column(
              children: comments.map((comment) => _buildCommentCard(comment)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Write a comment...',
                border: InputBorder.none,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _addComment,
                child: const Text('Post Comment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard(CommentModel comment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: comment.authorPhotoURL != null
                      ? NetworkImage(comment.authorPhotoURL!)
                      : null,
                  child: comment.authorPhotoURL == null
                      ? Text(comment.authorName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.authorName, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      timeago.format(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(comment.content),
          ],
        ),
      ),
    );
  }

  Future<void> _votePost(bool isUpvote) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    
    if (userId == null) return;

    await _firestoreService.votePost(widget.post.id, userId, isUpvote);
    
    Fluttertoast.showToast(
      msg: isUpvote ? 'Upvoted!' : 'Downvoted!',
      backgroundColor: AppTheme.successColor,
    );
  }

  Future<void> _toggleBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    
    if (userId == null) return;

    await _firestoreService.toggleBookmark(widget.post.id, userId);
    setState(() => _isBookmarked = !_isBookmarked);
    
    Fluttertoast.showToast(
      msg: _isBookmarked ? 'Bookmarked!' : 'Bookmark removed',
      backgroundColor: AppTheme.successColor,
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.getCurrentUserData();
    
    if (user == null) return;

    final comment = CommentModel(
      id: '',
      postId: widget.post.id,
      authorId: user.uid,
      authorName: user.displayName,
      authorPhotoURL: user.photoURL,
      content: _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    await _firestoreService.addComment(comment);
    _commentController.clear();
    
    // Create notification for post author
    if (widget.post.authorId != user.uid) {
      await NotificationService().createNotification(
        userId: widget.post.authorId,
        title: 'New Comment',
        message: '${user.displayName} commented on your post',
        type: 'comment',
        postId: widget.post.id,
      );
    }
    
    Fluttertoast.showToast(
      msg: 'Comment posted!',
      backgroundColor: AppTheme.successColor,
    );
  }
}
