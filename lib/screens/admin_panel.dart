import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/login_screen.dart';
import 'package:lost_found_app/state/app_role.dart';
import 'item_detail_screen.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile / Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, size: 48, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ?? "User",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Text(
              AppRole.isAdmin ? "System Overview (Admin)" : "Account",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (AppRole.isAdmin)
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: "Total Items",
                      icon: Icons.inventory_2,
                      stream: FirebaseFirestore.instance
                          .collection('lost_items')
                          .snapshots(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: "Active Claims",
                      icon: Icons.inbox,
                      stream: FirebaseFirestore.instance
                          .collection('claims')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role: ${AppRole.role.value ?? 'unknown'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: "My Claims",
                          icon: Icons.inbox_outlined,
                          stream: FirebaseFirestore.instance
                              .collection('claims')
                              .where(
                                'claimantId',
                                isEqualTo:
                                    FirebaseAuth.instance.currentUser?.uid ?? '',
                              )
                              .snapshots(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 32),
            const _ReportedItemsSection(type: 'lost'),
            const SizedBox(height: 32),
            const _ReportedItemsSection(type: 'found'),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                final count = snapshot.data?.docs.length.toString() ?? "0";
                return Text(
                  count,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ReportedItemsSection extends StatelessWidget {
  final String type;
  
  const _ReportedItemsSection({required this.type});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final title = type == 'lost' ? "Reported Lost Items" : "Reported Found Items";
    final emptyMessage = type == 'lost' ? "No lost items reported yet" : "No found items reported yet";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lost_items')
              .where('reportedBy', isEqualTo: uid)
              .where('type', isEqualTo: type)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      emptyMessage,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final itemTitle = data['title'] ?? 'No Title';
                final status = data['status'] ?? 'open';
                final imageUrl = data['imageUrl'] as String?;
                final docId = docs[index].id;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItemDetailScreen(itemData: {...data, 'id': docId}),
                      ),
                    );
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholder(),
                              ),
                            )
                          else
                            _buildPlaceholder(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itemTitle,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Status: ${status.toUpperCase()}",
                                  style: TextStyle(
                                    color: status == 'open' ? Colors.blue : Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}
