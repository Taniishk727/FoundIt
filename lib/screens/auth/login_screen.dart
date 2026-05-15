import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'register_screen.dart';
import 'package:lost_found_app/state/app_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController adminIdController = TextEditingController();
  final TextEditingController adminPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isAdminLogin = false; // Toggle between student and admin login

  // PRN format: letter followed by 2 digits, then department letters, then 3 digits
  // Examples: F24IT256, SF24IT253, F23CS101
  bool isValidStudentId(String id) {
    final regex = RegExp(r'^[A-Za-z]{1,2}\d{2}[A-Za-z]{2,4}\d{2,3}$');
    return regex.hasMatch(id);
  }

  // Admin ID: alphanumeric identifier (e.g., ADMIN001, A001)
  bool isValidAdminId(String id) {
    return id.isNotEmpty && id.length >= 3;
  }

  Future<void> loginUser() async {
    String studentId = studentIdController.text.trim();
    String password = passwordController.text.trim();

    if (!isValidStudentId(studentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid PRN format (e.g., F24IT256)")),
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 5));

      await AppRole.loadForCurrentUser().timeout(const Duration(seconds: 5));

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

  Future<void> loginAdmin() async {
    String adminId = adminIdController.text.trim();
    String password = adminPasswordController.text.trim();

    if (!isValidAdminId(adminId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid Admin ID")),
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

    // Admin email format: adminId@admin.campus.local
    String email = "${adminId.toLowerCase()}@admin.campus.local";

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 5));

      await AppRole.loadForCurrentUser().timeout(const Duration(seconds: 5));

      // Verify the user actually has admin role
      if (AppRole.role.value != 'admin') {
        await FirebaseAuth.instance.signOut();
        AppRole.role.value = null;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This account does not have admin privileges.")),
        );
        return;
      }

      if (mounted && Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admin login failed. Check your credentials.")),
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
                  _isAdminLogin
                      ? "Log in as administrator"
                      : "Log in to report or claim lost items",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Toggle between Student and Admin login
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Student'),
                      icon: Icon(Icons.school),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Admin'),
                      icon: Icon(Icons.admin_panel_settings),
                    ),
                  ],
                  selected: {_isAdminLogin},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isAdminLogin = newSelection.first;
                    });
                  },
                ),

                const SizedBox(height: 32),

                if (!_isAdminLogin) ...[
                  // Student Login
                  CustomTextField(
                    controller: studentIdController,
                    labelText: "PRN (Student ID)",
                    hintText: "F24IT256",
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
                    text: "Login as Student",
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
                ] else ...[
                  // Admin Login
                  CustomTextField(
                    controller: adminIdController,
                    labelText: "Admin ID",
                    hintText: "ADMIN001",
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                  CustomTextField(
                    controller: adminPasswordController,
                    labelText: "Password",
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: "Login as Admin",
                    isLoading: _isLoading,
                    onPressed: loginAdmin,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
