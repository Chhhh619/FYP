import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:crop_your_image/crop_your_image.dart';

class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  DateTime _startDate = DateTime.now();
  String _repeatType = 'Monthly';
  String _selectedIcon = '';
  File? _customIconFile;
  Uint8List? _croppedImage;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final CropController _cropController = CropController();

  void _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  void _showRepeatTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Repeat Type', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: ['Daily', 'Weekly', 'Monthly', 'Annually'].map((type) {
                  return ChoiceChip(
                    label: Text(type, style: const TextStyle(color: Colors.white)),
                    selected: _repeatType == type,
                    selectedColor: Colors.teal,
                    backgroundColor: Colors.grey[800],
                    onSelected: (_) {
                      setState(() => _repeatType = type);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> fetchSubscriptionCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('type', isEqualTo: 'subscription')
        .get();
    return snapshot.docs;
  }

  void _showIconSelector() {
    final List<Map<String, String>> localIcons = [
      {'label': 'Netflix', 'path': 'assets/images/netflix.png'},
      {'label': 'Spotify', 'path': 'assets/images/spotify.png'},
      {'label': 'YouTube', 'path': 'assets/images/youtube.png'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose Icon', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: localIcons.map((icon) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon['path']!;
                          _customIconFile = null;
                          _croppedImage = null;
                        });
                        Navigator.pop(context);
                      },
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal.withOpacity(0.2),
                        backgroundImage: AssetImage(icon['path']!),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(color: Colors.grey),
                TextButton.icon(
                  onPressed: _pickCustomImage,
                  icon: const Icon(Icons.upload, color: Colors.cyan),
                  label: const Text('Upload your own icon', style: TextStyle(color: Colors.cyan)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCustomImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      _openCropper(bytes);
    }
  }

  void _openCropper(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Crop(
            controller: _cropController,
            image: imageBytes,
            onCropped: (cropped) {
              setState(() => _croppedImage = cropped);
              _customIconFile = null;
              _selectedIcon = '';
              Navigator.pop(context);
              Navigator.pop(context);
            },
            withCircleUi: true,
            baseColor: Colors.black,
            maskColor: Colors.black.withOpacity(0.6),
            radius: 150,
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadImageToStorage(Uint8List imageBytes, String userId) async {
    try {
      final storageRef = _storage.ref().child('subscription_icons/$userId/${DateTime.now().millisecondsSinceEpoch}.png');
      final uploadTask = await storageRef.putData(imageBytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _submitSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    String? iconToSave = _selectedIcon.isNotEmpty ? _selectedIcon : null;

    if (_croppedImage != null) {
      iconToSave = await _uploadImageToStorage(_croppedImage!, user.uid);
      if (iconToSave == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
        return;
      }
    }

    final categoryRef = _firestore.collection('categories').doc('qOIeFiz2HjETIU1dyerW');

    await _firestore.collection('subscriptions').add({
      'userId': user.uid,
      'name': _nameController.text.trim(),
      'amount': amount,
      'startDate': Timestamp.fromDate(_startDate),
      'repeat': _repeatType,
      'icon': iconToSave ?? '❔',
      'category': categoryRef,
      });

    Navigator.pop(context);
  }

  Widget _buildCard({required Widget child}) {
    return Card(
      color: const Color.fromRGBO(33, 35, 34, 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add new Subscription', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
        child: ElevatedButton(
          onPressed: _submitSubscription,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Add Subscription', style: TextStyle(color: Colors.white)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _showIconSelector,
                      customBorder: const CircleBorder(),
                      splashColor: Colors.teal.withOpacity(0.3),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.teal.withOpacity(0.2),
                        backgroundImage: _customIconFile != null
                            ? FileImage(_customIconFile!)
                            : _croppedImage != null
                            ? MemoryImage(_croppedImage!) as ImageProvider
                            : (_selectedIcon.isNotEmpty
                            ? AssetImage(_selectedIcon)
                            : null),
                        child: (_customIconFile == null && _croppedImage == null && _selectedIcon.isEmpty)
                            ? const Icon(Icons.image, color: Colors.teal)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter name',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.yellow),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'RM0',
                        hintStyle: TextStyle(color: Colors.cyan),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      DateFormat('d MMM yyyy').format(_startDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar, color: Colors.cyan),
                    onPressed: _pickStartDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Row(
                children: [
                  const Icon(Icons.repeat, color: Colors.cyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _repeatType,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.cyan),
                    onPressed: _showRepeatTypeSelector,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}