import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyModel {
  final String id;
  final String commentId;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorEmail;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int upvotes;
  final int downvotes;
  final List<String> upvotedBy;
  final List<String> downvotedBy;

  ReplyModel({
    required this.id,
    required this.commentId,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorEmail,
    this.authorPhotoUrl,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.upvotes = 0,
    this.downvotes = 0,
    this.upvotedBy = const [],
    this.downvotedBy = const [],
  });

  factory ReplyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReplyModel(
      id: doc.id,
      commentId: data['commentId'] ?? '',
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorEmail: data['authorEmail'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      upvotedBy: List<String>.from(data['upvotedBy'] ?? []),
      downvotedBy: List<String>.from(data['downvotedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'upvotedBy': upvotedBy,
      'downvotedBy': downvotedBy,
    };
  }

  ReplyModel copyWith({
    String? id,
    String? commentId,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorEmail,
    String? authorPhotoUrl,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? upvotes,
    int? downvotes,
    List<String>? upvotedBy,
    List<String>? downvotedBy,
  }) {
    return ReplyModel(
      id: id ?? this.id,
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      upvotedBy: upvotedBy ?? this.upvotedBy,
      downvotedBy: downvotedBy ?? this.downvotedBy,
    );
  }
}