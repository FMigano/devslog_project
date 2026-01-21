import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reply_model.dart';
import 'activity_log_service.dart';
import '../models/activity_log_model.dart';

class CommentReplyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityLogService _activityService = ActivityLogService();

  // Add reply to comment
  Future<void> addReply({
    required String postId,
    required String commentId,
    required ReplyModel reply,
  }) async {
    try {
      print('📝 Adding reply to comment $commentId');
      
      // Add reply to subcollection
      final docRef = await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .add(reply.toMap());

      print('✅ Reply added with ID: ${docRef.id}');

      // Increment reply count on comment
      await _firestore.collection('comments').doc(commentId).update({
        'replyCount': FieldValue.increment(1),
      });

      // Log activity
      await _activityService.logActivity(
        userId: reply.authorId,
        userName: reply.authorName,
        userEmail: reply.authorEmail,
        type: ActivityType.commentCreated,
        description: 'Replied to a comment',
        metadata: {
          'postId': postId,
          'commentId': commentId,
          'replyId': docRef.id,
        },
      );

    } catch (e) {
      print('❌ Error adding reply: $e');
      rethrow;
    }
  }

  // Get replies stream for real-time updates
  Stream<List<ReplyModel>> getRepliesStream(String postId, String commentId) {
    print('📥 Getting replies stream for comment: $commentId');
    
    return _firestore
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      print('📊 Replies snapshot size: ${snapshot.docs.length}');
      
      return snapshot.docs.map((doc) {
        try {
          return ReplyModel.fromFirestore(doc);
        } catch (e) {
          print('❌ Error parsing reply ${doc.id}: $e');
          return null;
        }
      })
      .whereType<ReplyModel>()
      .toList();
    });
  }

  // Delete reply with proper cleanup
  Future<void> deleteReply({
    required String postId,
    required String commentId,
    required String replyId,
    required String authorId,
  }) async {
    try {
      print('🗑️ Deleting reply $replyId from comment $commentId');
      
      // Delete reply from subcollection
      await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .doc(replyId)
          .delete();

      print('✅ Reply deleted from Firestore');

      // Decrement reply count on comment
      await _firestore.collection('comments').doc(commentId).update({
        'replyCount': FieldValue.increment(-1),
      });

      print('✅ Reply count decremented');
    } catch (e) {
      print('❌ Error deleting reply: $e');
      rethrow;
    }
  }

  // Get reply count for a comment
  Future<int> getReplyCount(String commentId) async {
    try {
      final snapshot = await _firestore
          .collection('comments')
          .doc(commentId)
          .collection('replies')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting reply count: $e');
      return 0;
    }
  }
}