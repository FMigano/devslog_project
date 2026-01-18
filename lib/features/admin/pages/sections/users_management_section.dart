import 'package:flutter/material.dart';
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.people,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '👥 User Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  StreamBuilder<List<UserModel>>(
                    stream: _userService.getUsersStream(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: Text(
                          'Total: $count users',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
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
                  // Search Bar
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search users by name or email...',
                        hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
                        prefixIcon: Icon(Icons.search, color: AppTheme.darkTextSecondary),
                        filled: true,
                        fillColor: AppTheme.darkSurfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Role Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: DropdownButton<String>(
                      value: _filterRole,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.darkSurface,
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      icon: Icon(Icons.filter_list, color: AppTheme.darkTextSecondary),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Roles')),
                        DropdownMenuItem(value: 'admin', child: Text('Admins')),
                        DropdownMenuItem(value: 'user', child: Text('Users')),
                      ],
                      onChanged: (value) => setState(() {
                        _filterRole = value!;
                        _currentPage = 0;
                      }),
                    ),
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

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Users Found',
                  message: 'There are no users in the system yet.',
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.darkDivider),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.darkPrimary.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'User',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Email',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Role',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Posts',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Joined',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Actions',
                                      style: TextStyle(
                                        color: AppTheme.darkTextPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table Rows
                            ...paginatedUsers.asMap().entries.map((entry) {
                              final index = entry.key;
                              final user = entry.value;
                              final isEven = index % 2 == 0;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isEven
                                      ? AppTheme.darkSurfaceVariant.withOpacity(0.3)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppTheme.darkDivider.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // User
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: AppTheme.darkPrimary,
                                            backgroundImage: user.photoURL != null
                                                ? NetworkImage(user.photoURL!)
                                                : null,
                                            child: user.photoURL == null
                                                ? Text(
                                                    user.displayName[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              user.displayName,
                                              style: TextStyle(
                                                color: AppTheme.darkTextPrimary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Email
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        user.email,
                                        style: TextStyle(
                                          color: AppTheme.darkTextSecondary,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Role
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: user.isAdmin
                                              ? AppTheme.warningColor.withOpacity(0.2)
                                              : Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: user.isAdmin
                                                ? AppTheme.warningColor
                                                : Colors.grey,
                                          ),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: TextStyle(
                                            color: user.isAdmin
                                                ? AppTheme.warningColor
                                                : Colors.grey,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    // Posts
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${user.postCount}',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    // Joined
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        timeago.format(user.createdAt),
                                        style: TextStyle(
                                          color: AppTheme.darkTextSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    // Actions
                                    Expanded(
                                      flex: 1,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 18),
                                            color: AppTheme.darkPrimary,
                                            onPressed: () => _showEditDialog(user),
                                            tooltip: 'Edit User',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete, size: 18),
                                            color: AppTheme.errorColor,
                                            onPressed: () => _deleteUser(user),
                                            tooltip: 'Delete User',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
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

  void _showEditDialog(UserModel user) {
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
            _buildDetailRow('Joined', timeago.format(user.createdAt)),
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
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
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