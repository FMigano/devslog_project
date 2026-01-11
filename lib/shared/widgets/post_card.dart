import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../models/post_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _checkBookmark();
  }

  Future<void> _checkBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId != null) {
      final isBookmarked = await FirestoreService().isBookmarked(widget.post.id, userId);
      setState(() => _isBookmarked = isBookmarked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildContent(),
              const SizedBox(height: 16),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.post.authorName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                timeago.format(widget.post.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Chip(
          label: Text(widget.post.category),
          backgroundColor: AppTheme.primaryColor.withAlpha(26),
          labelStyle: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.post.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _stripHtmlTags(widget.post.content),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        if (widget.post.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: widget.post.tags.take(3).map((tag) {
              return Chip(
                label: Text('#$tag'),
                visualDensity: VisualDensity.compact,
                backgroundColor: AppTheme.backgroundColor,
                labelStyle: const TextStyle(fontSize: 12),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        _buildVoteButton(true, widget.post.upvotes),
        const SizedBox(width: 16),
        _buildVoteButton(false, widget.post.downvotes),
        const SizedBox(width: 24),
        Icon(Icons.comment_outlined, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text('${widget.post.commentCount}', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 24),
        Icon(Icons.visibility_outlined, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text('${widget.post.viewCount}', style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        IconButton(
          icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          color: _isBookmarked ? AppTheme.primaryColor : null,
          onPressed: _toggleBookmark,
        ),
      ],
    );
  }

  Widget _buildVoteButton(bool isUpvote, int count) {
    return Row(
      children: [
        Icon(
          isUpvote ? Icons.arrow_upward : Icons.arrow_downward,
          size: 20,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 4),
        Text('$count', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Future<void> _toggleBookmark() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    
    if (userId == null) return;

    await FirestoreService().toggleBookmark(widget.post.id, userId);
    setState(() => _isBookmarked = !_isBookmarked);
    
    Fluttertoast.showToast(
      msg: _isBookmarked ? 'Post bookmarked' : 'Bookmark removed',
      backgroundColor: AppTheme.successColor,
    );
  }

  String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
