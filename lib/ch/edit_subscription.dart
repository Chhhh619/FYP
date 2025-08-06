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

class EditSubscriptionPage extends StatefulWidget {
  final String subscriptionId;
  final Map<String, dynamic> subscriptionData;

  const EditSubscriptionPage({
    super.key,
    required this.subscriptionId,
    required this.subscriptionData,
  });

  @override
  State<EditSubscriptionPage> createState() => _EditSubscriptionPageState();
}

class _EditSubscriptionPageState extends State<EditSubscriptionPage> {
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

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _loadSelectedCard();
  }

  void _initializeFields() {
    final data = widget.subscriptionData;
    _nameController.text = data['name'] ?? '';
    _amountController.text = (data['amount'] ?? 0.0).toString();
    _startDate = (data['startDate'] as Timestamp).toDate();
    _repeatType = data['repeat'] ?? 'Monthly';
    _selectedIcon = data['icon'] ?? '';
  }

  Future<void> _loadSelectedCard() async {
    final fromCardId = widget.subscriptionData['fromCardId'];
    if (fromCardId != null && fromCardId.isNotEmpty) {
      try {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          final cardDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(fromCardId)
              .get();

          if (cardDoc.exists) {
            final cardData = cardDoc.data()!;
            setState(() {
              _selectedCard = {
                'id': cardDoc.id,
                'name': cardData['name'] ?? 'Unknown Card',
                'balance': (cardData['balance'] ?? 0.0).toDouble(),
              };
            });
          }
        }
      } catch (e) {
        print('Error loading selected card: $e');
      }
    }
  }

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
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose Icon', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: GridView.builder(
                  itemCount: _localIcons.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final icon = _localIcons[index];
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
                        radius: 30,
                        backgroundColor: Colors.teal.withOpacity(0.2),
                        backgroundImage: AssetImage(icon['path']!),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.grey),
              TextButton.icon(
                onPressed: _pickCustomImage,
                icon: const Icon(Icons.upload, color: Colors.cyan),
                label: const Text('Upload your own icon', style: TextStyle(color: Colors.cyan)),
              ),
            ],
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
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
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

  Future<void> _updateSubscription() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    String? iconToSave;

    // Determine which icon to save
    if (_croppedImage != null) {
      // New custom image uploaded
      iconToSave = await _uploadImageToStorage(_croppedImage!, user.uid);
      if (iconToSave == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
        return;
      }
    } else if (_selectedIcon.isNotEmpty) {
      // Selected from local icons or keeping existing
      iconToSave = _selectedIcon;
    } else {
      // Fallback
      iconToSave = '❔';
    }

    try {
      await _firestore.collection('subscriptions').doc(widget.subscriptionId).update({
        'name': _nameController.text.trim(),
        'amount': amount,
        'startDate': Timestamp.fromDate(_startDate),
        'repeat': _repeatType,
        'icon': iconToSave,
        'fromCardId': _selectedCard?['id'],
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription updated successfully')),
      );

      Navigator.pop(context, true); // Return true to indicate successful update
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update subscription: $e')),
      );
    }
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
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

  Widget _buildCurrentIcon() {
    // If there's a cropped image, show it
    if (_croppedImage != null) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.teal.withOpacity(0.2),
        backgroundImage: MemoryImage(_croppedImage!),
      );
    }

    // If there's a custom file, show it
    if (_customIconFile != null) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.teal.withOpacity(0.2),
        backgroundImage: FileImage(_customIconFile!),
      );
    }

    // If selected icon is an asset path
    if (_selectedIcon.isNotEmpty && _selectedIcon.startsWith('assets/')) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.teal.withOpacity(0.2),
        backgroundImage: AssetImage(_selectedIcon),
      );
    }

    // If selected icon is a URL (existing custom icon)
    if (_selectedIcon.isNotEmpty && (_selectedIcon.startsWith('http://') || _selectedIcon.startsWith('https://'))) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.teal.withOpacity(0.2),
        backgroundImage: NetworkImage(_selectedIcon),
      );
    }

    // If selected icon is an emoji or text
    if (_selectedIcon.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: Colors.teal.withOpacity(0.2),
        child: Text(_selectedIcon, style: const TextStyle(fontSize: 16)),
      );
    }

    // Default fallback
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.teal.withOpacity(0.2),
      child: const Icon(Icons.image, color: Colors.teal),
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
        title: const Text('Edit Subscription', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 32.0),
        child: ElevatedButton(
          onPressed: _updateSubscription,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Update Subscription', style: TextStyle(color: Colors.white)),
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
                  child: _buildCurrentIcon(),
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