import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyClaimsScreen extends StatelessWidget {
  const MyClaimsScreen({super.key});

  Stream<QuerySnapshot> _myClaimsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    return FirebaseFirestore.instance
        .collection('claims')
        .where('claimantId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Claims')),
        body: const Center(child: Text('Please log in to see your claims.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Claims')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myClaimsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading claims: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final claims = snapshot.data?.docs ?? const [];
          if (claims.isEmpty) {
            return const Center(child: Text('You have not requested any claims.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final doc = claims[index];
              final data = doc.data() as Map<String, dynamic>;

              final itemTitle = (data['itemTitle'] ?? 'Unknown item').toString();
              final message = (data['message'] ?? '').toString();
              final status = (data['status'] ?? 'pending').toString();

              String timestampText = 'Pending...';
              if (data['timestamp'] is Timestamp) {
                final date = (data['timestamp'] as Timestamp).toDate();
                timestampText = date.toString();
              }

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Message: $message'),
                      const SizedBox(height: 4),
                      Text('Status: $status'),
                      const SizedBox(height: 4),
                      Text('Time: $timestampText'),
                    ],
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

