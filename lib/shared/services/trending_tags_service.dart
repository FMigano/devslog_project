import 'package:cloud_firestore/cloud_firestore.dart';

class TrendingTagsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get trending tags from actual posts
  Future<List<Map<String, dynamic>>> getTrendingTags({int limit = 10}) async {
    try {
      // Get all approved posts
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('isApproved', isEqualTo: true)
          .get();

      // Count tag occurrences
      final Map<String, int> tagCounts = {};
      
      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        final tags = data['tags'] as List<dynamic>?;
        
        if (tags != null) {
          for (var tag in tags) {
            final tagStr = tag.toString().toLowerCase().trim();
            if (tagStr.isNotEmpty) {
              tagCounts[tagStr] = (tagCounts[tagStr] ?? 0) + 1;
            }
          }
        }
      }

      // Convert to list and sort by count
      final trendingTags = tagCounts.entries
          .map((entry) => {
                'tag': entry.key,
                'count': entry.value,
              })
          .toList();

      // Sort by count (descending) and limit results
      trendingTags.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return trendingTags.take(limit).toList();
    } catch (e) {
      print('Error fetching trending tags: $e');
      return [];
    }
  }

  /// Get trending tags as a stream (real-time updates)
  Stream<List<Map<String, dynamic>>> getTrendingTagsStream({int limit = 10}) {
    return _firestore
        .collection('posts')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      // Count tag occurrences
      final Map<String, int> tagCounts = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final tags = data['tags'] as List<dynamic>?;
        
        if (tags != null) {
          for (var tag in tags) {
            final tagStr = tag.toString().toLowerCase().trim();
            if (tagStr.isNotEmpty) {
              tagCounts[tagStr] = (tagCounts[tagStr] ?? 0) + 1;
            }
          }
        }
      }

      // Convert to list and sort by count
      final trendingTags = tagCounts.entries
          .map((entry) => {
                'tag': entry.key,
                'count': entry.value,
              })
          .toList();

      // Sort by count (descending) and limit results
      trendingTags.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return trendingTags.take(limit).toList();
    });
  }

  /// Get tags for a specific category
  Future<List<Map<String, dynamic>>> getTagsByCategory(
    String category, {
    int limit = 10,
  }) async {
    try {
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('isApproved', isEqualTo: true)
          .where('category', isEqualTo: category)
          .get();

      final Map<String, int> tagCounts = {};
      
      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        final tags = data['tags'] as List<dynamic>?;
        
        if (tags != null) {
          for (var tag in tags) {
            final tagStr = tag.toString().toLowerCase().trim();
            if (tagStr.isNotEmpty) {
              tagCounts[tagStr] = (tagCounts[tagStr] ?? 0) + 1;
            }
          }
        }
      }

      final trendingTags = tagCounts.entries
          .map((entry) => {
                'tag': entry.key,
                'count': entry.value,
              })
          .toList();

      trendingTags.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return trendingTags.take(limit).toList();
    } catch (e) {
      print('Error fetching tags by category: $e');
      return [];
    }
  }
}