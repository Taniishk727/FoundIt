import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lost_found_app/screens/view_lost_items.dart';

class ReportLostItem extends StatelessWidget {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();

  void submitItem(BuildContext context) async {
  await FirebaseFirestore.instance.collection('lost_items').add({
    'title': titleController.text,
    'description': descriptionController.text,
    'location': locationController.text,
    'status': 'open',
    'created_at': FieldValue.serverTimestamp(),
  });

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => ViewLostItems()),
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
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: "Description")),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: "Location")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:(){ submitItem(context);
              },
              child: const Text("Submit"),
            )
          ],
        ),
      ),
    );
  }
}