import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/models/post_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) => setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('Posts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildOverview(),
                _buildUsersManagement(),
                _buildPostsManagement(),
                _buildAnalytics(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, userSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('posts').snapshots(),
          builder: (context, postSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('comments').snapshots(),
              builder: (context, commentSnapshot) {
                final userCount = userSnapshot.data?.docs.length ?? 0;
                final postCount = postSnapshot.data?.docs.length ?? 0;
                final commentCount = commentSnapshot.data?.docs.length ?? 0;

                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('Dashboard Overview', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _buildStatCard('Total Users', userCount, Icons.people, AppTheme.primaryColor),
                        _buildStatCard('Total Posts', postCount, Icons.article, AppTheme.successColor),
                        _buildStatCard('Total Comments', commentCount, Icons.comment, AppTheme.accentColor),
                        _buildStatCard('Active Today', 0, Icons.trending_up, AppTheme.warningColor),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    _buildRecentPosts(),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs.map((doc) => PostModel.fromFirestore(doc)).toList();

        return Card(
          child: Column(
            children: posts.map((post) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: post.authorPhotoURL != null ? NetworkImage(post.authorPhotoURL!) : null,
                  child: post.authorPhotoURL == null ? Text(post.authorName[0]) : null,
                ),
                title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${post.authorName} • ${timeago.format(post.createdAt)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                      onPressed: () => _deletePost(post.id),
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

  Widget _buildUsersManagement() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('User Management', style: Theme.of(context).textTheme.headlineMedium),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add User'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Posts')),
                  DataColumn(label: Text('Reputation')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: users.map((user) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                              child: user.photoURL == null ? Text(user.displayName[0]) : null,
                            ),
                            const SizedBox(width: 8),
                            Text(user.displayName),
                          ],
                        ),
                      ),
                      DataCell(Text(user.email)),
                      DataCell(Chip(
                        label: Text(user.role),
                        backgroundColor: user.isAdmin ? AppTheme.accentColor.withAlpha(26) : null,
                      )),
                      DataCell(Text('${user.postCount}')),
                      DataCell(Text('${user.reputation}')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showEditUserDialog(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                              onPressed: () => _deleteUser(user.uid),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPostsManagement() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs.map((doc) => PostModel.fromFirestore(doc)).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Post Management', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: posts.map((post) {
                  return ExpansionTile(
                    leading: Icon(
                      Icons.article,
                      color: post.isPinned ? AppTheme.primaryColor : null,
                    ),
                    title: Text(post.title),
                    subtitle: Text('${post.authorName} • ${post.category} • ${timeago.format(post.createdAt)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            post.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            color: post.isPinned ? AppTheme.primaryColor : null,
                          ),
                          onPressed: () => _togglePinPost(post.id, !post.isPinned),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                          onPressed: () => _deletePost(post.id),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildPostStat(Icons.thumb_up, post.upvotes),
                                const SizedBox(width: 16),
                                _buildPostStat(Icons.thumb_down, post.downvotes),
                                const SizedBox(width: 16),
                                _buildPostStat(Icons.comment, post.commentCount),
                                const SizedBox(width: 16),
                                _buildPostStat(Icons.visibility, post.viewCount),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (post.tags.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                children: post.tags.map((tag) => Chip(label: Text(tag))).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPostStat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text('$count', style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildAnalytics() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
        final categoryData = _getCategoryData(posts);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Analytics', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Posts by Category', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 300,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: categoryData.values.reduce((a, b) => a > b ? a : b).toDouble() + 5,
                          barGroups: categoryData.entries.map((entry) {
                            final index = categoryData.keys.toList().indexOf(entry.key);
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.toDouble(),
                                  color: AppTheme.primaryColor,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final categories = categoryData.keys.toList();
                                  if (value.toInt() < categories.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        categories[value.toInt()],
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Activity', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 300,
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: _getMonthlyData(posts),
                              isCurved: true,
                              color: AppTheme.primaryColor,
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                                  if (value.toInt() < months.length) {
                                    return Text(months[value.toInt()]);
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: true),
                          gridData: const FlGridData(show: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, int> _getCategoryData(List<PostModel> posts) {
    final Map<String, int> categoryCount = {};
    for (var post in posts) {
      categoryCount[post.category] = (categoryCount[post.category] ?? 0) + 1;
    }
    return categoryCount;
  }

  List<FlSpot> _getMonthlyData(List<PostModel> posts) {
    final Map<int, int> monthlyCount = {};
    for (var post in posts) {
      final month = post.createdAt.month - 1;
      monthlyCount[month] = (monthlyCount[month] ?? 0) + 1;
    }
    return monthlyCount.entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('posts').doc(postId).delete();
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('users').doc(userId).delete();
    }
  }

  Future<void> _togglePinPost(String postId, bool pin) async {
    await _firestore.collection('posts').doc(postId).update({'isPinned': pin});
  }

  void _showEditUserDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Make Admin'),
              trailing: Switch(
                value: user.isAdmin,
                onChanged: (value) {
                  _firestore.collection('users').doc(user.uid).update({'role': value ? 'admin' : 'user'});
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
