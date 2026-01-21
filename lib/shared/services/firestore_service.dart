import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Posts
  Stream<List<PostModel>> getPosts({String? category, int limit = 20}) {
    Query query = _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true) // ⭐ Only approved posts
        .orderBy('createdAt', descending: true);

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return query.limit(limit).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    });
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

  Future<void> deletePost(String postId) async {
    try {
      print('🗑️ Deleting post: $postId');
      
      // Delete all comments for this post
      final commentsSnapshot = await _firestore
          .collection('comments')
          .where('postId', isEqualTo: postId)
          .get();
      
      for (var doc in commentsSnapshot.docs) {
        // Delete all replies for each comment
        final repliesSnapshot = await _firestore
            .collection('comments')
            .doc(doc.id)
            .collection('replies')
            .get();
        
        for (var replyDoc in repliesSnapshot.docs) {
          await replyDoc.reference.delete();
        }
        
        // Delete the comment
        await doc.reference.delete();
      }
      
      // Delete all votes for this post
      final votesSnapshot = await _firestore
          .collection('votes')
          .where('postId', isEqualTo: postId)
          .get();
      
      for (var doc in votesSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Delete all bookmarks for this post
      final bookmarksSnapshot = await _firestore
          .collection('bookmarks')
          .where('postId', isEqualTo: postId)
          .get();
      
      for (var doc in bookmarksSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // Finally, delete the post itself
      await _firestore.collection('posts').doc(postId).delete();
      
      print('✅ Post and all related data deleted');
    } catch (e) {
      print('❌ Error deleting post: $e');
      rethrow;
    }
  }

  Future<void> incrementPostView(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'views': FieldValue.increment(1), // ← Changed from 'viewCount' to 'views'
    });
  }

  // Comments - Read from ROOT collection (where they currently are)
  Stream<List<CommentModel>> getComments(String postId) {
    print('📥 Getting comments for post: $postId');
    return _firestore
        .collection('comments')  // ← ROOT collection, not subcollection
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      print('📊 Comments snapshot size: ${snapshot.docs.length}');
      
      return snapshot.docs.map((doc) {
        try {
          print('📄 Processing comment: ${doc.id}');
          return CommentModel.fromFirestore(doc);
        } catch (e) {
          print('❌ Error parsing comment ${doc.id}: $e');
          return null;
        }
      })
      .whereType<CommentModel>()
      .toList();
    });
  }

  Future<void> addComment(CommentModel comment) async {
    try {
      print('➕ Adding comment to post: ${comment.postId}');
      
      // Add comment to ROOT collection (to match existing structure)
      final docRef = await _firestore
          .collection('comments')  // ← ROOT collection
          .add(comment.toMap());
      
      print('✅ Comment added with ID: ${docRef.id}');
      
      // Increment comment count on post
      await _firestore.collection('posts').doc(comment.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      // Get post author to send notification
      final postDoc = await _firestore.collection('posts').doc(comment.postId).get();
      if (postDoc.exists) {
        final postAuthorId = postDoc.data()?['authorId'];
        final postTitle = postDoc.data()?['title'];
        
        // Send notification to post author
        if (postAuthorId != null && postAuthorId != comment.authorId) {
          await _notificationService.createNotification(
            userId: postAuthorId,
            title: '💬 New Comment',
            message: '${comment.authorName} commented on your post "$postTitle"',
            type: 'comment',
            postId: comment.postId,
            commentId: docRef.id,
            fromUserId: comment.authorId,
            fromUserName: comment.authorName,
          );
        }
      }
    } catch (e) {
      print('❌ Error adding comment: $e');
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId, String postId, String authorId) async {
    try {
      print('🗑️ Deleting comment: $commentId from post: $postId');
      
      final authService = AuthService();
      final currentUser = await authService.getCurrentUserData();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get comment document from ROOT collection
      final commentDoc = await _firestore
          .collection('comments')  // ← ROOT collection
          .doc(commentId)
          .get();
      
      if (!commentDoc.exists) {
        throw Exception('Comment not found');
      }

      final commentAuthorId = commentDoc.data()?['authorId'];
      
      // Check if user is the author or admin
      if (currentUser.uid != commentAuthorId && !currentUser.isAdmin) {
        throw Exception('Not authorized to delete this comment');
      }

      // Delete the comment from ROOT collection
      await _firestore
          .collection('comments')  // ← ROOT collection
          .doc(commentId)
          .delete();
      
      // Decrement comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });
      
      print('✅ Comment deleted: $commentId');
    } catch (e) {
      print('❌ Error deleting comment: $e');
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
      final voteDoc = await voteRef.get();
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) return;

      final postAuthorId = postDoc.data()?['authorId'];
      final postTitle = postDoc.data()?['title'];
      final currentUserDoc = await _firestore.collection('users').doc(userId).get();
      final currentUserName = currentUserDoc.data()?['displayName'] ?? 'Someone';

      if (voteDoc.exists) {
        final currentVote = voteDoc.data()?['isUpvote'] as bool?;
        
        if (currentVote == isUpvote) {
          // Remove vote
          await voteRef.delete();
          await postRef.update({
            isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(-1),
          });
        } else {
          // Change vote
          await voteRef.set({
            'postId': postId,
            'userId': userId,
            'isUpvote': isUpvote,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          await postRef.update({
            'upvotes': FieldValue.increment(isUpvote ? 1 : -1),
            'downvotes': FieldValue.increment(isUpvote ? -1 : 1),
          });

          // Send notification on upvote
          if (isUpvote && postAuthorId != null && postAuthorId != userId) {
            await _notificationService.createNotification(
              userId: postAuthorId,
              title: '👍 New Upvote',
              message: '$currentUserName upvoted your post "$postTitle"',
              type: 'vote',
              postId: postId,
              fromUserId: userId,
              fromUserName: currentUserName,
            );
          }
        }
      } else {
        // New vote
        await voteRef.set({
          'postId': postId,
          'userId': userId,
          'isUpvote': isUpvote,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        await postRef.update({
          isUpvote ? 'upvotes' : 'downvotes': FieldValue.increment(1),
        });

        // Send notification on upvote
        if (isUpvote && postAuthorId != null && postAuthorId != userId) {
          await _notificationService.createNotification(
            userId: postAuthorId,
            title: '👍 New Upvote',
            message: '$currentUserName upvoted your post "$postTitle"',
            type: 'vote',
            postId: postId,
            fromUserId: userId,
            fromUserName: currentUserName,
          );
        }
      }
    } catch (e) {
      print('❌ Error voting post: $e');
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

  Future<void> addBookmark(String postId, String userId) async {
    try {
      final bookmarkRef = _firestore.collection('bookmarks').doc('${userId}_$postId');
      await bookmarkRef.set({
        'userId': userId,
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
      
      // Increment saved count
      await _firestore.collection('posts').doc(postId).update({
        'savedCount': FieldValue.increment(1),
      });
      
      print('✅ Bookmark added: $postId');
    } catch (e) {
      print('❌ Error adding bookmark: $e');
      rethrow;
    }
  }

  Future<void> removeBookmark(String postId, String userId) async {
    try {
      final bookmarkRef = _firestore.collection('bookmarks').doc('${userId}_$postId');
      await bookmarkRef.delete();
      
      // Decrement saved count
      await _firestore.collection('posts').doc(postId).update({
        'savedCount': FieldValue.increment(-1),
      });
      
      print('✅ Bookmark removed: $postId');
    } catch (e) {
      print('❌ Error removing bookmark: $e');
      rethrow;
    }
  }

  Future<bool> isBookmarked(String postId, String userId) async {
    try {
      final bookmarkRef = _firestore.collection('bookmarks').doc('${userId}_$postId');
      final doc = await bookmarkRef.get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking bookmark: $e');
      return false;
    }
  }

  Stream<List<PostModel>> getBookmarkedPosts(String userId) {
    return _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<PostModel> posts = [];
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

  // Add this migration method
  Future<void> migrateCommentsToSubcollection() async {
    try {
      print('🔄 Starting comment migration...');
      
      // Get all comments from root collection
      final rootComments = await _firestore.collection('comments').get();
      
      print('📊 Found ${rootComments.docs.length} comments to migrate');
      
      for (var doc in rootComments.docs) {
        final data = doc.data();
        final postId = data['postId'];
        
        if (postId != null) {
          // Copy to subcollection
          await _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(doc.id)
              .set(data);
          
          print('✅ Migrated comment ${doc.id} to post $postId');
        }
      }
      
      print('✅ Migration complete!');
    } catch (e) {
      print('❌ Migration error: $e');
    }
  }

  // Admin functions
  Stream<List<PostModel>> getPendingPosts({int limit = 50}) {
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: false)
        .where('isRejected', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<PostModel>> getFeaturedPosts({int limit = 5}) {
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .orderBy('views', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    });
  }
}
