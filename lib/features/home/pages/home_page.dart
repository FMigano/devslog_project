import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();
  String _selectedCategory = 'All';
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.getCurrentUserData();
    setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          if (MediaQuery.of(context).size.width > 900) _buildSidebar(),
          Expanded(child: _buildMainContent()),
          if (MediaQuery.of(context).size.width > 1200) _buildRightSidebar(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreatePostPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Post'),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.code, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('DevsLog'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            );
          },
        ),
        StreamBuilder<List<NotificationModel>>(
          stream: _currentUser != null
              ? NotificationService().getNotifications(_currentUser!.uid)
              : Stream.value([]),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsPage()),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (_currentUser != null && _currentUser!.isAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
              );
            },
          ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: CircleAvatar(
            backgroundImage: _currentUser?.photoURL != null
                ? NetworkImage(_currentUser!.photoURL!)
                : null,
            child: _currentUser?.photoURL == null
                ? Text(_currentUser?.displayName[0].toUpperCase() ?? 'U')
                : null,
          ),
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'profile',
              child: const ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem<String>(
              value: 'bookmarks',
              child: const ListTile(
                leading: Icon(Icons.bookmark),
                title: Text('Bookmarks'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem<String>(
              value: 'settings',
              child: const ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'logout',
              child: const ListTile(
                leading: Icon(Icons.logout, color: AppTheme.errorColor),
                title: Text('Logout', style: TextStyle(color: AppTheme.errorColor)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'profile':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
                break;
              case 'bookmarks':
                // Handle bookmarks
                break;
              case 'settings':
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
                break;
              case 'logout':
                Provider.of<AuthService>(context, listen: false).signOut();
                break;
            }
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(right: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Categories', style: Theme.of(context).textTheme.titleMedium),
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
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : null),
      title: Text(category),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        setState(() => _selectedCategory = category);
      },
    );
  }

  Widget _buildMainContent() {
    return StreamBuilder<List<PostModel>>(
      stream: _firestoreService.getPosts(
        category: _selectedCategory == 'All' ? null : _selectedCategory,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 80, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                Text('No posts yet', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Be the first to share something!', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            return PostCard(
              post: posts[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailPage(post: posts[index]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRightSidebar() {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(left: BorderSide(color: AppTheme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trending Tags', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Flutter', 'Firebase', 'Dart', 'Web Dev', 'Mobile'].map((tag) {
              return Chip(
                label: Text(tag),
                backgroundColor: AppTheme.primaryColor.withAlpha(26),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
