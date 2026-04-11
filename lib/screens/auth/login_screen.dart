import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'register_screen.dart';
import 'package:lost_found_app/screens/main_navbar.dart';
import 'package:lost_found_app/state/app_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override

  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  bool isValidStudentId(String id) {
    final regex = RegExp(r'^SF\d{2}IT\d{3}$');
    return regex.hasMatch(id);
  }

  Future<void> loginUser() async {
    String studentId = studentIdController.text.trim();
    String password = passwordController.text.trim();

    if (!isValidStudentId(studentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Student ID format (e.g., SF24IT253)")),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a password")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String email = "${studentId.toLowerCase()}@campus.local";

    try {
      final stopwatch = Stopwatch()..start();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 5));

      await AppRole.loadForCurrentUser().timeout(const Duration(seconds: 5));

      stopwatch.stop();
      debugPrint("Login query time: ${stopwatch.elapsedMilliseconds} ms");

      // We do not need to call pushReplacement. StreamBuilder in main.dart handles it!
      // If we are pushed on top of a stack, pop back to first route
      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed. Check your credentials.")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.find_replace,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  "Welcome Back",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  "Log in to report or claim lost items",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),
                CustomTextField(
                  controller: studentIdController,
                  labelText: "Student ID",
                  hintText: "SF24IT253",
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                CustomTextField(
                  controller: passwordController,
                  labelText: "Password",
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: "Login",
                  isLoading: _isLoading,
                  onPressed: loginUser,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text("Register"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
