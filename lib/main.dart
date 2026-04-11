import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_navbar.dart';
import 'package:lost_found_app/state/app_role.dart';
import 'package:lost_found_app/theme/app_theme.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  debugPrint("APP STARTED. Initial User: ${FirebaseAuth.instance.currentUser?.uid}");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lost & Found',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("AuthWrapper build triggered. Current User: ${FirebaseAuth.instance.currentUser?.uid}");
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint(
            "authStateChanges EVENT TRIGGERED: Connection=${snapshot.connectionState}, SnapshotDataUser=${snapshot.data?.uid}, FirebaseAuthUser=${FirebaseAuth.instance.currentUser?.uid}");
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // If we have a user but role isn't loaded yet, load it.
          // AppRole.role is a ValueNotifier in MainNavbar.
          if (AppRole.role.value == null) {
            AppRole.loadForCurrentUser();
          }
          return const MainNavbar();
        }

        return const LoginScreen();
      },
    );
  }
}

