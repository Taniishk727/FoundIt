import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'package:lost_found_app/screens/main_navbar.dart';
import 'package:lost_found_app/state/app_role.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;

  bool isValidStudentId(String id) {
    final regex = RegExp(r'^SF\d{2}IT\d{3}$');
    return regex.hasMatch(id);
  }

  Future<void> registerUser() async {
    String studentId = studentIdController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (!isValidStudentId(studentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Student ID format (e.g., SF24IT253)")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String email = "${studentId.toLowerCase()}@campus.local";

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await AppRole.ensureUserDoc(uid: currentUser.uid, email: currentUser.email ?? email);
        await AppRole.loadForUid(currentUser.uid);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration Successful")),
      );

      // Registration signs the user in. authStateChanges stream will naturally route to MainNavbar.
      // Pop everything to return to the root AuthWrapper.
      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registration failed: ${e.toString()}")),
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
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Join FoundIt",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "Register with your strict Student ID",
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
                CustomTextField(
                  controller: confirmPasswordController,
                  labelText: "Confirm Password",
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_reset),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: "Register",
                  isLoading: _isLoading,
                  onPressed: registerUser,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
