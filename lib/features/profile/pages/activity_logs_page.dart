import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/activity_log_service.dart';
import '../../../shared/models/activity_log_model.dart';

class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  State<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage> {
  final ActivityLogService _activityService = ActivityLogService();
  ActivityType? _filterType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: Text(
            'Please login to view activity',
            style: TextStyle(color: AppTheme.darkTextPrimary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Activity History'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportActivity(userId),
            tooltip: 'Export',
          ),
        ],
      ),
      body: Column(
        children: [
          // Activity Summary Card
          _buildSummaryCard(userId),

          // Filters
          if (_showFilters) _buildFiltersPanel(),

          // Activity List
          Expanded(
            child: StreamBuilder<List<ActivityLogModel>>(
              stream: _activityService.getUserActivityStream(
                userId,
                filterType: _filterType,
                startDate: _startDate,
                endDate: _endDate,
                limit: 100,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading activity',
                          style: TextStyle(color: AppTheme.darkTextPrimary, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: AppTheme.darkTextSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No activity yet',
                          style: TextStyle(
                            color: AppTheme.darkTextPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your activity history will appear here',
                          style: TextStyle(color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ),
                  );
                }

                final activities = snapshot.data!;
                final groupedActivities = _groupActivitiesByDate(activities);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedActivities.length,
                  itemBuilder: (context, index) {
                    final dateKey = groupedActivities.keys.elementAt(index);
                    final dateActivities = groupedActivities[dateKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Text(
                            _formatDateHeader(dateKey),
                            style: TextStyle(
                              color: AppTheme.darkPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...dateActivities.map((activity) => _buildActivityItem(activity)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _activityService.getUserActivitySummary(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final summary = snapshot.data!;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.darkPrimary.withOpacity(0.2),
                AppTheme.darkSurfaceVariant,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.darkDivider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, color: AppTheme.darkPrimary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Activity Summary',
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Today', summary['today'], Colors.green),
                  _buildSummaryItem('This Week', summary['week'], Colors.blue),
                  _buildSummaryItem('This Month', summary['month'], Colors.purple),
                  _buildSummaryItem('Total', summary['total'], Colors.orange),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: TextStyle(
              color: AppTheme.darkTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', _filterType == null, () {
                setState(() => _filterType = null);
              }),
              ...ActivityType.values.map((type) {
                return _buildFilterChip(
                  _getActivityTypeLabel(type),
                  _filterType == type,
                  () => setState(() => _filterType = type),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_startDate != null 
                    ? DateFormat('MMM d, y').format(_startDate!)
                    : 'Start Date'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: _startDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_endDate != null 
                    ? DateFormat('MMM d, y').format(_endDate!)
                    : 'End Date'),
                ),
              ),
              if (_startDate != null || _endDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _startDate = null;
                    _endDate = null;
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.darkPrimary : AppTheme.darkSurfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.darkPrimary : AppTheme.darkDivider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.darkTextSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(ActivityLogModel activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkDivider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getActivityColor(activity.type).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getActivityIcon(activity.type),
            color: _getActivityColor(activity.type),
            size: 24,
          ),
        ),
        title: Text(
          activity.description,
          style: TextStyle(
            color: AppTheme.darkTextPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AppTheme.darkTextSecondary),
                  const SizedBox(width: 4),
                  Text(
                    timeago.format(activity.createdAt),
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (activity.deviceInfo != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.devices, size: 14, color: AppTheme.darkTextSecondary),
                    const SizedBox(width: 4),
                    Text(
                      activity.deviceInfo!,
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(activity.status).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getStatusColor(activity.status)),
          ),
          child: Text(
            activity.status.toString().split('.').last.toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(activity.status),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, List<ActivityLogModel>> _groupActivitiesByDate(List<ActivityLogModel> activities) {
    final Map<String, List<ActivityLogModel>> grouped = {};
    
    for (var activity in activities) {
      final dateKey = DateFormat('yyyy-MM-dd').format(activity.createdAt);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(activity);
    }
    
    return grouped;
  }

  String _formatDateHeader(String dateKey) {
    final date = DateTime.parse(dateKey);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date.isAtSameMomentAs(today)) {
      return 'TODAY';
    } else if (date.isAtSameMomentAs(yesterday)) {
      return 'YESTERDAY';
    } else {
      return DateFormat('MMMM d, yyyy').format(date).toUpperCase();
    }
  }

  String _getActivityTypeLabel(ActivityType type) {
    switch (type) {
      case ActivityType.login:
        return 'Login';
      case ActivityType.logout:
        return 'Logout';
      case ActivityType.postCreated:
        return 'Posts';
      case ActivityType.commentCreated:
        return 'Comments';
      default:
        return type.toString().split('.').last;
    }
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

  Color _getStatusColor(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.success:
        return Colors.green;
      case ActivityStatus.failed:
        return Colors.red;
      case ActivityStatus.pending:
        return Colors.orange;
      case ActivityStatus.warning:
        return Colors.yellow;
    }
  }

  Future<void> _exportActivity(String userId) async {
    try {
      final data = await _activityService.exportUserActivity(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${data.length} activity logs'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}