import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/ch/settings.dart';

class FinancialTipsScreen extends StatefulWidget {
  const FinancialTipsScreen({super.key});

  @override
  _FinancialTipsScreenState createState() => _FinancialTipsScreenState();
}

class _FinancialTipsScreenState extends State<FinancialTipsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 2; // Default to "Insights" tab

  Future<void> _markTipIrrelevant(String tipId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tips_footer')
          .doc(tipId)
          .set({
        'isHelpful': false,
        'isIrrelevant': true,
        'timestamp': Timestamp.now(),
      });
      print('Marked tip $tipId as irrelevant for user $userId');
      setState(() {}); // Refresh UI
    } catch (e) {
      print('Error marking tip irrelevant: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update tip feedback: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in');
      return Scaffold(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
        body: const Center(
          child: Text(
            'Please log in to view tips',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
        title: const Text(
          'Financial Tips',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('users')
            .doc(userId)
            .collection('tips_feedback')
            .doc('1')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('StreamBuilder Error: ${snapshot.error}');
            return const Center(
              child: Text(
                'Error loading tips',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }

          final feedbackData = snapshot.data?.data() as Map<String, dynamic>?;
          final isIrrelevant = feedbackData != null && feedbackData['isIrrelevant'] is bool
              ? feedbackData['isIrrelevant'] as bool
              : false;
          print('Tip 1 isIrrelevant: $isIrrelevant');

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                color: const Color.fromRGBO(33, 35, 34, 1),
                child: ListTile(
                  title: const Text(
                    'Cook at Home',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  subtitle: const Text(
                    'Save money by cooking at home instead of dining out.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  trailing: isIrrelevant
                      ? const Text(
                    'Dismissed',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  )
                      : TextButton(
                    onPressed: () => _markTipIrrelevant('1'),
                    child: const Text(
                      'Mark as Irrelevant',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // Update selected index
          });
          if (index == 0) {
            // "Details" selected - navigate to HomePage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 2) {
            // "Insights" selected - stay on FinancialTipsScreen
            // No navigation needed
          } else if (index == 3) {
            // "Mine" selected - navigate to SettingsPage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
          // "Trending" (index 1) only updates _selectedIndex
        },
      ),
    );
  }
}