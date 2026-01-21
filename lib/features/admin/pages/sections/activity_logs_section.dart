import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/activity_log_service.dart';
import '../../../../shared/models/activity_log_model.dart';
import '../../widgets/empty_state_widget.dart';

class ActivityLogsSection extends StatefulWidget {
  const ActivityLogsSection({super.key});

  @override
  State<ActivityLogsSection> createState() => _ActivityLogsSectionState();
}

class _ActivityLogsSectionState extends State<ActivityLogsSection> {
  final ActivityLogService _activityService = ActivityLogService();
  String _filterType = 'all';
  String _searchQuery = '';

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
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.history,
                          color: Colors.purple,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '📊 Activity Logs',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _activityService.clearOldLogs();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Old logs cleared successfully'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Clear Old Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Search
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by user or description...',
                        hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
                        prefixIcon: Icon(Icons.search, color: AppTheme.darkTextSecondary),
                        filled: true,
                        fillColor: AppTheme.darkSurfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkDivider),
                    ),
                    child: DropdownButton<String>(
                      value: _filterType,
                      underline: const SizedBox(),
                      dropdownColor: AppTheme.darkSurface,
                      style: TextStyle(color: AppTheme.darkTextPrimary),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Types')),
                        ...ActivityType.values.map((type) {
                          final name = type.toString().split('.').last;
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }),
                      ],
                      onChanged: (value) => setState(() => _filterType = value!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Logs List
        Expanded(
          child: StreamBuilder<List<ActivityLogModel>>(
            stream: _activityService.getAllActivityStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.history,
                  title: 'No Activity Logs',
                  message: 'Activity logs will appear here',
                );
              }

              var logs = snapshot.data!;

              // Apply filters
              if (_searchQuery.isNotEmpty) {
                logs = logs.where((log) {
                  return log.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      log.userEmail.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      log.description.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();
              }

              if (_filterType != 'all') {
                logs = logs.where((log) {
                  return log.type.toString().split('.').last == _filterType;
                }).toList();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildLogItem(log);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(ActivityLogModel log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getActivityColor(log.type).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getActivityIcon(log.type),
                color: _getActivityColor(log.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.description,
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.userName,
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          log.userEmail,
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeago.format(log.createdAt),
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Type Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getActivityColor(log.type).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getActivityColor(log.type)),
              ),
              child: Text(
                log.type.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  color: _getActivityColor(log.type),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.login:
        return Icons.login;
      case ActivityType.logout:
        return Icons.logout;
      case ActivityType.register:
        return Icons.person_add;
      case ActivityType.postCreated:
        return Icons.add_circle;
      case ActivityType.postUpdated:
        return Icons.edit;
      case ActivityType.postDeleted:
        return Icons.delete;
      case ActivityType.commentCreated:
        return Icons.comment;
      case ActivityType.commentDeleted:
        return Icons.delete_outline;
      case ActivityType.profileUpdated:
        return Icons.account_circle;
      case ActivityType.passwordChanged:
        return Icons.lock;
      case ActivityType.postSaved:
        return Icons.bookmark_add;
      case ActivityType.postUnsaved:
        return Icons.bookmark_remove;
      case ActivityType.postUpvoted:
        return Icons.thumb_up;
      case ActivityType.postDownvoted:
        return Icons.thumb_down;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.login:
      case ActivityType.register:
        return AppTheme.successColor;
      case ActivityType.logout:
        return AppTheme.warningColor;
      case ActivityType.postDeleted:
      case ActivityType.commentDeleted:
        return AppTheme.errorColor;
      case ActivityType.postCreated:
      case ActivityType.commentCreated:
        return Colors.blue;
      case ActivityType.postSaved:
        return Colors.purple;
      case ActivityType.postUpvoted:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}