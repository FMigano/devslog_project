import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/models/post_model.dart'; // Added missing import

class PostApprovalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Get pending posts
  Stream<List<Map<String, dynamic>>> getPendingPostsStream() {
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: false)
        .where('isRejected', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return {
                'id': doc.id,
                ...doc.data(),
              };
            }).toList());
  }

  // Approve post
  Future<void> approvePost({
    required String postId,
    required String adminId,
    required String adminName,
    String? feedback,
  }) async {
    try {
      // Get post data first
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final post = PostModel.fromFirestore(postDoc);

      await _firestore.collection('posts').doc(postId).update({
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
        'approverName': adminName,
        'adminFeedback': feedback ?? 'Your post has been approved',
      });

      // Send notification to post author
      await _notificationService.createNotification(
        userId: post.authorId,
        title: '✅ Post Approved',
        message: 'Your post "${post.title}" has been approved!',
        type: 'admin',
        postId: postId,
      );

      print('✅ Post approved: $postId');
    } catch (e) {
      print('❌ Error approving post: $e');
      rethrow;
    }
  }

  // Reject post
  Future<void> rejectPost({
    required String postId,
    required String adminId,
    required String adminName,
    required String reason,
  }) async {
    try {
      // Get post data first
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final post = PostModel.fromFirestore(postDoc);

      await _firestore.collection('posts').doc(postId).update({
        'isRejected': true,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': adminId,
        'rejecterName': adminName,
        'rejectionReason': reason,
      });

      // Send notification to post author
      await _notificationService.createNotification(
        userId: post.authorId,
        title: '❌ Post Rejected',
        message: 'Your post "${post.title}" was rejected: $reason',
        type: 'admin',
        postId: postId,
      );

      print('❌ Post rejected: $postId');
    } catch (e) {
      print('❌ Error rejecting post: $e');
      rethrow;
    }
  }

  // Get pending count
  Future<int> getPendingPostsCount() async {
    final snapshot = await _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: false)
        .where('isRejected', isEqualTo: false)
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }

  // Get approved posts count
  Future<int> getApprovedPostsCount() async {
    final snapshot = await _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }

  // Get rejected posts count
  Future<int> getRejectedPostsCount() async {
    final snapshot = await _firestore
        .collection('posts')
        .where('isRejected', isEqualTo: true)
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }
}