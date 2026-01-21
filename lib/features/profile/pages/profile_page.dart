import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/saved_posts_service.dart';
import '../../../shared/models/post_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/post_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../posts/pages/post_detail_page.dart';
import 'activity_logs_page.dart';
import '../../settings/pages/settings_page.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final SavedPostsService _savedPostsService = SavedPostsService();
  
  UserModel? _user;
  bool _isLoading = true;
  int _postsCount = 0;
  int _commentsCount = 0;
  int _reputation = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return EmptyState(
            icon: Icons.article_outlined,
            title: 'No Posts Yet',
            message: _isOwnProfile
                ? 'Start sharing your knowledge by creating your first post!'
                : 'This user hasn\'t posted anything yet.',
          );
        }

        // For own profile, show ALL posts (approved and pending)
        // For other profiles, show only approved posts
        final allPosts = snapshot.data!.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList();

        final posts = _isOwnProfile 
            ? allPosts  // Show all posts for own profile
            : allPosts.where((post) => post.isApproved).toList(); // Only approved for others

        if (posts.isEmpty) {
          return EmptyState(
            icon: Icons.pending,
            title: _isOwnProfile ? 'Posts Pending Approval' : 'No Posts Available',
            message: _isOwnProfile
                ? 'Your posts are waiting for admin approval.'
                : 'This user hasn\'t posted anything yet.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Stack(
                children: [
                  PostCard(
                    post: post,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailPage(
                            postId: post.id,
                          ),
                        ),
                      );
                    },
                  ),
                  // Show pending badge if not approved and is own post
                  if (_isOwnProfile && !post.isApproved)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Pending Approval',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadUserData() async {
    try {
      // Load user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          _user = UserModel.fromFirestore(userDoc);
        });
      }

      // Load posts count - get ALL posts for own profile
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('authorId', isEqualTo: widget.userId)
          .get();

      // For own profile, count all posts. For others, count only approved
      final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
      final isOwn = currentUserId == widget.userId;
      
      final postsCount = isOwn 
          ? postsSnapshot.docs.length  // All posts for own profile
          : postsSnapshot.docs.where((doc) => doc.data()['isApproved'] == true).length;

      // Load comments count
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('comments')
          .where('authorId', isEqualTo: widget.userId)
          .get();

      // Calculate reputation (only from approved posts)
      final approvedPostsCount = postsSnapshot.docs
          .where((doc) => doc.data()['isApproved'] == true)
          .length;
      final reputation = (approvedPostsCount * 10) + 
                        (commentsSnapshot.docs.length * 5);

      setState(() {
        _postsCount = postsCount;
        _commentsCount = commentsSnapshot.docs.length;
        _reputation = reputation;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  bool get _isOwnProfile {
    final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    return currentUserId == widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Profile'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Profile'),
        ),
        body: const Center(child: Text('User not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Profile'),
        actions: _isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.darkSurface,
            child: Column(
              children: [
                Row(
                  children: [
                    // Profile Avatar
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.darkPrimary,
                      backgroundImage: _user!.photoURL != null
                          ? NetworkImage(_user!.photoURL!)
                          : null,
                      child: _user!.photoURL == null
                          ? Text(
                              _user!.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user!.displayName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user!.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.darkTextSecondary,
                            ),
                          ),
                          if (_user!.bio != null && _user!.bio!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _user!.bio!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkTextPrimary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_isOwnProfile)
                      ElevatedButton.icon(
                        onPressed: () => _showEditProfileDialog(),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkPrimary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.article,
                        count: _postsCount,
                        label: 'Posts',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.comment,
                        count: _commentsCount,
                        label: 'Comments',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.star,
                        count: _reputation,
                        label: 'Reputation',
                      ),
                    ),
                  ],
                ),
                if (_isOwnProfile) ...[
                  const SizedBox(height: 16),
                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ActivityLogsPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history),
                          label: const Text('Activity'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.darkPrimary,
                            side: BorderSide(color: AppTheme.darkPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Tabs
          Container(
            color: AppTheme.darkSurface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.darkPrimary,
              labelColor: AppTheme.darkPrimary,
              unselectedLabelColor: AppTheme.darkTextSecondary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.article),
                  text: 'Posts ($_postsCount)',
                ),
                if (_isOwnProfile)
                  const Tab(
                    icon: Icon(Icons.bookmark),
                    text: 'Saved',
                  )
                else
                  const Tab(
                    icon: Icon(Icons.info),
                    text: 'About',
                  ),
              ],
            ),
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsTab(),
                if (_isOwnProfile) _buildSavedPostsTab() else _buildAboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.darkPrimary, size: 24),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkTextPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedPostsTab() {
    return StreamBuilder<List<PostModel>>(
      stream: _savedPostsService.getSavedPostsStream(widget.userId),
      builder: (context, snapshot) {
        // Add debug logging
        print('🔍 Saved Posts Stream State: ${snapshot.connectionState}');
        print('🔍 Has Data: ${snapshot.hasData}');
        print('🔍 Data Count: ${snapshot.data?.length ?? 0}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('❌ Error loading saved posts: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: 16),
                Text(
                  'Error loading saved posts',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return EmptyState(
            icon: Icons.bookmark_border,
            title: 'No Saved Posts',
            message: 'Posts you save will appear here',
          );
        }

        final posts = snapshot.data!;
        print('✅ Displaying ${posts.length} saved posts');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PostCard(
                post: posts[index],
                onTap: () {
                  // Navigate to post detail
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAboutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          'Email',
          _user!.email,
          Icons.email,
        ),
        if (_user!.bio != null && _user!.bio!.isNotEmpty)
          _buildInfoCard(
            'Bio',
            _user!.bio!,
            Icons.info,
          ),
        _buildInfoCard(
          'Joined',
          _formatDate(_user!.createdAt),
          Icons.calendar_today,
        ),
        _buildInfoCard(
          'Role',
          _user!.role.toUpperCase(),
          Icons.person,
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.darkPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _user!.displayName);
    final bioController = TextEditingController(text: _user!.bio ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'Edit Profile',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: AppTheme.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: AppTheme.darkTextSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.darkDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.darkPrimary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioController,
              maxLines: 3,
              style: TextStyle(color: AppTheme.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: AppTheme.darkTextSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.darkDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.darkPrimary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .update({
                  'displayName': nameController.text,
                  'bio': bioController.text,
                });

                if (mounted) {
                  Navigator.pop(context);
                  _loadUserData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
