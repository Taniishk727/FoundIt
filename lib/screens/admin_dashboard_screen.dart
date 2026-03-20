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

  Future<void> _approveClaim({
    required BuildContext context,
    required DocumentReference claimRef,
    required Map<String, dynamic> claimData,
  }) async {
    try {
      final String claimId = claimRef.id;

      await FirebaseFirestore.instance.runTransaction((tx) async {
        // 1. Fetch claim document using claimId
        final fetchedClaimRef = FirebaseFirestore.instance.collection('claims').doc(claimId);
        final claimSnap = await tx.get(fetchedClaimRef);
        
        if (!claimSnap.exists) {
          throw StateError('Claim not found');
        }

        // 2. Extract: legacy itemId, foundItemId, lostItemId, claimantId
        final extractedData = claimSnap.data() as Map<String, dynamic>;
        final String? legacyItemId = extractedData['itemId']?.toString();
        final String? foundItemId = (extractedData['foundItemId']?.toString() ?? legacyItemId);
        final String? lostItemId = extractedData['lostItemId']?.toString();
        final String? claimantId = extractedData['claimantId']?.toString();

        if (foundItemId == null || foundItemId.isEmpty || claimantId == null || claimantId.isEmpty) {
          throw StateError('Invalid claim data');
        }

        // 3. Fetch found item
        final foundItemRef = FirebaseFirestore.instance.collection('lost_items').doc(foundItemId);
        final foundItemSnap = await tx.get(foundItemRef);
        if (!foundItemSnap.exists) {
          throw StateError('Found item not found');
        }
        final fData = foundItemSnap.data() as Map<String, dynamic>;
        if (fData['status']?.toString() != 'open') {
          throw StateError('Found item already claimed or not open');
        }

        // 4. Fetch lost item if linked
        DocumentReference? lostItemRef;
        DocumentSnapshot? lostItemSnap;
        if (lostItemId != null && lostItemId.isNotEmpty) {
          lostItemRef = FirebaseFirestore.instance.collection('lost_items').doc(lostItemId);
          lostItemSnap = await tx.get(lostItemRef);
          if (lostItemSnap.exists) {
            final lData = lostItemSnap.data() as Map<String, dynamic>;
            if (lData['status']?.toString() != 'open') {
              throw StateError('Linked lost item is not open');
            }
          }
        }

        // 5. Update claim: status = "approved"
        tx.update(fetchedClaimRef, {'status': 'approved'});

        // 6. Update found item
        tx.update(foundItemRef, {
          'status': 'claimed',
          'claimedBy': claimantId,
        });

        // 7. Update lost item (if found)
        if (lostItemRef != null && lostItemSnap != null && lostItemSnap.exists) {
          tx.update(lostItemRef, {
            'status': 'claimed',
            'claimedBy': claimantId,
          });
        }
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim approved successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: ${e.toString()}')),
      );
    }
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
                              onPressed: () => _approveClaim(
                                context: context,
                                claimRef: doc.reference,
                                claimData: data,
                              ),
                              child: const Text('Approve'),
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

