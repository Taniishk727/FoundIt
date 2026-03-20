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

  void submitItem(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to report items")),
      );
      return;
    }

    if (titleController.text.trim().isEmpty || locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in the title and location")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('lost_items').add({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'location': locationController.text.trim(),
        'category': selectedCategory,
        'type': selectedType,
        'status': 'open',
        'created_at': FieldValue.serverTimestamp(),
        'reportedBy': currentUser.uid,
      });

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
            
            const SizedBox(height: 24),
            CustomTextField(
              controller: locationController,
              labelText: "Location found/lost",
              hintText: "e.g., Library 2nd Floor",
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
            
            CustomTextField(
              controller: descriptionController,
              labelText: "Description (Optional)",
              hintText: "Any identifying details...",
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
