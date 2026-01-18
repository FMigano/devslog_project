import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/post_model.dart';
import '../../widgets/stat_card.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_post_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class OverviewSection extends StatelessWidget {
  final AdminUserService _userService = AdminUserService();
  final AdminPostService _postService = AdminPostService();

  OverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.dashboard,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '📊 Dashboard Overview',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // Stats Cards
        FutureBuilder<Map<String, dynamic>>(
          future: _loadStats(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error loading stats: ${snapshot.error}',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              );
            }

            final stats = snapshot.data!;
            return Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Users',
                    value: '${stats['totalUsers']}',
                    icon: Icons.people,
                    color: Colors.blue,
                    subtitle: '${stats['activeToday']} active today',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Total Posts',
                    value: '${stats['totalPosts']}',
                    icon: Icons.article,
                    color: Colors.green,
                    subtitle: '${stats['pinnedPosts']} pinned',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Total Comments',
                    value: '${stats['totalComments']}',
                    icon: Icons.comment,
                    color: Colors.orange,
                    subtitle: 'Across all posts',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: StatCard(
                    title: 'Total Views',
                    value: '${stats['totalViews']}',
                    icon: Icons.visibility,
                    color: Colors.purple,
                    subtitle: 'All time views',
                  ),
                ),
              ],
            );
          },
        ),
        
        const SizedBox(height: 32),
        
        // Recent Posts Section
        _buildRecentPostsSection(),
      ],
    );
  }

  Widget _buildRecentPostsSection() {
    return StreamBuilder<List<PostModel>>(
      stream: _postService.getPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.darkDivider),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.darkDivider),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 48,
                    color: AppTheme.darkTextSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final recentPosts = snapshot.data!
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final topPosts = recentPosts.take(5).toList();

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.darkDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.article,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Recent Posts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.darkDivider),
                      ),
                      child: Text(
                        'Latest 5',
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppTheme.darkDivider),
              ...topPosts.asMap().entries.map((entry) {
                final index = entry.key;
                final post = entry.value;
                final isLast = index == topPosts.length - 1;
                return _buildPostItem(post, isLast);
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostItem(PostModel post, bool isLast) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppTheme.darkDivider.withOpacity(0.5),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Post Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.darkPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.darkPrimary.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.article_outlined,
                color: AppTheme.darkPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Post Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (post.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: AppTheme.warningColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.authorName,
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeago.format(post.createdAt),
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Stats
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMetric(Icons.visibility, post.views, Colors.blue),
                const SizedBox(width: 20),
                _buildMetric(Icons.comment, post.commentCount, Colors.orange),
                const SizedBox(width: 20),
                _buildMetric(Icons.thumb_up, post.upvotes, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadStats() async {
    final userStats = await _userService.getUserStats();
    final postStats = await _postService.getPostStats();
    
    return {
      ...userStats,
      ...postStats,
    };
  }
}