import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/post_model.dart';

class AdminPostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<PostModel>> getPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList());
  }

  Future<void> deletePost(String postId) async {
    try {
      // Delete all comments associated with the post
      final comments = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();
      
      for (var doc in comments.docs) {
        await doc.reference.delete();
      }

      // Delete the post
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  Future<void> togglePinPost(String postId, bool isPinned) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isPinned': isPinned,
        'pinnedAt': isPinned ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      throw Exception('Failed to pin/unpin post: $e');
    }
  }

  Future<void> featurePost(String postId, bool isFeatured) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isFeatured': isFeatured,
        'featuredAt': isFeatured ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      throw Exception('Failed to feature/unfeature post: $e');
    }
  }

  Future<Map<String, dynamic>> getPostStats() async {
    try {
      final postsSnapshot = await _firestore.collection('posts').get();
      final commentsSnapshot = await _firestore.collection('comments').get();

      int totalPosts = postsSnapshot.docs.length;
      int totalComments = commentsSnapshot.docs.length;
      int totalViews = 0;
      int pinnedPosts = 0;

      for (var doc in postsSnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        totalViews += post.views;
        if (post.isPinned) pinnedPosts++;
      }

      return {
        'totalPosts': totalPosts,
        'totalComments': totalComments,
        'totalViews': totalViews,
        'pinnedPosts': pinnedPosts,
      };
    } catch (e) {
      throw Exception('Failed to get post stats: $e');
    }
  }
}