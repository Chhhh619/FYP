import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/financial_tips.dart';
import 'package:fyp/ch/settings.dart';

class FavoriteTipsScreen extends StatefulWidget {
  const FavoriteTipsScreen({super.key});

  @override
  _FavoriteTipsScreenState createState() => _FavoriteTipsScreenState();
}

class _FavoriteTipsScreenState extends State<FavoriteTipsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 2; // Align with "Favorites" tab

  Future<void> _unlikeTip(String tipId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tips_feedback')
          .doc(tipId)
          .update({
        'isHelpful': false,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tip removed from favorites')),
      );
    } catch (e) {
      print('Error unliking tip: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unlike tip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        body: const Center(
          child: Text(
            'Please log in to view favorite tips.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back to Tips',
        ),
        title: const Text(
          'Favorite Tips',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(userId)
            .collection('tips_feedback')
            .where('isHelpful', isEqualTo: true)
            .snapshots(),
        builder: (context, feedbackSnapshot) {
          if (feedbackSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (feedbackSnapshot.hasError) {
            print('Feedback StreamBuilder Error: ${feedbackSnapshot.error}');
            return Center(
              child: Text(
                'Error loading favorite tips: ${feedbackSnapshot.error}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }
          if (!feedbackSnapshot.hasData || feedbackSnapshot.data!.docs.isEmpty) {
            print('No favorite tips found');
            return const Center(
              child: Text(
                'No favorite tips yet. Mark tips as helpful to add them here!',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          final feedbackDocs = feedbackSnapshot.data!.docs;
          print('Favorite tips found: ${feedbackDocs.length}');

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: feedbackDocs.length,
            itemBuilder: (context, index) {
              final feedback = feedbackDocs[index].data() as Map<String, dynamic>;
              final tipId = feedback['tipId'] as String;

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('tips').doc(tipId).get(),
                builder: (context, tipSnapshot) {
                  if (tipSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (tipSnapshot.hasError || !tipSnapshot.hasData || !tipSnapshot.data!.exists) {
                    print('Error or missing tip data for tipId: $tipId');
                    return const SizedBox.shrink();
                  }

                  final tipData = tipSnapshot.data!.data() as Map<String, dynamic>;
                  final tip = Tip(
                    id: tipId,
                    title: tipData['title'] ?? 'Unknown',
                    description: tipData['description'] ?? '',
                    category: tipData['category'] ?? 'unknown',
                  );

                  return Card(
                    color: const Color.fromRGBO(33, 35, 34, 1),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: Icon(
                        _getIconForCategory(tip.category),
                        color: Colors.white,
                      ),
                      title: Text(
                        tip.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      subtitle: Text(
                        tip.description,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.thumb_up, color: Colors.green),
                        onPressed: () => _unlikeTip(tip.id),
                        tooltip: 'Remove from Favorites',
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FinancialTipsScreen()),
            );
          } else if (index == 2) {
            // Stay on FavoriteTipsScreen
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
        },
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'dining':
        return Icons.restaurant;
      case 'budgeting':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'debt':
        return Icons.money_off;
      case 'shopping':
        return Icons.shopping_cart;
      case 'transport':
        return Icons.directions_bus;
      case 'subscription':
        return Icons.subscriptions;
      default:
        return Icons.attach_money;
    }
  }
}

class Tip {
  final String id;
  final String title;
  final String description;
  final String category;

  Tip({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
  });

  factory Tip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tip(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
    );
  }
}