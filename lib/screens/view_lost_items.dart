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
  final Set<String> _claimingItemIds = {};
  final Set<String> _claimedItemIds = {};

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

  Future<void> _handleClaim({
    required String foundItemId,
    required String lostItemId,
    required String itemTitle,
  }) async {
    if (!mounted) return;

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

    // Set loading immediately to prevent duplicate rapid clicks
    setState(() {
      _claimingItemIds.add(foundItemId);
    });

    try {
      final existingClaims = await FirebaseFirestore.instance
          .collection('claims')
          .where('userId', isEqualTo: currentUser.uid)
          .where('foundItemId', isEqualTo: foundItemId)
          .get();
          
      if (!mounted) return;
      
      if (existingClaims.docs.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Duplicate Claim"),
            content: const Text("You have already claimed this item."),
            actions: [
              TextButton(
                onPressed: () {
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
        return;
      }

      if (!mounted) return;
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
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () {
                  final msg = messageController.text.trim();
                  if (msg.isEmpty) return;
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, msg);
                  }
                },
                child: const Text("Submit Request"),
              ),
            ],
          );
        },
      );

      // Delay disposal to allow popup closing animation to finish and avoid 'dependents.isEmpty' Framework errors
      Future.delayed(const Duration(milliseconds: 500), () {
        messageController.dispose();
      });

      if (submittedMessage == null) return;

      if (!mounted) return;

      await _createClaim(
        foundItemId: foundItemId,
        lostItemId: lostItemId,
        itemTitle: itemTitle,
        message: submittedMessage,
        userId: currentUser.uid,
      );

      if (!mounted) return;
      
      setState(() {
        _claimedItemIds.add(foundItemId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Claim request sent successfully")),
      );
    } catch (e) {
      debugPrint("Claim Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is StateError ? e.message : "Error submitting claim: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _claimingItemIds.remove(foundItemId);
        });
      }
    }
  }

  Future<void> _createClaim({
    required String foundItemId,
    required String lostItemId,
    required String itemTitle,
    required String message,
    required String userId,
  }) async {
    final itemRef = FirebaseFirestore.instance.collection('lost_items').doc(foundItemId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      final itemData = itemSnap.data();
      final itemStatus = (itemData?['status'] ?? '').toString();
      
      if (itemStatus != 'open') {
        throw StateError("Item is no longer available for claiming.");
      }

      final newClaimRef = FirebaseFirestore.instance.collection('claims').doc();
      tx.set(newClaimRef, {
        'foundItemId': foundItemId,
        'lostItemId': lostItemId,
        'userId': userId,
        'itemTitle': itemTitle,
        'claimantId': userId,
        'message': message,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
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
                claimButtonEnabled: !_claimingItemIds.contains(doc.id) && !_claimedItemIds.contains(doc.id),
                claimButtonText: _claimingItemIds.contains(doc.id) 
                    ? 'Processing...' 
                    : _claimedItemIds.contains(doc.id) 
                        ? 'Claimed' 
                        : 'Claim',
                onClaimPressed: _claimingItemIds.contains(doc.id) || _claimedItemIds.contains(doc.id) ? null : () {
                  _handleClaim(
                    foundItemId: doc.id,
                    lostItemId: (data['lostItemId'] ?? '').toString(),
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
