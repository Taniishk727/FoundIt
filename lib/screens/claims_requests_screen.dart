import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClaimsRequestsScreen extends StatelessWidget {
  const ClaimsRequestsScreen({super.key, this.itemId});

  final String? itemId;

  Stream<QuerySnapshot> _claimsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Empty stream if not logged in; UI will handle this case separately.
      return const Stream<QuerySnapshot>.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('claims')
        .where('reporterId', isEqualTo: currentUser.uid);

    if (itemId != null && itemId!.trim().isNotEmpty) {
      query = query.where('itemId', isEqualTo: itemId);
    }

    return query.orderBy('timestamp', descending: true).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Requests')),
        body: const Center(
          child: Text('Please log in to see claim requests.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(itemId == null ? 'Claim Requests' : 'Claims for Item'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _claimsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading claim requests: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final claims = snapshot.data?.docs ?? const [];

          if (claims.isEmpty) {
            return const Center(
              child: Text('No claim requests found.'),
            );
          }

          return ListView.builder(
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final doc = claims[index];
              final data = doc.data() as Map<String, dynamic>;

              final status = (data['status'] ?? 'pending').toString();
              final message = (data['message'] ?? '').toString();
              final itemTitle =
                  (data['itemTitle'] ?? 'Unknown item').toString();

              final timestamp = data['timestamp'];
              String timestampText = 'Pending…';
              if (timestamp is Timestamp) {
                timestampText = timestamp.toDate().toString();
              }

              final isPending = status == 'pending';

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Item: $itemTitle',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          )),
                      const SizedBox(height: 4),
                      Text('Message: $message'),
                      const SizedBox(height: 4),
                      Text('Status: $status'),
                      const SizedBox(height: 4),
                      Text('Time: $timestampText'),
                      if (isPending) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await doc.reference
                                    .update({'status': 'approved'});
                              },
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                await doc.reference
                                    .update({'status': 'rejected'});
                              },
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
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

