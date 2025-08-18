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
  int _currentEmojiPage = 0;

  // Extended emoji collection organized by categories
  final List<List<String>> _emojiCategories = [
    // Faces & People
    ['😊', '😂', '😍', '😎', '🤔', '😴', '😢', '😡', '🤗', '🤩', '😇', '🥳', '🤯', '😱', '🤫', '🥰', '😋', '🤤', '🙄', '😏'],
    // Objects & Symbols
    ['💰', '💳', '💎', '💵', '💴', '💶', '💷', '🪙', '💸', '🏦', '🏧', '📊', '📈', '📉', '💹', '🏆', '⭐', '🌟', '🎁', '🎉'],
    // Transportation
    ['🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐', '🛻', '🚚', '🚛', '🚜', '🏍️', '🛵', '🚲', '🛴', '✈️', '🚁'],
    // Food & Drink
    ['🍎', '🍕', '🍔', '🍟', '🌭', '🥪', '🌮', '🌯', '🥙', '🍣', '🍜', '🍝', '🍤', '🍖', '🥩', '🍗', '🥓', '🍞', '🥐', '🧀'],
    // Activities & Entertainment
    ['⚽', '🏀', '🏈', '⚾', '🎾', '🏐', '🏉', '🎱', '🏓', '🏸', '🥅', '🎰', '🎮', '🕹️', '🎲', '♠️', '♥️', '♦️', '♣️', '🃏'],
    // Nature & Places
    ['🏠', '🏡', '🏢', '🏣', '🏤', '🏥', '🏦', '🏧', '🏨', '🏩', '🏪', '🏫', '🏬', '🏭', '🏮', '🏯', '🏰', '🗼', '🗽', '⛪'],
  ];

  final List<String> _categoryNames = [
    'Faces & People',
    'Objects & Symbols',
    'Transportation',
    'Food & Drink',
    'Activities',
    'Places'
  ];

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
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
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
            // Category tabs
            Container(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categoryNames.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _currentEmojiPage = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _currentEmojiPage == index
                              ? Colors.teal.withOpacity(0.8)
                              : const Color.fromRGBO(33, 35, 34, 1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _categoryNames[index],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: _currentEmojiPage == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // Emoji grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: _emojiCategories[_currentEmojiPage].length,
                itemBuilder: (context, index) {
                  final emoji = _emojiCategories[_currentEmojiPage][index];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedEmoji == emoji
                            ? Colors.teal.withOpacity(0.8)
                            : const Color.fromRGBO(33, 35, 34, 1), // Match categories_list.dart
                        shape: BoxShape.circle,
                        border: _selectedEmoji == emoji
                            ? Border.all(color: Colors.teal, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}