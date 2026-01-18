class AdminStatsModel {
  final int totalUsers;
  final int totalPosts;
  final int totalComments;
  final int totalViews;
  final int activeToday;
  final int pinnedPosts;

  AdminStatsModel({
    required this.totalUsers,
    required this.totalPosts,
    required this.totalComments,
    required this.totalViews,
    required this.activeToday,
    required this.pinnedPosts,
  });

  factory AdminStatsModel.empty() {
    return AdminStatsModel(
      totalUsers: 0,
      totalPosts: 0,
      totalComments: 0,
      totalViews: 0,
      activeToday: 0,
      pinnedPosts: 0,
    );
  }
}