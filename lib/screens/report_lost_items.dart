import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

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
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (pickedFile != null) setState(() => _selectedImage = File(pickedFile.path));
              },
            ),
          ],
        ),
      ),
    );
  }



Future<String?> uploadImage(File imageFile) async {
  try {
    const cloudName = "dpexojfur"; 
    const uploadPreset = "found_it_unsigned"; 

    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    debugPrint(" Uploading to Cloudinary: ${imageFile.path}");

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      final imageUrl = jsonData['secure_url'];

      debugPrint(" Cloudinary URL: $imageUrl");

      return imageUrl;
    } else {
      debugPrint(" Upload failed: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    debugPrint(" Cloudinary error: $e");
    return null;
  }
}

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
      final itemDocRef = FirebaseFirestore.instance.collection('lost_items').doc();
      String? imageUrl;

      if (_selectedImage != null) {
  final file = File(_selectedImage!.path);

  debugPrint("🧪 Checking file...");
  debugPrint("PATH: ${file.path}");
  debugPrint("EXISTS: ${file.existsSync()}");

  if (file.existsSync()) {
    imageUrl = await uploadImage(file);
    debugPrint("DEBUG: Uploaded Image URL: $imageUrl");
  } else {
    debugPrint("File invalid, skipping upload");
  }
}

      debugPrint("DEBUG: Final imageUrl before saving to Firestore: ${imageUrl ?? 'null'}");

      if (selectedType == 'lost') {
        await itemDocRef.set({
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'location': locationController.text.trim(),
          'category': selectedCategory,
          'type': 'lost',
          'status': 'open',
          'created_at': FieldValue.serverTimestamp(),
          'reportedBy': currentUser.uid,
          'imageUrl': imageUrl,
        });
      } else {
        await itemDocRef.set({
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
          'imageUrl': imageUrl ?? "",
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
        _selectedImage = null;
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
            
            const SizedBox(height: 24),
            Text("Image (Optional)", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_selectedImage != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_a_photo),
                label: const Text("Upload Image"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
