import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Stream<QuerySnapshot> _claimsStream() {
    return FirebaseFirestore.instance
        .collection('claims')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _acceptClaim({
    required BuildContext context,
    required DocumentReference claimRef,
    required Map<String, dynamic> claimData,
  }) async {
    final itemId = (claimData['itemId'] ?? '').toString();
    if (itemId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid claim: missing itemId')),
      );
      return;
    }

    final itemRef =
        FirebaseFirestore.instance.collection('lost_items').doc(itemId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final itemSnap = await tx.get(itemRef);
        if (!itemSnap.exists) {
          throw StateError('Item not found');
        }

        final itemData = itemSnap.data() as Map<String, dynamic>;
        final itemStatus = (itemData['status'] ?? '').toString();
        if (itemStatus != 'open') {
          throw StateError('Item already claimed');
        }

        final claimSnap = await tx.get(claimRef);
        if (!claimSnap.exists) {
          throw StateError('Claim not found');
        }

        // Lock item + accept selected claim.
        tx.update(itemRef, {'status': 'claimed'});
        tx.update(claimRef, {'status': 'accepted'});

        // Reject all other claims for this item.
        final otherClaims = await FirebaseFirestore.instance
            .collection('claims')
            .where('itemId', isEqualTo: itemId)
            .get();

        for (final doc in otherClaims.docs) {
          if (doc.reference.path == claimRef.path) continue;
          tx.update(doc.reference, {'status': 'rejected'});
        }
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: ${e.toString()}')),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Claim accepted')),
    );
  }

  Future<void> _rejectClaim({
    required BuildContext context,
    required DocumentReference claimRef,
  }) async {
    await claimRef.update({'status': 'rejected'});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Claim rejected')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _claimsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading claims: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final claims = snapshot.data?.docs ?? const [];
          if (claims.isEmpty) {
            return const Center(child: Text('No claims found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final doc = claims[index];
              final data = doc.data() as Map<String, dynamic>;

              final status = (data['status'] ?? 'pending').toString();
              final itemTitle = (data['itemTitle'] ?? 'Unknown item').toString();
              final claimantId = (data['claimantId'] ?? '').toString();
              final message = (data['message'] ?? '').toString();

              String timestampText = 'Pending...';
              if (data['timestamp'] is Timestamp) {
                timestampText = (data['timestamp'] as Timestamp).toDate().toString();
              }

              final isPending = status == 'pending';

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
                      const SizedBox(height: 6),
                      Text('Claimant: $claimantId'),
                      const SizedBox(height: 6),
                      Text('Message: $message'),
                      const SizedBox(height: 6),
                      Text('Status: $status'),
                      const SizedBox(height: 6),
                      Text('Time: $timestampText'),
                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _rejectClaim(
                                context: context,
                                claimRef: doc.reference,
                              ),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _acceptClaim(
                                context: context,
                                claimRef: doc.reference,
                                claimData: data,
                              ),
                              child: const Text('Accept'),
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

