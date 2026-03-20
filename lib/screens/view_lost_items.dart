import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/item_card.dart';
import 'item_detail_screen.dart';
import 'package:lost_found_app/state/app_role.dart';

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
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to claim items")),
      );
      return;
    }

    if (AppRole.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Admins cannot claim items")),
      );
      return;
    }

    // 1. Fetch user's reported lost items
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    late List<QueryDocumentSnapshot> lostItems;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('lost_items')
          .where('reportedBy', isEqualTo: currentUser.uid)
          .where('type', isEqualTo: 'lost')
          .where('status', isEqualTo: 'open')
          .get();
      lostItems = querySnapshot.docs;
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching your lost items: $e")),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // hide loading

    if (lostItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("No Lost Items"),
          content: const Text(
            "You have not reported any lost items. Please report your lost item first so we can link it to this found item."
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            )
          ],
        ),
      );
      return;
    }

    // 2. Select lost item dialog/bottom sheet
    if (!context.mounted) return;
    final selectedLostItemId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Select Your Lost Item",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: lostItems.length,
                    itemBuilder: (c, i) {
                      final data = lostItems[i].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: Icon(Icons.inventory_2_outlined, color: Theme.of(context).primaryColor),
                        title: Text((data['title'] ?? 'Unknown').toString()),
                        subtitle: Text((data['location'] ?? 'Unknown location').toString()),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.pop(ctx, lostItems[i].id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedLostItemId == null) return;

    // 3. Message dialog
    if (!context.mounted) return;
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

    // 4. Verify found item is still open and create claim
    final itemSnap = await FirebaseFirestore.instance
        .collection('lost_items')
        .doc(itemId)
        .get();
    
    final itemData = itemSnap.data();
    final itemStatus = (itemData?['status'] ?? '').toString();
    if (itemStatus != 'open') {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Already claimed")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('claims').add({
      'foundItemId': itemId,
      'lostItemId': selectedLostItemId,
      'itemTitle': itemTitle, // kept for backward compatibility with UI lists
      'claimantId': currentUser.uid,
      'message': submittedMessage,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
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

  Widget _buildItemList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: getItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading items: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var items = snapshot.data?.docs ?? [];

        // Apply filters
        items = items.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final itemType = (data['type'] ?? 'lost').toString();
          
          if (itemType != type) return false;

          if (searchQuery.isNotEmpty) {
            final title = (data['title'] ?? '').toString().toLowerCase();
            final location = (data['location'] ?? '').toString().toLowerCase();
            if (!(title.contains(searchQuery) || location.contains(searchQuery))) {
              return false;
            }
          }
          return true;
        }).toList();

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

            final isFound = type == 'found';
            final showClaim = isFound && !AppRole.isAdmin;

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
                showClaimButton: showClaim,
                claimButtonEnabled: true,
                claimButtonText: 'Claim',
                onClaimPressed: () {
                  _showClaimDialog(
                    context: context,
                    itemId: doc.id,
                    itemTitle: (data['title'] ?? "Item").toString(),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("FoundIt"),
          centerTitle: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: "Lost Items"),
              Tab(text: "Found Items"),
            ],
          ),
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
              child: TabBarView(
                children: [
                  _buildItemList('lost'),
                  _buildItemList('found'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
