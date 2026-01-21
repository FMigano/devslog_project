import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class SavedPostsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save a post - UPDATED to match FirestoreService
  Future<void> savePost(String userId, String postId) async {
    await _firestore
        .collection('bookmarks')
        .doc('${userId}_$postId')
        .set({
      'userId': userId,
      'postId': postId,
      'savedAt': FieldValue.serverTimestamp(),
    });

    // Increment saved count on post
    await _firestore.collection('posts').doc(postId).update({
      'savedCount': FieldValue.increment(1),
    });
  }

  // Unsave a post - UPDATED
  Future<void> unsavePost(String userId, String postId) async {
    await _firestore
        .collection('bookmarks')
        .doc('${userId}_$postId')
        .delete();

    // Decrement saved count on post
    await _firestore.collection('posts').doc(postId).update({
      'savedCount': FieldValue.increment(-1),
    });
  }

  // Check if post is saved - UPDATED
  Future<bool> isPostSaved(String userId, String postId) async {
    final doc = await _firestore
        .collection('bookmarks')
        .doc('${userId}_$postId')
        .get();
    
    return doc.exists;
  }

  // Get saved posts stream - UPDATED to avoid index requirement
  Stream<List<PostModel>> getSavedPostsStream(String userId) {
    return _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<PostModel> posts = [];
      
      // Get all bookmark documents
      for (var doc in snapshot.docs) {
        try {
          final postId = doc.data()['postId'];
          final postDoc = await _firestore.collection('posts').doc(postId).get();
          
          if (postDoc.exists) {
            posts.add(PostModel.fromFirestore(postDoc));
          }
        } catch (e) {
          print('Error loading bookmarked post: $e');
        }
      }
      
      // Sort in memory by savedAt (descending)
      posts.sort((a, b) {
        final aData = snapshot.docs.firstWhere((d) => d.data()['postId'] == a.id).data();
        final bData = snapshot.docs.firstWhere((d) => d.data()['postId'] == b.id).data();
        
        final aTime = aData['savedAt'] as Timestamp?;
        final bTime = bData['savedAt'] as Timestamp?;
        
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      
      return posts;
    });
  }

  // Get saved posts count - UPDATED
  Future<int> getSavedPostsCount(String userId) async {
    final snapshot = await _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .get();
    
    return snapshot.docs.length;
  }
}