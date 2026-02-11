import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/user_model.dart';
import '../../posts/pages/create_post_page.dart';
import '../../posts/pages/post_detail_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../admin/pages/admin_dashboard_page.dart';
import '../../../shared/widgets/post_card.dart';
import '../../search/pages/search_page.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../../shared/services/notification_service.dart';
import '../../settings/pages/settings_page.dart';
import '../../../shared/services/trending_tags_service.dart';
import '../../../shared/services/featured_posts_service.dart';
import '../../../shared/services/ai_summarizer_service.dart';
import '../../posts/widgets/post_detail_modal.dart';
import '../../search/widgets/search_modal.dart';
import '../../posts/widgets/create_post_modal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();
  final FeaturedPostsService _featuredPostsService = FeaturedPostsService();
  final AiSummarizerService _aiService = AiSummarizerService();
  String _selectedCategory = 'All';
  UserModel? _currentUser;
  bool _isInitializing = true;
  bool _aiAvailable = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await _loadCurrentUser(authService);
    setState(() => _isInitializing = false);
  }

  Future<void> _loadCurrentUser(AuthService authService) async {
    final user = await authService.getCurrentUserData();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _checkAiAvailability() async {
    final available = await _aiService.isAvailable();
    if (mounted) {
      setState(() => _aiAvailable = available);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Container(
              color: AppTheme.darkBackground,
              child: _buildMainContent(),
            ),
          ),
          _buildRightSidebar(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showCreatePostModal(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
        backgroundColor: AppTheme.darkPrimary,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.darkSurface,
      elevation: 1,
      shadowColor: AppTheme.darkDivider,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.darkPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.code, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            'DevsLog',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextPrimary,
                ),
          ),
        ],
      ),
      actions: [
        if (_aiAvailable)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.purple.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.purple),
                const SizedBox(width: 6),
                Text(
                  'AI Active',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            showSearchModal(context);
          },
          tooltip: 'Search',
          color: AppTheme.darkTextSecondary,
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsPage()),
                );
              },
              color: AppTheme.darkTextSecondary,
            ),
            StreamBuilder<int>(
              stream: NotificationService().getUnreadCountStream(_currentUser!.uid),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                if (unreadCount == 0) return const SizedBox();

                return Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(width: 8),
        _buildProfileMenu(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildProfileMenu() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      icon: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.darkPrimary,
            width: 2,
          ),
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.darkPrimary,
          backgroundImage: _currentUser!.photoURL != null
              ? NetworkImage(_currentUser!.photoURL!)
              : null,
          child: _currentUser!.photoURL == null
              ? Text(
                  _currentUser!.displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
      color: AppTheme.darkSurface,
      elevation: 8,
      onSelected: (value) async {
        final authService = Provider.of<AuthService>(context, listen: false);
        switch (value) {
          case 'profile':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProfilePage(userId: _currentUser!.uid),
              ),
            );
            break;
          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              ),
            );
            break;
          case 'admin':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminDashboardPage(),
              ),
            );
            break;
          case 'logout':
            _showLogoutDialog(authService);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.darkPrimary,
                    backgroundImage: _currentUser!.photoURL != null
                        ? NetworkImage(_currentUser!.photoURL!)
                        : null,
                    child: _currentUser!.photoURL == null
                        ? Text(
                            _currentUser!.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser!.displayName,
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentUser!.email,
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(color: AppTheme.darkDivider, height: 1),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'profile',
          height: 48,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: AppTheme.darkPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Profile',
                style: TextStyle(
                  color: AppTheme.darkTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          height: 48,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.darkPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: AppTheme.darkPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Settings',
                style: TextStyle(
                  color: AppTheme.darkTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_currentUser!.isAdmin)
          PopupMenuItem(
            value: 'admin',
            height: 48,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          height: 48,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.logout,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.logout,
                color: AppTheme.errorColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: AppTheme.darkTextPrimary,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.darkTextSecondary,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(right: BorderSide(color: AppTheme.darkDivider)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.darkTextPrimary,
                ),
          ),
          const SizedBox(height: 16),
          _buildCategoryItem('All', Icons.grid_view),
          ...AppConstants.postCategories.map((category) {
            return _buildCategoryItem(category, Icons.folder_outlined);
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String category, IconData icon) {
    final isSelected = _selectedCategory == category;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.darkPrimary : AppTheme.darkTextSecondary,
      ),
      title: Text(
        category,
        style: TextStyle(
          color: isSelected ? AppTheme.darkPrimary : AppTheme.darkTextPrimary,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.darkPrimary.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
    );
  }

  Widget _buildMainContent() {
    // Use StreamBuilder for real-time updates
    return StreamBuilder<QuerySnapshot>(
      stream: _selectedCategory == 'All'
          ? FirebaseFirestore.instance
              .collection('posts')
              .where('isApproved', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('posts')
              .where('isApproved', isEqualTo: true)
              .where('category', isEqualTo: _selectedCategory)
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: AppTheme.darkTextSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedCategory == 'All'
                      ? 'No approved posts yet'
                      : 'No posts in this category',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to post!',
                  style: TextStyle(color: AppTheme.darkTextSecondary),
                ),
              ],
            ),
          );
        }

        final posts = snapshot.data!.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList();

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: ListView.builder(
            key: ValueKey(_selectedCategory),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PostCard(
                  post: posts[index],
                  onTap: () {
                    showPostDetailModal(context, posts[index]);
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRightSidebar() {
    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.5),
        border: Border(left: BorderSide(color: AppTheme.darkDivider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trending Tags Section
            Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Trending Tags',
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: TrendingTagsService().getTrendingTagsStream(limit: 10),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text(
                    'No trending tags yet',
                    style: TextStyle(color: AppTheme.darkTextSecondary),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: snapshot.data!.map((tagData) {
                    final tag = tagData['tag'] as String;
                    final count = tagData['count'] as int;
                    
                    return InkWell(
                      onTap: () {
                        showSearchModal(context, initialQuery: '#$tag');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$tag',
                              style: TextStyle(
                                color: AppTheme.darkPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.darkPrimary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: AppTheme.darkPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Featured Posts Section - UPDATED
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Featured Posts',
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Use getBestEngagementPosts instead for better results
            StreamBuilder<List<PostModel>>(
              stream: _featuredPostsService.getBestEngagementPosts(limit: 3),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('Featured posts error: ${snapshot.error}');
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.errorColor, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Error loading posts',
                          style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.stars, color: AppTheme.darkTextSecondary, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'No featured posts yet',
                          style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: snapshot.data!.map((post) {
                    return _buildFeaturedPostCard(post);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedPostCard(PostModel post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.darkPrimary.withOpacity(0.2),
            AppTheme.darkSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkPrimary.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // ✅ Open as modal instead of navigation
            showPostDetailModal(context, post);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: AppTheme.darkPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.title,
                        style: TextStyle(
                          color: AppTheme.darkTextPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.authorName,
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatChip(Icons.visibility, post.views, AppTheme.darkTextSecondary),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.arrow_upward, post.upvotes, Colors.green),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.comment, post.commentCount, Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ));
  }
}
