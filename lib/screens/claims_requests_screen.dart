import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClaimsRequestsScreen extends StatelessWidget {
  const ClaimsRequestsScreen({super.key, this.itemId});

  final String? itemId;

  Stream<QuerySnapshot> _claimsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream<QuerySnapshot>.empty();
    }

    Query query = FirebaseFirestore.instance
        .collection('claims');

    if (itemId != null && itemId!.trim().isNotEmpty) {
      query = query.where('itemId', isEqualTo: itemId);
    } else {
      // Default view: show *my* claim requests (claimant view)
      query = query.where('claimantId', isEqualTo: currentUser.uid);
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
        title: Text(itemId == null ? 'My Claims' : 'Claims for Item'),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No claim requests found',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final doc = claims[index];
              final data = doc.data() as Map<String, dynamic>;

              final status = (data['status'] ?? 'pending').toString();
              final message = (data['message'] ?? '').toString();
              final itemTitle = (data['itemTitle'] ?? 'Unknown item').toString();
              
              String timestampText = 'Pending...';
              if (data['timestamp'] is Timestamp) {
                final date = (data['timestamp'] as Timestamp).toDate();
                
                final String ampm = date.hour >= 12 ? 'PM' : 'AM';
                final int hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
                final String minute = date.minute.toString().padLeft(2, '0');
                
                timestampText = '${date.month}/${date.day}/${date.year} - $hour:$minute $ampm';
              }

              final isPending = status == 'pending';
              
              Color statusColor = Colors.grey;
              if (status == 'accepted' || status == 'approved') statusColor = Colors.green;
              if (status == 'rejected') statusColor = Colors.red;
              if (status == 'pending') statusColor = Theme.of(context).primaryColor;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              itemTitle,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            timestampText,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        "Claimant Message:",
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Text(
                          'This request is pending review.',
                          style: Theme.of(context).textTheme.bodySmall,
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
