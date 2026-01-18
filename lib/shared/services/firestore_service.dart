import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Posts
  Stream<List<PostModel>> getPosts({String? category, int limit = 20}) {
    Query query = _firestore.collection('posts');
    
    if (category != null && category != 'All' && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category).limit(limit);
      
      return query.snapshots().map((snapshot) {
        final posts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return posts;
      });
    }
    
    return query
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  Stream<List<PostModel>> getPostsByCategories(List<String> categories, {int limit = 20}) {
    if (categories.isEmpty || categories.contains('All')) {
      return getPosts(limit: limit);
    }

    return _firestore
        .collection('posts')
        .where('category', whereIn: categories)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  Stream<List<PostModel>> getPostsByTag(String tag, {int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  Future<PostModel?> getPost(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return PostModel.fromFirestore(doc);
  }

  // Stream for real-time post updates
  Stream<PostModel?> getPostStream(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PostModel.fromFirestore(doc);
    });
  }

  Future<String> createPost(PostModel post) async {
    try {
      print('FirestoreService: Creating post...');
      
      final postData = post.toFirestore();
      print('FirestoreService: Post data prepared');
      print('FirestoreService: Category = ${postData['category']}');
      
      if (!postData.containsKey('category') || postData['category'] == null || postData['category'].toString().isEmpty) {
        postData['category'] = 'General';
        print('FirestoreService: Category set to General');
      }
      
      print('FirestoreService: Adding to Firestore...');
      final docRef = await _firestore.collection('posts').add(postData);
      print('FirestoreService: Post added with ID: ${docRef.id}');
      
      print('FirestoreService: Updating user post count...');
      await _firestore.collection('users').doc(post.authorId).update({
        'postCount': FieldValue.increment(1),
      });
      print('FirestoreService: User post count updated');
      
      return docRef.id;
    } catch (e, stackTrace) {
      print('FirestoreService ERROR: $e');
      print('FirestoreService STACK: $stackTrace');
      rethrow;
    }
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
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs.map((doc) {
        try {
          return CommentModel.fromFirestore(doc);
        } catch (e) {
          return null;
        }
      }).whereType<CommentModel>().toList();
      
      // Sort by createdAt in ascending order (oldest first)
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      return comments;
    });
  }

  Future<void> addComment(CommentModel comment) async {
    try {
      final commentData = comment.toFirestore();
      await _firestore.collection('comments').add(commentData);
      
      // Increment comment count
      await _firestore.collection('posts').doc(comment.postId).update({
        'commentCount': FieldValue.increment(1),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId, String postId, String authorId) async {
    try {
      final authService = AuthService();
      final currentUser = await authService.getCurrentUserData();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final commentDoc = await _firestore.collection('comments').doc(commentId).get();
      
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentAuthorId = commentDoc.data()?['authorId'];
      
      // Check if user is the author or admin
      if (currentUser.uid != commentAuthorId && !currentUser.isAdmin) {
        throw Exception('Not authorized to delete this comment');
      }

      await _firestore.collection('comments').doc(commentId).delete();
      
      // Decrement comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Votes
  Future<bool?> getUserVote(String postId, String userId) async {
    try {
      final voteDoc = await _firestore.collection('votes').doc('${userId}_$postId').get();
      if (!voteDoc.exists) return null;
      return voteDoc.data()?['isUpvote'] as bool?;
    } catch (e) {
      return null;
    }
  }

  Stream<bool?> getUserVoteStream(String postId, String userId) {
    return _firestore.collection('votes').doc('${userId}_$postId').snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data()?['isUpvote'] as bool?;
    });
  }

  Future<void> votePost(String postId, String userId, bool isUpvote) async {
    try {
      final voteRef = _firestore.collection('votes').doc('${userId}_$postId');
      final postRef = _firestore.collection('posts').doc(postId);
      
      // Get current post data to ensure fields exist
      final postDoc = await postRef.get();
      if (!postDoc.exists) {
        throw Exception('Post not found');
      }
      
      final postData = postDoc.data()!;
      final currentUpvotes = postData['upvotes'] ?? 0;
      final currentDownvotes = postData['downvotes'] ?? 0;
      
      final voteDoc = await voteRef.get();

      if (voteDoc.exists) {
        final data = voteDoc.data()!;
        final wasUpvote = data['isUpvote'] as bool;

        if (wasUpvote == isUpvote) {
          // Remove vote - user clicked same button again
          await voteRef.delete();
          
          if (isUpvote) {
            await postRef.update({
              'upvotes': currentUpvotes > 0 ? currentUpvotes - 1 : 0,
            });
          } else {
            await postRef.update({
              'downvotes': currentDownvotes > 0 ? currentDownvotes - 1 : 0,
            });
          }
        } else {
          // Change vote - user clicked opposite button
          await voteRef.update({
            'isUpvote': isUpvote,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          if (isUpvote) {
            await postRef.update({
              'upvotes': currentUpvotes + 1,
              'downvotes': currentDownvotes > 0 ? currentDownvotes - 1 : 0,
            });
          } else {
            await postRef.update({
              'upvotes': currentUpvotes > 0 ? currentUpvotes - 1 : 0,
              'downvotes': currentDownvotes + 1,
            });
          }
        }
      } else {
        // New vote
        await voteRef.set({
          'userId': userId,
          'postId': postId,
          'isUpvote': isUpvote,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        if (isUpvote) {
          await postRef.update({
            'upvotes': currentUpvotes + 1,
          });
        } else {
          await postRef.update({
            'downvotes': currentDownvotes + 1,
          });
        }
      }
    } catch (e) {
      rethrow;
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

  // Search
  Future<List<PostModel>> searchPosts(String query) async {
    if (query.isEmpty) return [];
    
    final queryLower = query.toLowerCase();
    
    // Search by title
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    
    final posts = snapshot.docs
        .map((doc) => PostModel.fromFirestore(doc))
        .where((post) =>
            post.title.toLowerCase().contains(queryLower) ||
            post.content.toLowerCase().contains(queryLower) ||
            post.tags.any((tag) => tag.toLowerCase().contains(queryLower)))
        .toList();
    
    return posts;
  }

  // Get available categories
  Future<List<String>> getCategories() async {
    final snapshot = await _firestore.collection('posts').get();
    final categories = <String>{};
    
    for (var doc in snapshot.docs) {
      final category = doc.data()['category'] as String?;
      if (category != null && category.isNotEmpty) {
        categories.add(category);
      }
    }
    
    return categories.toList()..sort();
  }

  // Migration: Ensure all posts have vote fields
  Future<void> migratePostsVoteFields() async {
    try {
      final postsSnapshot = await _firestore.collection('posts').get();
      
      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        
        // Check if vote fields are missing
        if (!data.containsKey('upvotes') || !data.containsKey('downvotes')) {
          await doc.reference.update({
            'upvotes': data['upvotes'] ?? 0,
            'downvotes': data['downvotes'] ?? 0,
          });
        }
      }
    } catch (e) {
      // Migration failed silently
    }
  }
}
