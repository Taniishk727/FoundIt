import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/main_navbar.dart';
import 'package:lost_found_app/state/app_role.dart';
import 'package:lost_found_app/theme/app_theme.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final prefs = await SharedPreferences.getInstance();
  
  debugPrint("APP STARTED. Initial User: ${FirebaseAuth.instance.currentUser?.uid}");
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(prefs),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Lost & Found',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
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

