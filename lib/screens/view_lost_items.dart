import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_lost_items.dart';

class ViewLostItems extends StatefulWidget {
  const ViewLostItems({super.key});

  @override
  State<ViewLostItems> createState() => _ViewLostItemsState();
}

class _ViewLostItemsState extends State<ViewLostItems> {
  String selectedCategory = "All";

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
      appBar: AppBar(title: const Text("Recent Lost Items")),

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

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        title: Text(data['title'] ?? 'No title'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['location'] ?? 'Unknown location'),
                            Text("Category: ${data['category'] ?? 'Other'}"),
                          ],
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
