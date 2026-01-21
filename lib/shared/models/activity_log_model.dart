import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final ActivityType type;
  final String description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final String? ipAddress;
  final String? deviceInfo;
  final String? location;
  final ActivityStatus status;

  ActivityLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.type,
    required this.description,
    this.metadata,
    required this.createdAt,
    this.ipAddress,
    this.deviceInfo,
    this.location,
    this.status = ActivityStatus.success,
  });

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLogModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == 'ActivityType.${data['type']}',
        orElse: () => ActivityType.other,
      ),
      description: data['description'] ?? '',
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      ipAddress: data['ipAddress'],
      deviceInfo: data['deviceInfo'],
      location: data['location'],
      status: ActivityStatus.values.firstWhere(
        (e) => e.toString() == 'ActivityStatus.${data['status']}',
        orElse: () => ActivityStatus.success,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'type': type.toString().split('.').last,
      'description': description,
      'metadata': metadata,
      'createdAt': FieldValue.serverTimestamp(),
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
      'location': location,
      'status': status.toString().split('.').last,
    };
  }
}

enum ActivityType {
  login,
  logout,
  register,
  postCreated,
  postUpdated,
  postDeleted,
  postApproved,
  postRejected,
  commentCreated,
  commentDeleted,
  replyCreated,
  replyDeleted,
  profileUpdated,
  passwordChanged,
  emailChanged,
  postSaved,
  postUnsaved,
  postUpvoted,
  postDownvoted,
  userPromoted,
  userDemoted,
  userBanned,
  userUnbanned,
  accountDeleted,
  settingsChanged,
  other,
}

enum ActivityStatus {
  success,
  failed,
  pending,
  warning,
}