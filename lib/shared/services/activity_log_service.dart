import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_log_model.dart';

class ActivityLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Log user activity with enhanced details
  Future<void> logActivity({
    required String userId,
    required String userName,
    required String userEmail,
    required ActivityType type,
    required String description,
    Map<String, dynamic>? metadata,
    ActivityStatus status = ActivityStatus.success,
    String? ipAddress,
    String? deviceInfo,
    String? location,
  }) async {
    final log = ActivityLogModel(
      id: '',
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      type: type,
      description: description,
      metadata: metadata,
      createdAt: DateTime.now(),
      ipAddress: ipAddress,
      deviceInfo: deviceInfo,
      location: location,
      status: status,
    );

    // Store only in global collection for easier querying
    await _firestore.collection('activity_logs').add(log.toMap());
  }

  // Get user activity with pagination
  Stream<List<ActivityLogModel>> getUserActivityStream(
    String userId, {
    int limit = 50,
    ActivityType? filterType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore
        .collection('activity_logs')
        .where('userId', isEqualTo: userId);

    if (filterType != null) {
      query = query.where('type', isEqualTo: filterType.toString().split('.').last);
    }

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityLogModel.fromFirestore(doc))
            .toList());
  }

  // Get all activity logs (admin only) with advanced filtering
  Stream<List<ActivityLogModel>> getAllActivityStream({
    int limit = 100,
    ActivityType? filterType,
    ActivityStatus? filterStatus,
    String? searchUserId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore.collection('activity_logs');

    if (filterType != null) {
      query = query.where('type', isEqualTo: filterType.toString().split('.').last);
    }

    if (filterStatus != null) {
      query = query.where('status', isEqualTo: filterStatus.toString().split('.').last);
    }

    if (searchUserId != null) {
      query = query.where('userId', isEqualTo: searchUserId);
    }

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityLogModel.fromFirestore(doc))
            .toList());
  }

  // Get activity count by type
  Future<Map<ActivityType, int>> getActivityCountByType(String userId) async {
    final snapshot = await _firestore
        .collection('activity_logs')
        .where('userId', isEqualTo: userId)
        .get();

    final Map<ActivityType, int> counts = {};
    for (var doc in snapshot.docs) {
      final log = ActivityLogModel.fromFirestore(doc);
      counts[log.type] = (counts[log.type] ?? 0) + 1;
    }

    return counts;
  }

  // Get activity summary for user
  Future<Map<String, dynamic>> getUserActivitySummary(String userId) async {
    final snapshot = await _firestore
        .collection('activity_logs')
        .where('userId', isEqualTo: userId)
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeek = now.subtract(const Duration(days: 7));
    final thisMonth = DateTime(now.year, now.month, 1);

    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;
    DateTime? lastActivity;

    for (var doc in snapshot.docs) {
      final log = ActivityLogModel.fromFirestore(doc);
      final logDate = log.createdAt;

      if (logDate.isAfter(today)) todayCount++;
      if (logDate.isAfter(thisWeek)) weekCount++;
      if (logDate.isAfter(thisMonth)) monthCount++;

      if (lastActivity == null || logDate.isAfter(lastActivity)) {
        lastActivity = logDate;
      }
    }

    return {
      'total': snapshot.docs.length,
      'today': todayCount,
      'week': weekCount,
      'month': monthCount,
      'lastActivity': lastActivity,
    };
  }

  // Clear old logs (for maintenance)
  Future<void> clearOldLogs({int daysToKeep = 90}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    final snapshot = await _firestore
        .collection('activity_logs')
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  // Export user activity logs
  Future<List<Map<String, dynamic>>> exportUserActivity(String userId) async {
    final snapshot = await _firestore
        .collection('activity_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}