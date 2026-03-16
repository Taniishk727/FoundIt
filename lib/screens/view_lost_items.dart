import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_lost_items.dart';
import 'claims_requests_screen.dart';
import 'my_reported_items_screen.dart';

class ViewLostItems extends StatefulWidget {
  const ViewLostItems({super.key});

  @override
  State<ViewLostItems> createState() => _ViewLostItemsState();
}

class _ViewLostItemsState extends State<ViewLostItems> {
  String selectedCategory = "All";

  Future<void> _showClaimDialog({
    required BuildContext context,
    required String itemId,
    required String itemTitle,
    required String? reporterId,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to claim items")),
      );
      return;
    }

    if (reporterId == null || reporterId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This item can’t be claimed yet (missing reporter)"),
        ),
      );
      return;
    }

    final messageController = TextEditingController();
    final submittedMessage = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Claim Item"),
          content: TextField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: "Why is this item yours?",
            ),
            minLines: 2,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final msg = messageController.text.trim();
                if (msg.isEmpty) return;
                Navigator.pop(dialogContext, msg);
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );

    messageController.dispose();
    if (submittedMessage == null) return;

    await FirebaseFirestore.instance.collection('claims').add({
      'itemId': itemId,
      'itemTitle': itemTitle,
      'claimantId': currentUser.uid,
      'reporterId': reporterId,
      'message': submittedMessage,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Claim request sent")),
    );
  }

  Stream<QuerySnapshot> getItemsStream() {
    if (selectedCategory == "All") {
      return FirebaseFirestore.instance
          .collection('lost_items')
          .where('status', isEqualTo: 'open')
          .orderBy('created_at', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('lost_items')
          .where('status', isEqualTo: 'open')
          .where('category', isEqualTo: selectedCategory)
          .orderBy('created_at', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recent Lost Items"),
        actions: [
          IconButton(
            tooltip: "My Reported Items",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyReportedItemsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: "Claim Requests",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ClaimsRequestsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.inbox_outlined),
          ),
        ],
      ),

      body: Column(
        children: [
          // CATEGORY FILTER
          Padding(
            padding: const EdgeInsets.all(10),
            child: DropdownButton<String>(
              value: selectedCategory,
              isExpanded: true,
              items:
                  [
                    "All",
                    "Phone",
                    "Wallet",
                    "ID Card",
                    "Bag",
                    "Electronics",
                    "Keys",
                    "Other",
                  ].map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedCategory = value;
                });
              },
            ),
          ),

          // ITEMS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Error loading items: ${snapshot.error}"),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data?.docs ?? const [];

                if (items.isEmpty) {
                  return const Center(child: Text("No items found"));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = (data['title'] ?? 'No title').toString();
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['location'] ?? 'Unknown location'),
                            Text("Category: ${data['category'] ?? 'Other'}"),
                          ],
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            _showClaimDialog(
                              context: context,
                              itemId: doc.id,
                              itemTitle: title,
                              reporterId: data['reportedBy'] as String?,
                            );
                          },
                          child: const Text("Claim Item"),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReportLostItem()),
          );
        },
      ),
    );
  }
}
