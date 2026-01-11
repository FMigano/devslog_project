class AppConstants {
  static const String appName = 'DevsLog';
  static const String appTagline = 'Where Developers Connect & Collaborate';
  static const String appDescription = 'Join thousands of developers sharing knowledge, solving problems, and building the future together.';
  
  // Collections
  static const String usersCollection = 'users';
  static const String postsCollection = 'posts';
  static const String commentsCollection = 'comments';
  static const String bookmarksCollection = 'bookmarks';
  static const String votesCollection = 'votes';
  static const String historyCollection = 'history';
  static const String notificationsCollection = 'notifications';
  
  // Pagination
  static const int postsPerPage = 10;
  static const int commentsPerPage = 20;
  
  // User roles
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';
  
  // Post categories
  static const List<String> postCategories = [
    'General Discussion',
    'Web Development',
    'Mobile Development',
    'Backend Development',
    'DevOps',
    'Database',
    'Algorithm & Data Structures',
    'Career Advice',
    'Tools & Resources',
    'Open Source',
    'Security',
    'UI/UX',
  ];
  
  // Badges
  static const Map<String, String> badges = {
    'new_member': '🆕 New Member',
    'contributor': '⭐ Contributor',
    'expert': '🏆 Expert',
    'mentor': '🎓 Mentor',
    'verified': '✓ Verified',
  };
}
