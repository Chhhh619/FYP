import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class CompletedChallengesPage extends StatefulWidget {
  const CompletedChallengesPage({super.key});

  @override
  _CompletedChallengesPageState createState() => _CompletedChallengesPageState();
}

class _CompletedChallengesPageState extends State<CompletedChallengesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _completedChallenges = [];

  @override
  void initState() {
    super.initState();
    _loadCompletedChallenges();
  }

  Future<void> _loadCompletedChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Load all challenges (including inactive ones for historical records)
      final challengesSnapshot = await _firestore
          .collection('challenges')
          .get();

      // Create a map of challenge details
      Map<String, Map<String, dynamic>> challengeDetails = {};
      for (var doc in challengesSnapshot.docs) {
        challengeDetails[doc.id] = doc.data();
      }

      // Load ONLY user's completed AND claimed challenge progress
      final userChallengesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .where('isCompleted', isEqualTo: true)
          .where('isClaimed', isEqualTo: true)
          .orderBy('claimedAt', descending: true)
          .get();

      List<Map<String, dynamic>> completed = [];

      for (var doc in userChallengesSnapshot.docs) {
        final progressData = doc.data();
        final challengeId = doc.id;
        final challengeData = challengeDetails[challengeId];

        if (challengeData != null) {
          completed.add({
            'id': challengeId,
            ...challengeData,
            'progress': progressData['progress'] ?? 0,
            'completedAt': progressData['completedAt'],
            'claimedAt': progressData['claimedAt'],
          });
        }
      }

      setState(() {
        _completedChallenges = completed;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading completed challenges: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildCompletedChallengeCard(Map<String, dynamic> challenge) {
    final progress = challenge['progress'] ?? 0;
    final target = challenge['targetValue'] ?? 1;
    final completedAt = challenge['completedAt'] as Timestamp?;
    final claimedAt = challenge['claimedAt'] as Timestamp?;

    return Card(
      color: const Color.fromRGBO(33, 35, 34, 1),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      challenge['icon'] ?? '🎯',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                challenge['title'] ?? 'Challenge',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          challenge['description'] ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress bar (always full for completed challenges)
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${target.toInt()}/${target.toInt()}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const Text(
                    '100%',
                    style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Rewards section
              Row(
                children: [
                  const Icon(Icons.stars, color: Colors.yellow, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${challenge['rewardPoints'] ?? 0} points earned',
                    style: const TextStyle(color: Colors.yellow, fontSize: 14),
                  ),
                  if (challenge['rewardBadge'] != null) ...[
                    const SizedBox(width: 16),
                    Text(
                      challenge['rewardBadge']['icon'] ?? '🏆',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      challenge['rewardBadge']['name'] ?? 'Badge',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // Completion dates
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (completedAt != null)
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Completed: ${DateFormat('MMM dd, yyyy \'at\' HH:mm').format(completedAt.toDate())}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  if (claimedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.redeem, color: Colors.yellow, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Claimed: ${DateFormat('MMM dd, yyyy \'at\' HH:mm').format(claimedAt.toDate())}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
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
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFB0BEC5).withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
          : RefreshIndicator(
        color: Colors.teal,
        backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
        onRefresh: _loadCompletedChallenges,
        child: _completedChallenges.isEmpty
            ? _buildEmptyState()
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(33, 35, 34, 1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.green, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '${_completedChallenges.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Challenges Completed',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Your Achievements',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              ..._completedChallenges.map((challenge) => _buildCompletedChallengeCard(challenge)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              SizedBox(height: 60),
              Icon(Icons.emoji_events_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                'No completed challenges yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Complete and claim challenges to see your achievements here!',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              Icon(Icons.trending_up, color: Colors.teal, size: 40),
              SizedBox(height: 8),
              Text(
                'Keep working on your active challenges',
                style: TextStyle(color: Colors.teal, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(33, 35, 34, 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 24,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 120,
                      height: 14,
                      color: Colors.grey[700],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Challenge cards skeleton
          ...List.generate(3, (index) => Card(
            color: const Color.fromRGBO(33, 35, 34, 1),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 150,
                              height: 18,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 200,
                              height: 14,
                              color: Colors.grey[700],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 8,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 120,
                    height: 14,
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}