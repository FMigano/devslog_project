import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'activity_log_service.dart'; // ← ADD THIS
import '../models/activity_log_model.dart'; // ← ADD THIS

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityLogService _activityService = ActivityLogService(); // ← ADD THIS

  // Get auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ⭐ ADD ACTIVITY LOGGING
      final user = await getCurrentUserData();
      if (user != null) {
        await _activityService.logActivity(
          userId: user.uid,
          userName: user.displayName,
          userEmail: user.email,
          type: ActivityType.login,
          description: 'User logged in',
          status: ActivityStatus.success,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      // ⭐ LOG FAILED ATTEMPTS
      await _activityService.logActivity(
        userId: '',
        userName: 'Unknown',
        userEmail: email,
        type: ActivityType.login,
        description: 'Failed login attempt: ${e.code}',
        status: ActivityStatus.failed,
      );
      throw Exception(_getAuthErrorMessage(e.code));
    }
  }

  // Register with email and password (alternative name)
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    return signUpWithEmailAndPassword(email, password, displayName);
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      final user = UserModel(
        uid: credential.user!.uid,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
        isEmailVerified: false,
      );

      await _firestore.collection('users').doc(credential.user!.uid).set(user.toFirestore());

      // ⭐ LOG REGISTRATION
      await _activityService.logActivity(
        userId: user.uid,
        userName: user.displayName,
        userEmail: user.email,
        type: ActivityType.register,
        description: 'New user registered',
        status: ActivityStatus.success,
      );

      await credential.user!.sendEmailVerification();

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    }
  }

  // Get current user data from Firestore
  Future<UserModel?> getCurrentUserData() async {
    try {
      if (currentUser == null) return null;

      final doc = await _firestore.collection('users').doc(currentUser!.uid).get();

      if (!doc.exists) return null;

      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    // ⭐ LOG BEFORE SIGNING OUT
    final user = await getCurrentUserData();
    if (user != null) {
      await _activityService.logActivity(
        userId: user.uid,
        userName: user.displayName,
        userEmail: user.email,
        type: ActivityType.logout,
        description: 'User logged out',
        status: ActivityStatus.success,
      );
    }

    await _auth.signOut();
  }

  // Reset password
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      final message = _getAuthErrorMessage(e.code);
      throw Exception(message);
    } catch (e) {
      throw Exception('Failed to send password reset email');
    }
  }

  // Get user-friendly error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      case 'user-disabled':
        return 'This account has been disabled';
      default:
        return 'An error occurred. Please try again';
    }
  }
}
