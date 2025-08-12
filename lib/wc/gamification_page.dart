import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'rewards_page.dart';
import 'gamification_service.dart';
import 'completed_challenges_page.dart';
import 'point_shop_page.dart';

class GamificationPage extends StatefulWidget {
  const GamificationPage({super.key});

  @override
  _GamificationPageState createState() => _GamificationPageState();
}

class _GamificationPageState extends State<GamificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GamificationService _gamificationService = GamificationService();

  bool _isLoading = true;
  int _userPoints = 0;
  String? _equippedBadge;
  List<Map<String, dynamic>> _activeChallenges = [];
  List<Map<String, dynamic>> _completedChallenges = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadChallenges();
    _checkChallengeCompletion();
  }

  Future<void> _loadUserData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _userPoints = data['points'] ?? 0;
          _equippedBadge = data['equippedBadge'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  // Replace the existing _loadChallenges method in gamification_page.dart

  Future<void> _loadChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Load active challenges
      final activeChallengesSnapshot = await _firestore
          .collection('challenges')
          .where('isActive', isEqualTo: true)
          .get();

      // Load user's challenge progress
      final userChallengesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .get();

      Map<String, Map<String, dynamic>> userProgress = {};
      for (var doc in userChallengesSnapshot.docs) {
        userProgress[doc.id] = doc.data();
      }

      List<Map<String, dynamic>> active = [];
      List<Map<String, dynamic>> completed = [];

      for (var doc in activeChallengesSnapshot.docs) {
        final challengeData = doc.data();
        final challengeId = doc.id;
        final progress = userProgress[challengeId];

        // Only show challenges that have been assigned to the user
        // (i.e., they have an assignedAt timestamp or were created before this tracking system)
        if (progress == null) {
          // Check if this is a new challenge that should be auto-assigned
          final challengeCreatedAt = challengeData['createdAt'] as Timestamp?;
          if (challengeCreatedAt != null) {
            // Auto-assign new active challenges to users who don't have them yet
            await _autoAssignChallenge(challengeId, userId);

            // Create default progress entry
            final defaultProgress = {
              'progress': 0,
              'isCompleted': false,
              'isClaimed': false,
              'assignedAt': Timestamp.now(),
            };

            final challengeWithProgress = {
              'id': challengeId,
              ...challengeData,
              'progress': defaultProgress['progress'],
              'isCompleted': defaultProgress['isCompleted'],
              'isClaimed': defaultProgress['isClaimed'],
              'assignedAt': defaultProgress['assignedAt'],
            };

            active.add(challengeWithProgress);
          }
          continue;
        }

        final challengeWithProgress = {
          'id': challengeId,
          ...challengeData,
          'progress': progress['progress'] ?? 0,
          'isCompleted': progress['isCompleted'] ?? false,
          'isClaimed': progress['isClaimed'] ?? false,
          'completedAt': progress['completedAt'],
          'assignedAt': progress['assignedAt'],
        };

        // Only include challenges that are either:
        // 1. Not completed (active)
        // 2. Completed but not claimed (ready to claim)
        if (challengeWithProgress['isCompleted'] == true &&
            challengeWithProgress['isClaimed'] == true) {
          continue; // These will appear in CompletedChallengesPage
        } else if (challengeWithProgress['isCompleted'] == true &&
            challengeWithProgress['isClaimed'] != true) {
          completed.add(challengeWithProgress); // Ready to claim
        } else {
          active.add(challengeWithProgress); // Active (not completed)
        }
      }

      setState(() {
        _activeChallenges = active;
        _completedChallenges = completed;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to auto-assign a challenge to a user
  Future<void> _autoAssignChallenge(String challengeId, String userId) async {
    try {
      final progressRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .doc(challengeId);

      // Check if already exists
      final existingDoc = await progressRef.get();
      if (!existingDoc.exists) {
        await progressRef.set({
          'progress': 0,
          'isCompleted': false,
          'isClaimed': false,
          'assignedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('Auto-assigned challenge $challengeId to user $userId');
      }
    } catch (e) {
      print('Error auto-assigning challenge: $e');
    }
  }

  Future<void> _checkChallengeCompletion() async {
    await _gamificationService.checkAndUpdateChallenges();
    _loadChallenges(); // Reload to get updated progress
  }

  Future<void> _claimReward(String challengeId, Map<String, dynamic> challenge) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final batch = _firestore.batch();

      // Update user points
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'points': FieldValue.increment(challenge['rewardPoints'] ?? 0),
      });

      // Mark challenge as completed and claimed
      final progressRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .doc(challengeId);

      batch.set(progressRef, {
        'isCompleted': true,
        'isClaimed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'claimedAt': FieldValue.serverTimestamp(),
        'progress': challenge['targetValue'],
      }, SetOptions(merge: true));

      // Add badge if challenge has one
      if (challenge['rewardBadge'] != null) {
        final badgeRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(challenge['rewardBadge']['id']);

        batch.set(badgeRef, {
          'id': challenge['rewardBadge']['id'],
          'name': challenge['rewardBadge']['name'],
          'description': challenge['rewardBadge']['description'],
          'icon': challenge['rewardBadge']['icon'],
          'earnedAt': FieldValue.serverTimestamp(),
          'challengeId': challengeId,
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reward claimed! +${challenge['rewardPoints']} points'),
          backgroundColor: Colors.green,
        ),
      );

      _loadUserData();
      _loadChallenges();
    } catch (e) {
      print('Error claiming reward: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim reward: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final progress = challenge['progress'] ?? 0;
    final target = challenge['targetValue'] ?? 1;
    final isCompleted = challenge['isCompleted'] ?? false;
    final isClaimed = challenge['isClaimed'] ?? false;
    final progressPercentage = (progress / target).clamp(0.0, 1.0);

    return Card(
      color: const Color.fromRGBO(33, 35, 34, 1),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  challenge['icon'] ?? '🎯',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge['title'] ?? 'Challenge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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

            // Progress bar
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progressPercentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.teal,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.toInt()}/${target.toInt()}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  '${(progressPercentage * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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
                  '${challenge['rewardPoints'] ?? 0} points',
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

            if (isCompleted && !isClaimed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _claimReward(challenge['id'], challenge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Claim Reward'),
                ),
              ),
            ],
          ],
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
        body: const Center(
          child: Text(
            'Please log in to view challenges.',
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
          'Challenges',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.yellow),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PointShopPage()),
              );
            },
            tooltip: 'Point Shop',
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.teal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CompletedChallengesPage()),
              );
            },
            tooltip: 'Completed Challenges',
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.yellow),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RewardsPage()),
              );
            },
            tooltip: 'Rewards',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
        color: Colors.teal,
        backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
        onRefresh: () async {
          await _checkChallengeCompletion();
          await _loadUserData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User stats header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(33, 35, 34, 1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.stars, color: Colors.yellow, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '$_userPoints',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Points',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.orange, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '${_activeChallenges.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Active',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          '${_completedChallenges.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Ready to Claim',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active challenges
              if (_activeChallenges.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Active Challenges',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._activeChallenges.map((challenge) => _buildChallengeCard(challenge)),
              ],

              // Completed challenges (ready to claim)
              if (_completedChallenges.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Ready to Claim',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ..._completedChallenges.map((challenge) => _buildChallengeCard(challenge)),
              ],

              if (_activeChallenges.isEmpty && _completedChallenges.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.emoji_events, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No challenges available',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Check back later for new challenges!',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (index) => Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 24,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 14,
                    color: Colors.grey[700],
                  ),
                ],
              )),
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
                        width: 24,
                        height: 24,
                        color: Colors.grey[700],
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
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}