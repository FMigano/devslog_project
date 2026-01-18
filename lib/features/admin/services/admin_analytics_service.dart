import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/post_model.dart';
import '../models/chart_data_model.dart';

class AdminAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, int>> getCategoryDistribution() async {
    try {
      final postsSnapshot = await _firestore.collection('posts').get();
      final Map<String, int> categoryCount = {};

      for (var doc in postsSnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        categoryCount[post.category] = (categoryCount[post.category] ?? 0) + 1;
      }

      return categoryCount;
    } catch (e) {
      throw Exception('Failed to get category distribution: $e');
    }
  }

  Future<List<ChartDataModel>> getMonthlyActivity() async {
    try {
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);

      final postsSnapshot = await _firestore
          .collection('posts')
          .where('createdAt', isGreaterThanOrEqualTo: sixMonthsAgo)
          .get();

      final Map<String, int> monthlyCount = {};
      
      for (var doc in postsSnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        final monthKey = '${post.createdAt.year}-${post.createdAt.month.toString().padLeft(2, '0')}';
        monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
      }

      final List<ChartDataModel> data = [];
      for (var i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        data.add(ChartDataModel(
          label: _getMonthName(date.month),
          value: monthlyCount[monthKey]?.toDouble() ?? 0,
        ));
      }

      return data;
    } catch (e) {
      throw Exception('Failed to get monthly activity: $e');
    }
  }

  Future<List<ChartDataModel>> getUserGrowth() async {
    try {
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);

      final usersSnapshot = await _firestore
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: sixMonthsAgo)
          .get();

      final Map<String, int> monthlyCount = {};
      
      for (var doc in usersSnapshot.docs) {
        final createdAt = (doc.data()['createdAt'] as Timestamp).toDate();
        final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
      }

      final List<ChartDataModel> data = [];
      for (var i = 5; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        data.add(ChartDataModel(
          label: _getMonthName(date.month),
          value: monthlyCount[monthKey]?.toDouble() ?? 0,
        ));
      }

      return data;
    } catch (e) {
      throw Exception('Failed to get user growth: $e');
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<Map<String, dynamic>> getEngagementMetrics() async {
    try {
      final postsSnapshot = await _firestore.collection('posts').get();
      
      int totalUpvotes = 0;
      int totalDownvotes = 0;
      int totalComments = 0;
      int totalViews = 0;

      for (var doc in postsSnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        totalUpvotes += post.upvotes;
        totalDownvotes += post.downvotes;
        totalComments += post.commentCount;
        totalViews += post.views;
      }

      final avgEngagement = postsSnapshot.docs.isEmpty
          ? 0.0
          : (totalUpvotes + totalComments) / postsSnapshot.docs.length;

      return {
        'totalUpvotes': totalUpvotes,
        'totalDownvotes': totalDownvotes,
        'totalComments': totalComments,
        'totalViews': totalViews,
        'avgEngagement': avgEngagement.toStringAsFixed(2),
      };
    } catch (e) {
      throw Exception('Failed to get engagement metrics: $e');
    }
  }
}