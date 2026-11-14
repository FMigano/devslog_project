# Re: Devs

**Re: Devs** is a Flutter-powered developer community platform where programmers share knowledge, discuss technical topics, publish tutorials, ask questions, and collaborate.

## Features

- Email/password authentication, email verification, password reset, and profile management
- Create, edit, delete, and search developer posts
- Rich-text posts with image uploads, categories, and tags
- Upvotes, downvotes, bookmarks, views, and reading history
- Comments, nested replies, and real-time post updates
- User profiles with posts, saved posts, activity logs, and reputation
- Notifications for community activity
- AI-assisted tag generation, post enhancement, duplicate detection, and comment suggestions
- Admin dashboard for post approval, moderation, user management, roles, bans, pinning, and featured posts
- Analytics for categories, activity, user growth, and engagement
- Light and dark themes

## Technology stack

- **Flutter/Dart** for the application
- **Firebase Authentication** for user accounts
- **Cloud Firestore** for application data
- **Firebase Storage** for post and profile images
- **Provider** for state management
- **fl_chart** for admin analytics
- **Firebase Hosting** for web deployment
- Optional local **Ollama** integration for AI-assisted features

## Requirements

- Flutter SDK 3.9.0 or later
- Dart SDK compatible with `^3.9.0`
- A Firebase project with Authentication, Firestore, Storage, and Hosting enabled
- Node.js and the Firebase CLI for deployment
- Optional: Ollama for local AI features

## Getting started

1. Install dependencies:

   ```bash
   flutter pub get
   ```

2. Configure Firebase in `lib/core/config/firebase_config.dart` using your Firebase web app settings.

3. Enable Email/Password authentication, Cloud Firestore, and Firebase Storage in the Firebase Console.

4. Review `firestore.rules` and `firebase.json` for your deployment environment.

5. Run the application:

   ```bash
   flutter run -d chrome
   ```

   You can also use any configured Flutter device:

   ```bash
   flutter devices
   flutter run
   ```

## Firebase deployment

```bash
flutter build web
firebase login
firebase deploy --only hosting
```

Firebase Hosting serves `build/web` and rewrites application routes to `index.html`.

## Firestore collections

The application uses these primary collections:

- `users`
- `posts`
- `comments` and nested `replies`
- `votes`
- `bookmarks`
- `notifications`
- `activity_logs`

The repository includes Firestore rules and indexes, Firebase Hosting configuration, and the project alias in `.firebaserc`.

## Project structure

```text
lib/
├── core/
│   ├── config/       # Firebase, Ollama, and app configuration
│   ├── constants/    # App name, categories, tags, roles, and limits
│   └── theme/        # Light and dark themes
├── features/
│   ├── admin/        # Moderation, user management, and analytics
│   ├── auth/         # Login, registration, verification, and reset flows
│   ├── home/         # Authenticated home experience
│   ├── landing/      # Public landing page
│   ├── notifications/ # User notifications
│   ├── posts/        # Post creation, details, comments, votes, and bookmarks
│   ├── profile/      # Profiles, saved posts, and activity logs
│   ├── search/       # Post search and suggestions
│   └── settings/     # Application settings
├── shared/
│   ├── models/       # Shared Firestore models
│   ├── providers/    # Shared application state
│   ├── services/     # Auth, Firestore, notification, and AI services
│   └── widgets/      # Reusable UI components
└── main.dart         # Firebase initialization and app bootstrap
```

## Development commands

```bash
flutter analyze
flutter test
flutter build web
```

## Security notes

- Do not commit private credentials or production secrets.
- Replace sample Firebase configuration before deploying your own environment.
- Review and customize Firestore and Storage rules for production.
- Replace development-only administrator credentials and disable automatic admin creation before production use.

## License

No license file is currently included in this repository.
