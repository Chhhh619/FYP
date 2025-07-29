import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/financial_tips.dart';
import 'package:fyp/ch/settings.dart';

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

class TipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<Tip>> getFavoriteTips(String userId) async {
    final feedbackSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tips_feedback')
        .where('isHelpful', isEqualTo: true)
        .get();
    print('Favorite feedback found: ${feedbackSnapshot.docs.length}');

    final favoriteTips = <Tip>[];
    for (var feedbackDoc in feedbackSnapshot.docs) {
      final tipId = feedbackDoc.id;
      final tipSnapshot = await _firestore.collection('tips').doc(tipId).get();
      if (tipSnapshot.exists) {
        final tip = Tip.fromFirestore(tipSnapshot);
        print('Favorite tip: ${tip.title} (${tip.category})');
        favoriteTips.add(tip);
      }
    }
    return favoriteTips;
  }

  Future<void> markTipFeedback(
      String tipId, bool isHelpful, bool isIrrelevant) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tips_feedback')
          .doc(tipId)
          .set({
        'tipId': tipId,
        'isHelpful': isHelpful,
        'isIrrelevant': isIrrelevant,
        'timestamp': Timestamp.now(),
      });
      print('Updated feedback for tip: $tipId, isHelpful: $isHelpful');
    } catch (e) {
      throw Exception('Failed to update tip feedback: $e');
    }
  }
}

class FavoriteTipsScreen extends StatefulWidget {
  const FavoriteTipsScreen({super.key});

  @override
  _FavoriteTipsScreenState createState() => _FavoriteTipsScreenState();
}

class _FavoriteTipsScreenState extends State<FavoriteTipsScreen> {
  final TipService _tipService = TipService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 2; // Align with "Favorites" tab

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for FavoriteTipsScreen');
      return Scaffold(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        body: const Center(
          child: Text(
            'Please log in to view favorite tips',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text(
          'Favorite Tips',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Tip>>(
        future: _tipService.getFavoriteTips(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('FavoriteTips Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading favorite tips: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            print('No favorite tips found');
            return const Center(
              child: Text(
                'No favorite tips yet. Mark tips as helpful to add them here.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          final favoriteTips = snapshot.data!;
          print('Favorite tips displayed: ${favoriteTips.map((t) => t.title).toList()}');

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: favoriteTips.length,
            itemBuilder: (context, index) {
              final tip = favoriteTips[index];
              return Card(
                color: const Color.fromRGBO(33, 35, 34, 1),
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
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () async {
                      try {
                        await _tipService.markTipFeedback(tip.id, false, false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Removed from favorites')),
                        );
                        setState(() {}); // Refresh the list
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                  ),
                ),
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