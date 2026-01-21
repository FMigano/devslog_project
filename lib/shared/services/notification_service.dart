import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? postId;
  final String? commentId;
  final String? fromUserId;
  final String? fromUserName;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.postId,
    this.commentId,
    this.fromUserId,
    this.fromUserName,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      postId: data['postId'],
      commentId: data['commentId'],
      fromUserId: data['fromUserId'],
      fromUserName: data['fromUserName'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      data: data['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'postId': postId,
      'commentId': commentId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'data': data,
    };
  }
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⭐ FIXED: Simple query without compound index
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      // Sort in memory instead of Firestore
      var notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();

      // Sort by createdAt descending
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Limit to 50 most recent
      return notifications.take(50).toList();
    });
  }

  // Get unread count stream - FIXED
  Stream<int> getUnreadCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Create notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? postId,
    String? commentId,
    String? fromUserId,
    String? fromUserName,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Don't send notification to yourself
      if (userId == fromUserId) return;

      final notification = NotificationModel(
        id: '',
        userId: userId,
        title: title,
        message: message,
        type: type,
        postId: postId,
        commentId: commentId,
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        createdAt: DateTime.now(),
        data: data,
      );

      await _firestore.collection('notifications').add(notification.toFirestore());
      print('✅ Notification created for user: $userId - $title');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  // Mark as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all as read - FIXED
  Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      print('✅ All notifications marked as read for user: $userId');
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  // Delete all notifications for user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
    }
  }
}
