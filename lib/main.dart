import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/config/firebase_config.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/auth_service.dart';
import 'shared/providers/theme_provider.dart';
import 'features/landing/pages/landing_page.dart';
import 'features/home/pages/home_page.dart';
import 'shared/models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      authDomain: FirebaseConfig.authDomain,
      projectId: FirebaseConfig.projectId,
      storageBucket: FirebaseConfig.storageBucket,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      appId: FirebaseConfig.appId,
      measurementId: FirebaseConfig.measurementId,
    ),
  );
  
  // Auto-create admin account if it doesn't exist
  await _createDefaultAdminIfNeeded();
  
  runApp(const MyApp());
}

Future<void> _createDefaultAdminIfNeeded() async {
  try {
    const adminEmail = 'admin@devslog.com';
    const adminPassword = '@dmin123';
    
    // Check if admin already exists in Firestore
    final adminQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: adminEmail)
        .limit(1)
        .get();
    
    if (adminQuery.docs.isEmpty) {
      // Create admin in Firebase Auth
      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
      } catch (e) {
        // If account exists in Auth but not in Firestore, sign in
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
      }
      
      // Create admin user document in Firestore
      final adminUser = UserModel(
        uid: credential.user!.uid,
        email: adminEmail,
        displayName: 'System Admin',
        role: 'admin',
        createdAt: DateTime.now(),
        isEmailVerified: true,
      );
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set(adminUser.toFirestore());
      
      print('✅ Default admin account created successfully!');
      print('📧 Email: $adminEmail');
      print('🔑 Password: $adminPassword');
      
      // Sign out the admin after creation
      await FirebaseAuth.instance.signOut();
    } else {
      print('✅ Admin account already exists');
    }
  } catch (e) {
    print('⚠️ Error creating default admin: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'DevsLog',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const HomePage();
        }
        
        // User is not logged in
        return const LandingPage();
      },
    );
  }
}
