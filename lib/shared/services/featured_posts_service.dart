import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';

class FeaturedPostsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auto-feature posts based on views (most viewed posts)
  Future<void> updateFeaturedPosts() async {
    // Get top 5 most viewed posts from last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final postsSnapshot = await _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('createdAt', descending: true)
        .orderBy('views', descending: true)
        .limit(100)
        .get();

    // Calculate feature score for each post
    Map<String, double> postScores = {};
    
    for (var doc in postsSnapshot.docs) {
      final data = doc.data();
      final views = data['views'] ?? 0;
      final upvotes = data['upvotes'] ?? 0;
      final commentCount = data['commentCount'] ?? 0;
      final savedCount = data['savedCount'] ?? 0;
      
      // Feature score formula: views * 1 + upvotes * 10 + comments * 5 + saves * 15
      final score = (views * 1.0) + (upvotes * 10.0) + (commentCount * 5.0) + (savedCount * 15.0);
      postScores[doc.id] = score;
    }

    // Sort by score
    var sortedPosts = postScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 and mark as featured
    final top5 = sortedPosts.take(5).map((e) => e.key).toList();

    // Update posts
    final batch = _firestore.batch();
    
    // First, unfeatured all posts
    final allFeatured = await _firestore
        .collection('posts')
        .where('isFeatured', isEqualTo: true)
        .get();
    
    for (var doc in allFeatured.docs) {
      batch.update(doc.reference, {'isFeatured': false});
    }

    // Then feature the top 5
    for (var postId in top5) {
      batch.update(
        _firestore.collection('posts').doc(postId),
        {
          'isFeatured': true,
          'featuredAt': FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  // Get featured posts
  Stream<List<PostModel>> getFeaturedPostsStream() {
    return _firestore
        .collection('posts')
        .where('isFeatured', isEqualTo: true)
        .where('isApproved', isEqualTo: true)
        .orderBy('views', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList());
  }

  // Manually feature a post (admin)
  Future<void> featurePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'isFeatured': true,
      'featuredAt': FieldValue.serverTimestamp(),
    });
  }

  // Unfeature a post (admin)
  Future<void> unfeaturePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'isFeatured': false,
    });
  }

  // Get featured posts count
  Future<int> getFeaturedPostsCount() async {
    final snapshot = await _firestore
        .collection('posts')
        .where('isFeatured', isEqualTo: true)
        .count()
        .get();
    
    return snapshot.count ?? 0;
  }

  // Get top upvoted posts - UPDATED to avoid compound index
  Stream<List<PostModel>> getTopUpvotedPosts({int limit = 3}) {
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      // Get all approved posts
      var posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
      
      // Sort in memory by upvotes (descending)
      posts.sort((a, b) => b.upvotes.compareTo(a.upvotes));
      
      // Take top N posts
      return posts.take(limit).toList();
    });
  }

  // Alternative: Get posts by engagement score
  Stream<List<PostModel>> getBestEngagementPosts({int limit = 3}) {
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      var posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
      
      // Calculate engagement score: upvotes * 2 + comments * 1.5 + views * 0.1
      posts.sort((a, b) {
        final scoreA = (a.upvotes * 2) + (a.commentCount * 1.5) + (a.views * 0.1);
        final scoreB = (b.upvotes * 2) + (b.commentCount * 1.5) + (b.views * 0.1);
        return scoreB.compareTo(scoreA);
      });
      
      return posts.take(limit).toList();
    });
  }

  // Get most viewed posts (another alternative)
  Stream<List<PostModel>> getMostViewedPosts({int limit = 3}) {
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      var posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
      
      // Sort by views
      posts.sort((a, b) => b.views.compareTo(a.views));
      
      return posts.take(limit).toList();
    });
  }

  // Get recent popular posts (created in last 7 days with good engagement)
  Stream<List<PostModel>> getRecentPopularPosts({int limit = 3}) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .snapshots()
        .map((snapshot) {
      var posts = snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
      
      // Sort by engagement
      posts.sort((a, b) {
        final scoreA = (a.upvotes * 2) + (a.commentCount * 1.5);
        final scoreB = (b.upvotes * 2) + (b.commentCount * 1.5);
        return scoreB.compareTo(scoreA);
      });
      
      return posts.take(limit).toList();
    });
  }
}