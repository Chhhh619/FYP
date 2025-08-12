import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'select_card_popup.dart';
import 'dart:convert';

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
  Map<String, dynamic>? _selectedCard;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final CropController _cropController = CropController();

  final List<Map<String, String>> _localIcons = [
    {'label': 'Netflix', 'path': 'assets/images/netflix.png'},
    {'label': 'Spotify', 'path': 'assets/images/spotify.png'},
    {'label': 'YouTube', 'path': 'assets/images/youtube.png'},
  ];

  void _selectCard() async {
    final selectedCard = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectCardPopup(
        onCardSelected: (card) {
          Navigator.pop(context, card);
        },
      ),
    );
    if (selectedCard != null) {
      setState(() {
        _selectedCard = selectedCard;
      });
    }
  }

  void _showIconSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        // Use StatefulBuilder to make the modal rebuild when setState is called
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Choose Icon',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Prebuilt Icons Section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Popular Services',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: GridView.builder(
                      itemCount: _localIcons.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final icon = _localIcons[index];
                        final isSelected = _selectedIcon == icon['path'];

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIcon = icon['path']!;
                              _customIconFile = null;
                              _croppedImage = null;
                            });
                            Navigator.pop(context);
                          },
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: Colors.teal, width: 3)
                                      : null,
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.teal.withOpacity(0.2),
                                  backgroundImage: AssetImage(icon['path']!),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                icon['label']!,
                                style: TextStyle(
                                  color: isSelected ? Colors.teal : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 16),

                  // Custom Upload Section
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Custom Icon',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Show current custom icon if exists
                  if (_croppedImage != null) ...[
                    GestureDetector(
                      onTap: _pickCustomImage, // Make the entire row clickable to retrigger cropper
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.teal, width: 3),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundImage: MemoryImage(_croppedImage!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Custom Icon Selected',
                                  style: TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Text(
                                  'Tap to change',
                                  style: TextStyle(
                                    color: Colors.cyan,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // Update both the main widget state AND the modal state
                              setState(() {
                                _croppedImage = null;
                                _customIconFile = null;
                                _selectedIcon = '';
                              });
                              setModalState(() {}); // This rebuilds the modal
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Upload Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _pickCustomImage,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.upload, color: Colors.cyan),
                      label: Text(
                        _croppedImage != null ? 'Change Custom Icon' : 'Upload Your Own Icon',
                        style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
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
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Container(
          width: double.maxFinite,
          height: 500,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Crop Your Icon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Cropper
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Crop(
                    controller: _cropController,
                    image: imageBytes,
                    onCropped: (cropped) {
                      setState(() {
                        _croppedImage = cropped;
                        _customIconFile = null;
                        _selectedIcon = '';
                      });
                      Navigator.pop(context);
                      Navigator.pop(context); // Close icon selector too

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Custom icon uploaded successfully!'),
                          backgroundColor: Colors.teal,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    withCircleUi: true,
                    baseColor: Colors.black,
                    maskColor: Colors.black.withOpacity(0.7),
                    radius: 120,
                    interactive: true,
                  ),
                ),
              ),

              // Instructions & Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Drag to reposition • Pinch to zoom',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.grey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () => _cropController.crop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Crop & Use',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _processCustomIcon(Uint8List imageBytes) {
    try {
      // Convert to base64 string with data URI prefix
      final base64String = 'data:image/png;base64,${base64Encode(imageBytes)}';

      // Check size limit (Firestore has 1MB document limit)
      if (base64String.length > 500000) { // 500KB limit to be safe
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image too large. Please choose a smaller image.'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      return base64String;
    } catch (e) {
      print('Error processing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process image. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
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
          child: Wrap(
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
        );
      },
    );
  }

  Future<void> _submitSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    String? iconToSave = _selectedIcon.isNotEmpty ? _selectedIcon : null;

    if (_croppedImage != null) {
      iconToSave = _processCustomIcon(_croppedImage!);
      if (iconToSave == null) {
        return; // Error already shown in _processCustomIcon
      }
    }

    try {
      await _firestore.collection('subscriptions').add({
        'userId': user.uid,
        'name': _nameController.text.trim(),
        'amount': amount,
        'startDate': Timestamp.fromDate(_startDate),
        'repeat': _repeatType,
        'icon': iconToSave ?? '❔',
        'fromCardId': _selectedCard?['id'],
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription added successfully!'),
          backgroundColor: Colors.teal,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add subscription: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  })

  {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.tealAccent),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white70))),
            trailing,
          ],
        ),
      ),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Icon + Name Row
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showIconSelector,
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
                    child: (_customIconFile == null &&
                        _croppedImage == null &&
                        _selectedIcon.isEmpty)
                        ? const Icon(Icons.image, color: Colors.teal)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
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

          _buildTile(
            icon: Icons.attach_money,
            title: 'Amount',
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),

          // Start Date
          _buildTile(
            icon: Icons.calendar_today,
            title: 'Start Date',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('d MMM yyyy').format(_startDate), style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
              ],
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setState(() => _startDate = picked);
              }
            },
          ),

          // Repeat
          _buildTile(
            icon: Icons.repeat,
            title: 'Repeat',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_repeatType, style: const TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down, color: Colors.white),
              ],
            ),
            onTap: _showRepeatTypeSelector,
          ),

          // From Card
          _buildTile(
            icon: Icons.credit_card,
            title: 'From Card',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedCard != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_selectedCard!['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                      Text('RM${(_selectedCard!['balance'] ?? 0.0).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ] else ...[
                  const Text('Select Card', style: TextStyle(color: Colors.white54)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ],
            ),
            onTap: _selectCard,
          ),
        ],
      ),
    );
  }
}
