# DevsLog - Developer Forum Web App

A modern forum web application built with Flutter and Firebase where developers can share knowledge, collaborate on code, and build a community.

## Features

### User Features
- 🔐 Account management with email verification
- ✍️ Create, edit, and delete posts with rich text editor
- 👍 Vote system (upvotes/downvotes) for posts
- 🔖 Bookmark favorite posts
- 💬 Comment on posts
- 📚 Reading history tracking
- 👤 Customizable user profiles
- 🔑 Password reset functionality

### Admin Features
- 📊 Admin dashboard with statistics
- 👥 User management (CRUD operations)
- 🛡️ Post moderation and management
- 🔔 Admin notifications system
- 📈 Monthly post analytics with charts

## Setup Instructions

### Prerequisites
- Flutter SDK (3.9.0 or higher)
- Firebase account
- Node.js (for Firebase tools)

### Firebase Setup

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add Project"
   - Follow the setup wizard

2. **Enable Authentication**
   - In Firebase Console, go to Authentication
   - Enable Email/Password sign-in method

3. **Create Firestore Database**
   - Go to Firestore Database
   - Click "Create Database"
   - Start in production mode
   - Choose a location

4. **Setup Firebase for Web**
   - In Project Settings, add a Web app
   - Copy the Firebase configuration
   - Create `lib/core/config/firebase_config.dart` with your config

5. **Firestore Security Rules**
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read: if request.auth != null;
         allow write: if request.auth.uid == userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
       }
       match /posts/{postId} {
         allow read: if true;
         allow create: if request.auth != null;
         allow update, delete: if request.auth.uid == resource.data.authorId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
       }
       match /comments/{commentId} {
         allow read: if true;
         allow create: if request.auth != null;
         allow update, delete: if request.auth.uid == resource.data.authorId;
       }
     }
   }
   ```

### Installation

1. Clone the repository
2. Run `flutter pub get`
3. Configure Firebase (see above)
4. Run `flutter run -d chrome` for web

## Project Structure

```
lib/
├── core/
│   ├── config/
│   ├── theme/
│   └── constants/
├── features/
│   ├── auth/
│   ├── posts/
│   ├── profile/
│   └── admin/
├── shared/
│   ├── models/
│   ├── widgets/
│   └── services/
└── main.dart
```

## Technology Stack

- **Frontend**: Flutter Web
- **Backend**: Firebase (Firestore, Auth, Storage)
- **State Management**: Provider
- **UI**: Custom Material Design with Google Fonts

## License

This project is licensed under the MIT License.
