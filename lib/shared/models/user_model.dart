import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? bio;
  final String role;
  final List<String> badges;
  final int postCount;
  final int commentCount;
  final int reputation;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isEmailVerified;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.bio,
    this.role = 'user',
    this.badges = const [],
    this.postCount = 0,
    this.commentCount = 0,
    this.reputation = 0,
    required this.createdAt,
    this.lastSeen,
    this.isEmailVerified = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'Anonymous',
      photoURL: data['photoURL'],
      bio: data['bio'],
      role: data['role'] ?? 'user',
      badges: List<String>.from(data['badges'] ?? []),
      postCount: data['postCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      reputation: data['reputation'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastSeen: data['lastSeen'] != null ? (data['lastSeen'] as Timestamp).toDate() : null,
      isEmailVerified: data['isEmailVerified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'bio': bio,
      'role': role,
      'badges': badges,
      'postCount': postCount,
      'commentCount': commentCount,
      'reputation': reputation,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'isEmailVerified': isEmailVerified,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? photoURL,
    String? bio,
    List<String>? badges,
    int? postCount,
    int? commentCount,
    int? reputation,
    DateTime? lastSeen,
    bool? isEmailVerified,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      role: role,
      badges: badges ?? this.badges,
      postCount: postCount ?? this.postCount,
      commentCount: commentCount ?? this.commentCount,
      reputation: reputation ?? this.reputation,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  bool get isAdmin => role == 'admin';
}
