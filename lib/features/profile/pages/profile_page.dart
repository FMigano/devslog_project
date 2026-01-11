import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/models/user_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.getCurrentUserData();
    setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildStatsCards(),
              const SizedBox(height: 24),
              _buildBadges(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _user!.photoURL != null ? NetworkImage(_user!.photoURL!) : null,
              child: _user!.photoURL == null
                  ? Text(_user!.displayName[0].toUpperCase(), style: const TextStyle(fontSize: 32))
                  : null,
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_user!.displayName, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(_user!.email, style: Theme.of(context).textTheme.bodyLarge),
                  if (_user!.bio != null) ...[
                    const SizedBox(height: 8),
                    Text(_user!.bio!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Posts', _user!.postCount, Icons.article)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Comments', _user!.commentCount, Icons.comment)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Reputation', _user!.reputation, Icons.star)),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildBadges() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Badges', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _user!.badges.map((badge) {
                return Chip(
                  label: Text(badge),
                  avatar: const Icon(Icons.emoji_events, size: 20),
                  backgroundColor: AppTheme.primaryColor.withAlpha(26),
                );
              }).toList(),
            ),
            if (_user!.badges.isEmpty)
              const Text('No badges yet. Keep contributing to earn badges!'),
          ],
        ),
      ),
    );
  }
}
