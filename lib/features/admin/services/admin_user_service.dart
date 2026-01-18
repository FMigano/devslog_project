import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/models/user_model.dart';

class AdminUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<UserModel>> getUsersStream() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  Future<void> deleteUser(String userId) async {
    try {
      // Delete user's posts
      final userPosts = await _firestore
          .collection('posts')
          .where('authorId', isEqualTo: userId)
          .get();
      
      for (var doc in userPosts.docs) {
        await doc.reference.delete();
      }

      // Delete user's comments
      final userComments = await _firestore
          .collection('comments')
          .where('authorId', isEqualTo: userId)
          .get();
      
      for (var doc in userComments.docs) {
        await doc.reference.delete();
      }

      // Delete user document
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  Future<void> banUser(String userId, bool banned) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': banned,
        'bannedAt': banned ? FieldValue.serverTimestamp() : null,
      });
    } catch (e) {
      throw Exception('Failed to ban/unban user: $e');
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int totalUsers = usersSnapshot.docs.length;
      int activeToday = 0;
      int admins = 0;

      for (var doc in usersSnapshot.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.isAdmin) admins++;
        
        // Check if user was active today (you'd need to track lastActive in your user model)
        if (user.createdAt.isAfter(today)) {
          activeToday++;
        }
      }

      return {
        'totalUsers': totalUsers,
        'activeToday': activeToday,
        'admins': admins,
      };
    } catch (e) {
      throw Exception('Failed to get user stats: $e');
    }
  }
}