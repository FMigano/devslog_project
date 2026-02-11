import 'package:cloud_firestore/cloud_firestore.dart';

class DuplicateDetectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Finds similar posts based on title, content, and tags
  /// Returns a list of similar posts with their similarity scores
  Future<List<Map<String, dynamic>>> findSimilarPosts({
    required String title,
    required String content,
    required List<String> tags,
    double threshold = 0.6,
  }) async {
    try {
      // Fetch all posts
      final snapshot = await _firestore
          .collection('posts')
          .where('status', isEqualTo: 'approved')
          .get();

      final similarPosts = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final postData = doc.data();
        final postTitle = postData['title'] as String? ?? '';
        final postContent = postData['content'] as String? ?? '';
        final postTags = List<String>.from(postData['tags'] ?? []);

        // Calculate similarity score
        final similarityScore = _calculateSimilarity(
          title: title,
          content: content,
          tags: tags,
          postTitle: postTitle,
          postContent: postContent,
          postTags: postTags,
        );

        // If similarity exceeds threshold, add to results
        if (similarityScore >= threshold) {
          similarPosts.add({
            'id': doc.id,
            'title': postTitle,
            'similarity': similarityScore,
            'tags': postTags,
            'authorName': postData['authorName'] ?? 'Unknown',
            'createdAt': postData['createdAt'],
          });
        }
      }

      // Sort by similarity score (highest first)
      similarPosts.sort((a, b) => 
        (b['similarity'] as double).compareTo(a['similarity'] as double)
      );

      return similarPosts;
    } catch (e) {
      print('Error finding similar posts: $e');
      return [];
    }
  }

  /// Calculate similarity score between two posts
  double _calculateSimilarity({
    required String title,
    required String content,
    required List<String> tags,
    required String postTitle,
    required String postContent,
    required List<String> postTags,
  }) {
    // Weight factors
    const titleWeight = 0.4;
    const contentWeight = 0.3;
    const tagWeight = 0.3;

    // Calculate title similarity (case-insensitive)
    final titleSimilarity = _calculateTextSimilarity(
      title.toLowerCase(),
      postTitle.toLowerCase(),
    );

    // Calculate content similarity (using first 500 chars, case-insensitive)
    final contentPreview = content.length > 500 
        ? content.substring(0, 500).toLowerCase() 
        : content.toLowerCase();
    final postContentPreview = postContent.length > 500 
        ? postContent.substring(0, 500).toLowerCase() 
        : postContent.toLowerCase();
    final contentSimilarity = _calculateTextSimilarity(
      contentPreview,
      postContentPreview,
    );

    // Calculate tag overlap
    final tagSimilarity = _calculateTagSimilarity(tags, postTags);

    // Weighted average
    return (titleSimilarity * titleWeight) +
           (contentSimilarity * contentWeight) +
           (tagSimilarity * tagWeight);
  }

  /// Calculate text similarity using Jaccard similarity
  double _calculateTextSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    // Tokenize (split by spaces and remove special chars)
    final words1 = text1
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();
    
    final words2 = text2
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    // Jaccard similarity: intersection / union
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    return intersection / union;
  }

  /// Calculate tag similarity (overlap ratio)
  double _calculateTagSimilarity(List<String> tags1, List<String> tags2) {
    if (tags1.isEmpty || tags2.isEmpty) return 0.0;

    final set1 = tags1.map((t) => t.toLowerCase()).toSet();
    final set2 = tags2.map((t) => t.toLowerCase()).toSet();

    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;

    return intersection / union;
  }
}