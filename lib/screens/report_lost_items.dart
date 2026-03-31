import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class ReportLostItem extends StatefulWidget {
  const ReportLostItem({super.key});

  @override
  State<ReportLostItem> createState() => _ReportLostItemState();
}

class _ReportLostItemState extends State<ReportLostItem> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  
  String selectedCategory = "Other";
  String selectedType = "lost"; // Default to lost
  bool _isLoading = false;

  final List<String> categories = [
    "Phone",
    "Wallet",
    "ID Card",
    "Bag",
    "Electronics",
    "Keys",
    "Other",
  ];

  String? selectedLostItemId;
  Map<String, dynamic>? selectedLostItemData;

  void submitItem(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to report items")),
      );
      return;
    }

    if (selectedType == 'lost') {
      if (titleController.text.trim().isEmpty || locationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in the title and location")),
        );
        return;
      }
    } else {
      if (selectedLostItemId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select what lost item you found")),
        );
        return;
      }
      if (locationController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in the location found")),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (selectedType == 'lost') {
        await FirebaseFirestore.instance.collection('lost_items').add({
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'location': locationController.text.trim(),
          'category': selectedCategory,
          'type': 'lost',
          'status': 'open',
          'created_at': FieldValue.serverTimestamp(),
          'reportedBy': currentUser.uid,
        });
      } else {
        await FirebaseFirestore.instance.collection('lost_items').add({
          'lostItemId': selectedLostItemId,
          'finderId': currentUser.uid,
          'reportedBy': currentUser.uid, // backward compat
          'title': selectedLostItemData?['title'] ?? 'Unknown Found Item', // Inherit title for ui displays
          'category': selectedLostItemData?['category'] ?? 'Other',
          'location': locationController.text.trim(),
          'description': descriptionController.text.trim(),
          'type': 'found',
          'status': 'open',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item reported successfully")),
      );

      // Clear the form after submission
      titleController.clear();
      descriptionController.clear();
      locationController.clear();
      setState(() {
        selectedCategory = "Other";
        selectedType = "lost";
        selectedLostItemId = null;
        selectedLostItemData = null;
      });
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error reporting item: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Item")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Found or Lost something?",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "Provide details below to help returning it.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Segmented control for Type (Lost vs Found)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'lost',
                  label: Text('I Lost This'),
                  icon: Icon(Icons.search_off),
                ),
                ButtonSegment<String>(
                  value: 'found',
                  label: Text('I Found This'),
                  icon: Icon(Icons.domain_verification),
                ),
              ],
              selected: {selectedType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  selectedType = newSelection.first;
                });
              },
            ),

            const SizedBox(height: 32),
            
            if (selectedType == 'lost') ...[
              CustomTextField(
                controller: titleController,
                labelText: "Item Title",
                hintText: "e.g., Black Leather Wallet",
                prefixIcon: const Icon(Icons.title),
              ),
              
              const SizedBox(height: 8),
              Text("Category", style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDEE2E6)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue!;
                      });
                    },
                  ),
                ),
              ),
            ] else ...[
              Text("Select Corresponding Lost Item", style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('lost_items').where('type', isEqualTo: 'lost').where('status', isEqualTo: 'open').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return Text("Error loading lost items.", style: TextStyle(color: Theme.of(context).colorScheme.error));
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Text("There are no open lost items. Please wait until someone reports a lost item before marking it found."),
                    );
                  }
                  
                  // Ensure selected item is valid relative to list
                  if (selectedLostItemId != null && !docs.any((d) => d.id == selectedLostItemId)) {
                    // Reset securely via scheduled callback to avoid setState during build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => selectedLostItemId = null);
                    });
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedLostItemId,
                        hint: const Text("Select the lost item you found"),
                        isExpanded: true,
                        items: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final title = (data['title'] ?? 'Unknown').toString();
                          final loc = (data['location'] ?? 'Unknown location').toString();
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text("$title (Lost at: $loc)"),
                            onTap: () {
                              selectedLostItemData = data;
                            },
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedLostItemId = val;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
            
            const SizedBox(height: 24),
            CustomTextField(
              controller: locationController,
              labelText: selectedType == 'lost' ? "Location lost" : "Location found",
              hintText: "e.g., Library 2nd Floor",
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            
            CustomTextField(
              controller: descriptionController,
              labelText: "Description (Optional)",
              hintText: "Any identifying details or instructions...",
              maxLines: 4,
            ),
            
            const SizedBox(height: 32),
            PrimaryButton(
              text: "Submit Report",
              isLoading: _isLoading,
              onPressed: () => submitItem(context),
            ),
          ],
        ),
      ),
    );
  }
}
