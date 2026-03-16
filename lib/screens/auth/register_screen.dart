import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatelessWidget {
  RegisterScreen({super.key});

  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isValidStudentId(String id) {
    final regex = RegExp(r'^SF\d{2}IT\d{3}$');
    return regex.hasMatch(id);
  }

  String studentIdToEmail(String studentId) {
    return "${studentId.toLowerCase()}@campus.local";
  }

  Future<void> registerUser(BuildContext context) async {
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
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful. Please login.")),
      );

      Navigator.pop(context); // returns to login screen
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Student")),
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
                registerUser(context);
              },
              child: const Text("Register"),
            ),
          ],
        ),
      ),
    );
  }
}
