import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/user_model.dart';
import '../../widgets/pagination_controls.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import '../../widgets/empty_state_widget.dart';
import '../../services/admin_user_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:fluttertoast/fluttertoast.dart';

class UsersManagementSection extends StatefulWidget {
  const UsersManagementSection({super.key});

  @override
  State<UsersManagementSection> createState() => _UsersManagementSectionState();
}

class _UsersManagementSectionState extends State<UsersManagementSection> {
  final AdminUserService _userService = AdminUserService();
  final int _itemsPerPage = 10;
  int _currentPage = 0;
  String _searchQuery = '';
  String _filterRole = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header and Filters
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withOpacity(0.5),
            border: Border(bottom: BorderSide(color: AppTheme.darkDivider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.people, color: Colors.green, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Users Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkTextPrimary,
                            ),
                          ),
                          Text(
                            'Manage user accounts and permissions',
                            style: TextStyle(
                              color: AppTheme.darkTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  StreamBuilder<List<UserModel>>(
                    stream: _userService.getUsersStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Text(
                          '$count Users',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
                        prefixIcon: Icon(Icons.search, color: AppTheme.darkTextSecondary),
                        filled: true,
                        fillColor: AppTheme.darkSurfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.darkDivider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.darkDivider),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _filterRole,
                    dropdownColor: AppTheme.darkSurface,
                    style: TextStyle(color: AppTheme.darkTextPrimary),
                    underline: Container(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Roles')),
                      DropdownMenuItem(value: 'user', child: Text('Users')),
                      DropdownMenuItem(value: 'admin', child: Text('Admins')),
                    ],
                    onChanged: (value) => setState(() => _filterRole = value!),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Users Table
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _userService.getUsersStream(),
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

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Users Found',
                  message: 'No users in the system yet.',
                );
              }

              var users = snapshot.data!;

              // Apply filters
              if (_searchQuery.isNotEmpty) {
                users = users.where((user) {
                  return user.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      user.email.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();
              }

              if (_filterRole != 'all') {
                users = users.where((user) => user.role == _filterRole).toList();
              }

              // Pagination
              final totalPages = (users.length / _itemsPerPage).ceil();
              final startIndex = _currentPage * _itemsPerPage;
              final endIndex = (startIndex + _itemsPerPage).clamp(0, users.length);
              final paginatedUsers = users.sublist(startIndex, endIndex);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.darkSurfaceVariant,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 250,
                                    child: Text(
                                      'USER',
                                      style: TextStyle(
                                        color: AppTheme.darkTextSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      'ROLE',
                                      style: TextStyle(
                                        color: AppTheme.darkTextSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'POSTS',
                                      style: TextStyle(
                                        color: AppTheme.darkTextSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'JOINED',
                                      style: TextStyle(
                                        color: AppTheme.darkTextSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 200,
                                    child: Text(
                                      'ACTIONS',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: AppTheme.darkTextSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table Body
                            ...paginatedUsers.asMap().entries.map((entry) {
                              final index = entry.key;
                              final user = entry.value;
                              final isLast = index == paginatedUsers.length - 1;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: isLast
                                        ? BorderSide.none
                                        : BorderSide(color: AppTheme.darkDivider),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // User Info
                                    SizedBox(
                                      width: 250,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: AppTheme.darkPrimary,
                                            backgroundImage: user.photoURL != null
                                                ? NetworkImage(user.photoURL!)
                                                : null,
                                            child: user.photoURL == null
                                                ? Text(
                                                    user.displayName[0].toUpperCase(),
                                                    style: const TextStyle(
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
                                                  user.displayName,
                                                  style: TextStyle(
                                                    color: AppTheme.darkTextPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  user.email,
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
                                    ),

                                    // Role
                                    SizedBox(
                                      width: 150,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: user.isAdmin
                                              ? AppTheme.warningColor.withOpacity(0.2)
                                              : Colors.blue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: user.isAdmin
                                                ? AppTheme.warningColor
                                                : Colors.blue,
                                          ),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: TextStyle(
                                            color: user.isAdmin
                                                ? AppTheme.warningColor
                                                : Colors.blue,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),

                                    // Posts Count
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        '${user.postCount} posts',
                                        style: TextStyle(
                                          color: AppTheme.darkTextPrimary,
                                        ),
                                      ),
                                    ),

                                    // Joined Date
                                    Expanded(
                                      child: Text(
                                        timeago.format(user.createdAt),
                                        style: TextStyle(
                                          color: AppTheme.darkTextSecondary,
                                        ),
                                      ),
                                    ),

                                    // Actions
                                    SizedBox(
                                      width: 200,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18),
                                            onPressed: () => _showEditDialog(user),
                                            tooltip: 'Edit User',
                                            color: Colors.blue,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.visibility, size: 18),
                                            onPressed: () => _showViewDialog(user),
                                            tooltip: 'View Details',
                                            color: AppTheme.darkTextSecondary,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18),
                                            onPressed: () => _deleteUser(user),
                                            tooltip: 'Delete User',
                                            color: AppTheme.errorColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (totalPages > 1)
                    PaginationControls(
                      currentPage: _currentPage,
                      totalPages: totalPages,
                      onPageChanged: (page) => setState(() => _currentPage = page),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ⭐ NEW: Edit user dialog
  void _showEditDialog(UserModel user) {
    final nameController = TextEditingController(text: user.displayName);
    final emailController = TextEditingController(text: user.email);
    final bioController = TextEditingController(text: user.bio ?? '');
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.darkDivider),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              'Edit User',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Name
              Text(
                'Display Name',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: TextStyle(color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkSurfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              Text(
                'Email',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                style: TextStyle(color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkSurfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Role
              Text(
                'Role',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setState) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: DropdownButton<String>(
                      value: selectedRole,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.darkSurface,
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      items: const [
                        DropdownMenuItem(value: 'user', child: Text('User')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (value) {
                        setState(() => selectedRole = value!);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Bio
              Text(
                'Bio',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioController,
                maxLines: 3,
                style: TextStyle(color: AppTheme.darkTextPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.darkSurfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.darkDivider),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Update user in Firestore
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                  'displayName': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'role': selectedRole,
                  'bio': bioController.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                Fluttertoast.showToast(
                  msg: '✅ User updated successfully',
                  backgroundColor: AppTheme.successColor,
                );
              } catch (e) {
                Fluttertoast.showToast(
                  msg: '❌ Failed to update user: $e',
                  backgroundColor: AppTheme.errorColor,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // View user details (read-only)
  void _showViewDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.darkDivider),
        ),
        title: Text(
          'User Details',
          style: TextStyle(
            color: AppTheme.darkTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Name', user.displayName),
            _buildDetailRow('Email', user.email),
            _buildDetailRow('Role', user.role.toUpperCase()),
            _buildDetailRow('Posts', '${user.postCount}'),
            _buildDetailRow('Comments', '${user.commentCount}'),
            _buildDetailRow('Reputation', '${user.reputation}'),
            _buildDetailRow('Joined', timeago.format(user.createdAt)),
            if (user.bio != null && user.bio!.isNotEmpty)
              _buildDetailRow('Bio', user.bio!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await DeleteConfirmationDialog.show(
      context,
      title: 'Delete User',
      message:
          'Are you sure you want to delete ${user.displayName}? This will also delete all their posts and comments. This action cannot be undone.',
    );

    if (confirm == true) {
      try {
        await _userService.deleteUser(user.uid);
        Fluttertoast.showToast(
          msg: '✅ User deleted successfully',
          backgroundColor: AppTheme.successColor,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: '❌ Failed to delete user: $e',
          backgroundColor: AppTheme.errorColor,
        );
      }
    }
  }
}