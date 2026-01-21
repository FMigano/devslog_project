import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/services/auth_service.dart';
import '../../profile/pages/profile_page.dart';
import '../../auth/pages/terms_and_conditions_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _pushNotifications = data?['pushNotifications'] ?? true;
            _emailNotifications = data?['emailNotifications'] ?? true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({key: value});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings updated successfully')),
          );
        }
      }
    } catch (e) {
      print('Error updating settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update settings')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.darkBackground,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: ListView(
        children: [
          _buildSection(
            context,
            'Appearance',
            [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return SwitchListTile(
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                    ),
                    subtitle: Text(
                      'Enable dark theme',
                      style: TextStyle(color: AppTheme.darkTextSecondary),
                    ),
                    value: themeProvider.isDarkMode,
                    onChanged: (value) => themeProvider.toggleTheme(),
                    secondary: Icon(
                      themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: AppTheme.darkPrimary,
                    ),
                    activeThumbColor: AppTheme.darkPrimary,
                  );
                },
              ),
            ],
          ),
          _buildSection(
            context,
            'Notifications',
            [
              SwitchListTile(
                title: Text(
                  'Push Notifications',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                subtitle: Text(
                  'Receive notifications for new activity',
                  style: TextStyle(color: AppTheme.darkTextSecondary),
                ),
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() => _pushNotifications = value);
                  _updateNotificationSetting('pushNotifications', value);
                },
                secondary: Icon(Icons.notifications, color: AppTheme.darkPrimary),
                activeThumbColor: AppTheme.darkPrimary,
              ),
              SwitchListTile(
                title: Text(
                  'Email Notifications',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                subtitle: Text(
                  'Receive email updates',
                  style: TextStyle(color: AppTheme.darkTextSecondary),
                ),
                value: _emailNotifications,
                onChanged: (value) {
                  setState(() => _emailNotifications = value);
                  _updateNotificationSetting('emailNotifications', value);
                },
                secondary: Icon(Icons.email, color: AppTheme.darkPrimary),
                activeThumbColor: AppTheme.darkPrimary,
              ),
            ],
          ),
          _buildSection(
            context,
            'Account',
            [
              ListTile(
                leading: Icon(Icons.person, color: AppTheme.darkPrimary),
                title: Text(
                  'Edit Profile',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
                onTap: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(userId: user.uid),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.lock, color: AppTheme.darkPrimary),
                title: Text(
                  'Change Password',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
                onTap: () => _showChangePasswordDialog(),
              ),
              ListTile(
                leading: Icon(Icons.privacy_tip, color: AppTheme.darkPrimary),
                title: Text(
                  'Privacy Settings',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
                onTap: () => _showPrivacySettings(),
              ),
              ListTile(
                leading: Icon(Icons.delete_forever, color: AppTheme.errorColor),
                title: Text(
                  'Delete Account',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
                onTap: () => _showDeleteAccountDialog(),
              ),
            ],
          ),
          _buildSection(
            context,
            'About',
            [
              ListTile(
                leading: Icon(Icons.info, color: AppTheme.darkPrimary),
                title: Text(
                  'About DevsLog',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
                onTap: () => _showAboutDialog(),
              ),
              ListTile(
                leading: Icon(Icons.policy, color: AppTheme.darkPrimary),
                title: Text(
                  'Terms & Conditions',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsAndConditionsPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.help, color: AppTheme.darkPrimary),
                title: Text(
                  'Help & Support',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
                onTap: () => _showHelpSupport(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(),
              icon: const Icon(Icons.logout, color: AppTheme.errorColor),
              label: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.darkPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: AppTheme.darkSurface,
          child: Column(children: children),
        ),
      ],
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'Change Password',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: TextStyle(color: AppTheme.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Current Password',
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
              controller: newPasswordController,
              obscureText: true,
              style: TextStyle(color: AppTheme.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'New Password',
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
              controller: confirmPasswordController,
              obscureText: true,
              style: TextStyle(color: AppTheme.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Confirm Password',
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
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser!;
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPasswordController.text,
                );
                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPasswordController.text);
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully')),
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
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'Privacy Settings',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(
                'Profile Visibility',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              subtitle: Text(
                'Make profile visible to everyone',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
              value: true,
              onChanged: (value) {},
              activeThumbColor: AppTheme.darkPrimary,
            ),
            SwitchListTile(
              title: Text(
                'Show Activity',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              subtitle: Text(
                'Show your activity to others',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
              value: true,
              onChanged: (value) {},
              activeThumbColor: AppTheme.darkPrimary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.darkPrimary)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'Delete Account',
          style: TextStyle(color: AppTheme.errorColor),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser!;
                
                // Delete user data from Firestore
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .delete();
                
                // Delete user account
                await user.delete();
                
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'About DevsLog',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DevsLog',
              style: TextStyle(
                color: AppTheme.darkPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'A modern blogging platform for developers to share their knowledge and experiences.',
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              '© 2026 DevsLog. All rights reserved.',
              style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.darkPrimary)),
          ),
        ],
      ),
    );
  }

  void _showHelpSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'Help & Support',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.email, color: AppTheme.darkPrimary),
              title: Text(
                'Email Support',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              subtitle: Text(
                'support@devslog.com',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
            ),
            ListTile(
              leading: Icon(Icons.bug_report, color: AppTheme.darkPrimary),
              title: Text(
                'Report a Bug',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              subtitle: Text(
                'bugs@devslog.com',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
            ),
            ListTile(
              leading: Icon(Icons.book, color: AppTheme.darkPrimary),
              title: Text(
                'Documentation',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              subtitle: Text(
                'docs.devslog.com',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AppTheme.darkPrimary)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'Logout',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
