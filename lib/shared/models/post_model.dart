import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoURL;
  final String title;
  final String content;
  final String category;
  final List<String> tags;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final int viewCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isEdited;
  final bool isPinned;
  final bool isLocked;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoURL,
    required this.title,
    required this.content,
    required this.category,
    this.tags = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.isEdited = false,
    this.isPinned = false,
    this.isLocked = false,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Anonymous',
      authorPhotoURL: data['authorPhotoURL'],
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'General Discussion',
      tags: List<String>.from(data['tags'] ?? []),
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      isEdited: data['isEdited'] ?? false,
      isPinned: data['isPinned'] ?? false,
      isLocked: data['isLocked'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoURL': authorPhotoURL,
      'title': title,
      'content': content,
      'category': category,
      'tags': tags,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'commentCount': commentCount,
      'viewCount': viewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isEdited': isEdited,
      'isPinned': isPinned,
      'isLocked': isLocked,
    };
  }

  int get score => upvotes - downvotes;
}
