import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String authorEmail;
  final String? authorPhotoUrl;
  final String? authorPhotoURL; // Added for compatibility
  final String category; // Added missing field
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int views;
  final int viewCount; // Added for compatibility
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final bool isPinned;
  final List<String> upvotedBy;
  final List<String> downvotedBy;
  
  // New fields
  final bool isApproved;
  final bool isRejected;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approverName;
  final String? adminFeedback;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final String? rejecterName;
  final String? rejectionReason;
  final bool isFeatured;
  final DateTime? featuredAt;
  final int savedCount;
  final int replyCount;

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorEmail,
    this.authorPhotoUrl,
    String? authorPhotoURL,
    this.category = 'General',
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.views = 0,
    int? viewCount,
    this.upvotes = 0,
    this.downvotes = 0,
    this.commentCount = 0,
    this.isPinned = false,
    this.upvotedBy = const [],
    this.downvotedBy = const [],
    this.isApproved = false,
    this.isRejected = false,
    this.approvedAt,
    this.approvedBy,
    this.approverName,
    this.adminFeedback,
    this.rejectedAt,
    this.rejectedBy,
    this.rejecterName,
    this.rejectionReason,
    this.isFeatured = false,
    this.featuredAt,
    this.savedCount = 0,
    this.replyCount = 0,
  }) : authorPhotoURL = authorPhotoURL ?? authorPhotoUrl,
       viewCount = viewCount ?? views;

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorEmail: data['authorEmail'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] ?? data['authorPhotoURL'],
      category: data['category'] ?? 'General',
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      views: data['views'] ?? 0,
      upvotes: data['upvotes'] ?? 0,
      downvotes: data['downvotes'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      isPinned: data['isPinned'] ?? false,
      upvotedBy: List<String>.from(data['upvotedBy'] ?? []),
      downvotedBy: List<String>.from(data['downvotedBy'] ?? []),
      isApproved: data['isApproved'] ?? false,
      isRejected: data['isRejected'] ?? false,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      approverName: data['approverName'],
      adminFeedback: data['adminFeedback'],
      rejectedAt: data['rejectedAt'] != null
          ? (data['rejectedAt'] as Timestamp).toDate()
          : null,
      rejectedBy: data['rejectedBy'],
      rejecterName: data['rejecterName'],
      rejectionReason: data['rejectionReason'],
      isFeatured: data['isFeatured'] ?? false,
      featuredAt: data['featuredAt'] != null
          ? (data['featuredAt'] as Timestamp).toDate()
          : null,
      savedCount: data['savedCount'] ?? 0,
      replyCount: data['replyCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'authorPhotoUrl': authorPhotoUrl,
      'category': category,
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'views': views, // ← ADD THIS LINE
      'upvotes': upvotes,
      'downvotes': downvotes,
      'commentCount': commentCount,
      'isPinned': isPinned,
      'upvotedBy': upvotedBy,
      'downvotedBy': downvotedBy,
      'isApproved': isApproved,
      'isRejected': isRejected,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'approverName': approverName,
      'adminFeedback': adminFeedback,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectedBy': rejectedBy,
      'rejecterName': rejecterName,
      'rejectionReason': rejectionReason,
      'isFeatured': isFeatured,
      'featuredAt': featuredAt != null ? Timestamp.fromDate(featuredAt!) : null,
      'savedCount': savedCount,
      'replyCount': replyCount,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();
}
