import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lost_found_app/services/notification_service.dart';

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
      final String? lostItemId = claimData['lostItemId']?.toString();
      final String? claimantId = claimData['claimantId']?.toString();

      if (lostItemId == null || lostItemId.isEmpty || claimantId == null || claimantId.isEmpty) {
        throw StateError('Invalid claim data: missing lostItemId or claimantId');
      }

      // Pre-fetch all found items linked to this lost item
      final foundItemsQuery = await FirebaseFirestore.instance
          .collection('lost_items')
          .where('type', isEqualTo: 'found')
          .where('lostItemId', isEqualTo: lostItemId)
          .where('status', isEqualTo: 'open')
          .get();

      await FirebaseFirestore.instance.runTransaction((tx) async {
        // 1. Fetch claim document
        final fetchedClaimRef = FirebaseFirestore.instance.collection('claims').doc(claimId);
        final claimSnap = await tx.get(fetchedClaimRef);
        
        if (!claimSnap.exists) {
          throw StateError('Claim not found');
        }

        // 2. Fetch lost item
        final lostItemRef = FirebaseFirestore.instance.collection('lost_items').doc(lostItemId);
        final lostItemSnap = await tx.get(lostItemRef);
        if (!lostItemSnap.exists) {
          throw StateError('Lost item not found');
        }
        final lData = lostItemSnap.data() as Map<String, dynamic>;
        debugPrint('Item status before update (lostItem): ${lData['status']}');
        if (lData['status']?.toString() != 'open') {
          throw StateError('Lost item is already claimed or not open');
        }

        

        // 3. Update claim: status = "approved"
        tx.update(fetchedClaimRef, {'status': 'approved'});

        // 4. Update lost item
        tx.update(lostItemRef, {
          'status': 'claimed',
          'claimedBy': claimantId,
        });

        // 5. Update ALL associated found items to hide them
        for (var doc in foundItemsQuery.docs) {
          tx.update(doc.reference, {
            'status': 'claimed',
            'claimedBy': claimantId,
          });
        }
        
        debugPrint('Claim approval status update: lostItemId=$lostItemId SUCCESS. Resolved ${foundItemsQuery.docs.length} found item(s).');
      });

      // Notify the claimant about approval
      if (claimantId.isNotEmpty) {
        NotificationService.sendInAppNotification(
          userId: claimantId,
          title: 'Claim Approved!',
          body: 'Your claim for "${ (claimData['itemTitle'] ?? 'an item').toString() }" has been approved. You can now collect your item.',
          type: 'claim_approved',
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim approved successfully')),
      );
    } catch (e) {
      debugPrint('Claim approval update FAILURE: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _rejectClaim({
    required BuildContext context,
    required DocumentReference claimRef,
    required Map<String, dynamic> claimData,
  }) async {
    await claimRef.update({'status': 'rejected'});

    // Notify the claimant about rejection
    final claimantId = (claimData['claimantId'] ?? '').toString();
    if (claimantId.isNotEmpty) {
      NotificationService.sendInAppNotification(
        userId: claimantId,
        title: 'Claim Rejected',
        body: 'Your claim for "${ (claimData['itemTitle'] ?? 'an item').toString() }" was rejected.',
        type: 'claim_rejected',
      );
    }

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
                                claimData: data,
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

