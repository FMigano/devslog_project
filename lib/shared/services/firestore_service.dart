import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Posts
  Stream<List<PostModel>> getPosts({String? category, int limit = 20}) {
    Query query = _firestore.collection('posts').orderBy('createdAt', descending: true);
    
    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }
    
    return query.limit(limit).snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
    );
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromFirestore(doc);
  }

  Future<String> createPost(PostModel post) async {
    final docRef = await _firestore.collection('posts').add(post.toFirestore());
    
    await _firestore.collection('users').doc(post.authorId).update({
      'postCount': FieldValue.increment(1),
    });
    
    return docRef.id;
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    await _firestore.collection('posts').doc(postId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'isEdited': true,
    });
  }

  Future<void> deletePost(String postId, String authorId) async {
    await _firestore.collection('posts').doc(postId).delete();
    await _firestore.collection('users').doc(authorId).update({
      'postCount': FieldValue.increment(-1),
    });
    
    final comments = await _firestore.collection('comments')
        .where('postId', isEqualTo: postId)
        .get();
    
    for (var doc in comments.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> incrementPostView(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  // Comments
  Stream<List<CommentModel>> getComments(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CommentModel.fromFirestore(doc)).toList());
  }

  Future<void> addComment(CommentModel comment) async {
    await _firestore.collection('comments').add(comment.toFirestore());
    
    await _firestore.collection('posts').doc(comment.postId).update({
      'commentCount': FieldValue.increment(1),
    });
    
    await _firestore.collection('users').doc(comment.authorId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  Future<void> deleteComment(String commentId, String postId, String authorId) async {
    await _firestore.collection('comments').doc(commentId).delete();
    
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
    
    await _firestore.collection('users').doc(authorId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  // Votes
  Future<void> votePost(String postId, String userId, bool isUpvote) async {
    final voteRef = _firestore.collection('votes').doc('${userId}_$postId');
    final voteDoc = await voteRef.get();

    if (voteDoc.exists) {
      final data = voteDoc.data()!;
      final wasUpvote = data['isUpvote'] as bool;

      if (wasUpvote == isUpvote) {
        await voteRef.delete();
        await _firestore.collection('posts').doc(postId).update({
          isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(-1),
        });
      } else {
        await voteRef.update({'isUpvote': isUpvote});
        await _firestore.collection('posts').doc(postId).update({
          'upvotes': FieldValue.increment(isUpvote ? 1 : -1),
          'downvotes': FieldValue.increment(isUpvote ? -1 : 1),
        });
      }
    } else {
      await voteRef.set({
        'userId': userId,
        'postId': postId,
        'isUpvote': isUpvote,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('posts').doc(postId).update({
        isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(1),
      });
    }
  }

  // Bookmarks
  Future<void> toggleBookmark(String postId, String userId) async {
    final bookmarkRef = _firestore.collection('bookmarks').doc('${userId}_$postId');
    final doc = await bookmarkRef.get();

    if (doc.exists) {
      await bookmarkRef.delete();
    } else {
      await bookmarkRef.set({
        'userId': userId,
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> isBookmarked(String postId, String userId) async {
    final doc = await _firestore.collection('bookmarks').doc('${userId}_$postId').get();
    return doc.exists;
  }

  Stream<List<PostModel>> getBookmarkedPosts(String userId) {
    return _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<PostModel> posts = [];
      for (var doc in snapshot.docs) {
        final postId = doc.data()['postId'];
        final post = await getPost(postId);
        if (post != null) posts.add(post);
      }
      return posts;
    });
  }

  // User Management
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }
}
