import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorPhotoURL;
  final String content;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;

  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoURL,
    required this.content,
    this.upvotes = 0,
    this.downvotes = 0,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorPhotoURL: data['authorPhotoURL'],
      content: data['content'] ?? '',
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      isEdited: data['isEdited'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoURL': authorPhotoURL,
      'content': content,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isEdited': isEdited,
    };
  }
}
