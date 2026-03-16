import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'claims_requests_screen.dart';

class MyReportedItemsScreen extends StatelessWidget {
  const MyReportedItemsScreen({super.key});

  Stream<QuerySnapshot> _myItemsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return FirebaseFirestore.instance
        .collection('lost_items')
        .where('reportedBy', isEqualTo: currentUser.uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Reported Items')),
        body: const Center(child: Text('Please log in to see your items.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Reported Items')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading your items: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data?.docs ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('You have not reported any items.'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = (data['title'] ?? 'No title').toString();
              final status = (data['status'] ?? 'open').toString();
              final category = (data['category'] ?? 'Other').toString();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category: $category'),
                      Text('Status: $status'),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ClaimsRequestsScreen(itemId: doc.id),
                        ),
                      );
                    },
                    child: const Text('View Claims'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

