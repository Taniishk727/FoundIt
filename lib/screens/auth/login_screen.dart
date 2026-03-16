import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lost_found_app/screens/view_lost_items.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isValidStudentId(String id) {
    final regex = RegExp(r'^SF\d{2}IT\d{3}$');
    return regex.hasMatch(id);
  }

  Future<void> loginUser(BuildContext context) async {
    String studentId = studentIdController.text.trim();
    String password = passwordController.text.trim();

    if (!isValidStudentId(studentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Student ID format")),
      );
      return;
    }

    String email = "${studentId.toLowerCase()}@campus.local";

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ViewLostItems()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: studentIdController,
              decoration: const InputDecoration(
                labelText: "Student ID",
                hintText: "SF24IT253",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                loginUser(context);
              },
              child: const Text("Login"),
            ),
            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegisterScreen()),
                );
              },
              child: const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}
