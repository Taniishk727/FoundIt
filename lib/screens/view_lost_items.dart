import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/item_card.dart';
import 'item_detail_screen.dart';

class ViewLostItems extends StatefulWidget {
  const ViewLostItems({super.key});

  @override
  State<ViewLostItems> createState() => _ViewLostItemsState();
}

class _ViewLostItemsState extends State<ViewLostItems> {
  String selectedCategory = "All";
  String searchQuery = "";

  final List<String> categories = [
    "All",
    "Phone",
    "Wallet",
    "ID Card",
    "Bag",
    "Electronics",
    "Keys",
    "Other",
  ];

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
        const SnackBar(content: Text("This item can’t be claimed yet (missing reporter)")),
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
              border: OutlineInputBorder(),
            ),
            minLines: 2,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                final msg = messageController.text.trim();
                if (msg.isEmpty) return;
                Navigator.pop(dialogContext, msg);
              },
              child: const Text("Submit Request"),
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
      const SnackBar(content: Text("Claim request sent successfully")),
    );
  }

  Stream<QuerySnapshot> getItemsStream() {
    Query query = FirebaseFirestore.instance
        .collection('lost_items')
        .where('status', isEqualTo: 'open')
        .orderBy('created_at', descending: true);

    if (selectedCategory != "All") {
      query = query.where('category', isEqualTo: selectedCategory);
    }
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FoundIt"),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          )
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search items...",
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedCategory = category;
                            });
                          },
                          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading items: ${snapshot.error}"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var items = snapshot.data?.docs ?? [];

                // Client-side search filtering (since Firestore doesn't support partial text search easily)
                if (searchQuery.isNotEmpty) {
                  items = items.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    final location = (data['location'] ?? '').toString().toLowerCase();
                    return title.contains(searchQuery) || location.contains(searchQuery);
                  }).toList();
                }

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "No items found",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final doc = items[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ItemDetailScreen(itemData: data),
                          ),
                        );
                      },
                      child: ItemCard(
                        title: (data['title'] ?? 'No title').toString(),
                        location: (data['location'] ?? 'Unknown location').toString(),
                        category: (data['category'] ?? 'Other').toString(),
                        reporterId: (data['reportedBy'] ?? '').toString(),
                        onClaimPressed: () {
                          _showClaimDialog(
                            context: context,
                            itemId: doc.id,
                            itemTitle: (data['title'] ?? "Item").toString(),
                            reporterId: data['reportedBy'] as String?,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
