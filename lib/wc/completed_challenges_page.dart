import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/rewards_page.dart';
import 'package:fyp/ch/settings.dart';
import 'package:fyp/wc/gamification_page.dart';

class CompletedChallengesPage extends StatefulWidget {
  const CompletedChallengesPage({super.key});

  @override
  _CompletedChallengesPageState createState() => _CompletedChallengesPageState();
}

class _CompletedChallengesPageState extends State<CompletedChallengesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _completedChallenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedChallenges();
  }

  Future<void> _loadCompletedChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final challengeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('completed_challenges')
          .get();

      setState(() {
        _completedChallenges = challengeSnapshot.docs
            .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading completed challenges: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load completed challenges: $e'), backgroundColor: Colors.red),
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
            'Please log in to view completed challenges.',
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
        ),
        title: const Text(
          'Completed Challenges',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _completedChallenges.isEmpty
          ? const Center(
        child: Text(
          'No challenges completed yet. Keep going!',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _completedChallenges.length,
        itemBuilder: (context, index) {
          final challenge = _completedChallenges[index];
          return _buildChallengeCard(challenge);
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3, // Settings tab
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            // Navigate to FinancialTipsScreen (assuming it exists)
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GamificationPage()),
            );
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

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    String progressText = '';
    if (challenge['type'] == 'spending' ||
        challenge['type'] == 'no_spend' ||
        challenge['type'] == 'savings') {
      progressText =
      'RM${(challenge['progress'] as num? ?? 0).toStringAsFixed(1)} / RM${(challenge['targetAmount'] as num? ?? 0).toStringAsFixed(1)}';
    } else if (challenge['type'] == 'limit') {
      progressText = '${challenge['progress'] ?? 0} / ${challenge['targetCount'] ?? 0} transactions';
    } else if (challenge['type'] == 'streak') {
      progressText = '${challenge['progress'] ?? 0} / ${challenge['targetDays'] ?? 0} days';
    } else {
      progressText = 'Completed';
    }

    return Card(
      color: const Color.fromRGBO(33, 35, 34, 1),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    challenge['title'] as String? ?? 'Untitled Challenge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.teal, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              challenge['description'] as String? ?? 'No description',
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Final Progress: $progressText',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reward: ${(challenge['badge'] as Map<String, dynamic>?)?['name'] as String? ?? 'No Badge'} Badge',
                  style: const TextStyle(color: Colors.yellow, fontSize: 14),
                ),
                Text(
                  (challenge['badge'] as Map<String, dynamic>?)?['icon'] as String? ?? '🏆',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
              (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Card(
              color: const Color.fromRGBO(33, 35, 34, 1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 18,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 14,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 100,
                      height: 14,
                      color: Colors.grey[700],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}