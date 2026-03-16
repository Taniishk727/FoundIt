import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lost_found_app/screens/view_lost_items.dart';

class ReportLostItem extends StatefulWidget {
  const ReportLostItem({super.key});

  @override
  State<ReportLostItem> createState() => _ReportLostItemState();
}

class _ReportLostItemState extends State<ReportLostItem> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();

  String selectedCategory = "Other";

  void submitItem(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to report items")),
      );
      return;
    }

    if (titleController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in title and location")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('lost_items').add({
      'title': titleController.text,
      'description': descriptionController.text,
      'location': locationController.text,
      'category': selectedCategory,
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
      'reportedBy': currentUser.uid,
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ViewLostItems()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Lost Item")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),

            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: "Description"),
            ),

            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: "Location"),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
              value: selectedCategory,
              items:
                  [
                    "Phone",
                    "Wallet",
                    "ID Card",
                    "Bag",
                    "Electronics",
                    "Keys",
                    "Other",
                  ].map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                submitItem(context);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
