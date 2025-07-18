import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomCategoryPage extends StatefulWidget {
  final String type;

  const CustomCategoryPage({super.key, required this.type});

  @override
  _CustomCategoryPageState createState() => _CustomCategoryPageState();
}

class _CustomCategoryPageState extends State<CustomCategoryPage> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '😊';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveCategory() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _nameController.text.isEmpty) return;

    setState(() => _isSaving = true);
    await _firestore.collection('categories').add({
      'name': _nameController.text,
      'icon': _selectedEmoji,
      'type': widget.type,
      'userId': userId,
    });
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveCategory,
            child: Text(
              'Add',
              style: TextStyle(color: _isSaving ? Colors.grey : Colors.teal),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom spend type',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Type Name',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal),
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                for (var emoji in [
                  '😊', '😂', '😍', '😎', '🤓', '😴', '😢', '😡', '🤔', '👍', '👎', '🎉',
                  '❤️', '💔', '💰', '⭐', '🌟', '🍎', '🚗', '🏠'
                ])
                  GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: CircleAvatar(
                      backgroundColor: _selectedEmoji == emoji ? Colors.teal : Colors.grey,
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}