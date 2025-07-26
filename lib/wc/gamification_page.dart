import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fyp/wc/completed_challenges_page.dart';

class GamificationPage extends StatefulWidget {
  const GamificationPage({super.key});

  @override
  _GamificationPageState createState() => _GamificationPageState();
}

class _GamificationPageState extends State<GamificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> userChallenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChallenges();
    _listenToTransactions();
    _listenToBudgets();
    _listenToNoSpendChallenge();
  }

  Future<void> _initializeChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _startDefaultChallenges(userId);
    await _loadChallenges();
  }

  Future<void> _startDefaultChallenges(String userId) async {
    final now = DateTime.now();
    final defaultChallenges = [
      {
        'id': 'first_transaction',
        'title': 'Add Your First Transaction',
        'description': 'Record your first income or expense in the app.',
        'type': 'onboarding',
        'targetAmount': 1,
        'progress': 0.0,
        'points': 10,
        'badge': {
          'id': 'badge_first_transaction',
          'name': 'First Step',
          'description': 'Recorded your first transaction',
          'icon': '🎉',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'id': 'set_budget',
        'title': 'Set Your First Budget',
        'description': 'Set a monthly budget to start tracking your spending.',
        'type': 'onboarding',
        'targetAmount': 1,
        'progress': 0.0,
        'points': 15,
        'badge': {
          'id': 'badge_budget_setter',
          'name': 'Budget Beginner',
          'description': 'Set your first budget',
          'icon': '💰',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'id': 'no_spend_day',
        'title': 'No-Spend Day',
        'description': 'Avoid spending for one day to earn this challenge.',
        'type': 'no_spend',
        'targetAmount': 1,
        'progress': 0.0,
        'points': 5,
        'badge': {
          'id': 'badge_no_spend',
          'name': 'Frugal Day',
          'description': 'Completed a no-spend day',
          'icon': '🛑',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
        'lastChecked': Timestamp.fromDate(now),
      },
    ];

    for (var challenge in defaultChallenges) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('challenges')
            .doc(challenge['id'] as String?) // Cast to String?
            .set(challenge, SetOptions(merge: true));
      } catch (e) {
        print('Error saving challenge: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save challenge: $e')),
        );
      }
    }
  }

  Future<void> _listenToTransactions() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      final transactions = snapshot.docs;
      final challengesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .get();

      for (var challengeDoc in challengesSnapshot.docs) {
        final challenge = challengeDoc.data();
        if (challenge['type'] == 'onboarding' &&
            challenge['id'] == 'first_transaction') {
          final progress = transactions.isNotEmpty ? 1.0 : 0.0;
          final completed = progress >= 1.0;
          await _updateChallengeProgress(
            userId,
            challenge['id'],
            progress,
            completed,
            challenge,
          );
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToBudgets() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .snapshots()
        .listen((snapshot) async {
      final budgets = snapshot.docs;
      final challengeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .doc('set_budget')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        final progress = budgets.isNotEmpty ? 1.0 : 0.0;
        final completed = progress >= 1.0;
        await _updateChallengeProgress(
          userId,
          'set_budget',
          progress,
          completed,
          challenge,
        );
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToNoSpendChallenge() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      final transactions = snapshot.docs;
      final challengeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .doc('no_spend_day')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        final lastChecked = (challenge['lastChecked'] as Timestamp).toDate();
        final now = DateTime.now();
        if (now.day != lastChecked.day) {
          final todayExpenses = transactions.where((tx) {
            final txDate = (tx.data()['timestamp'] as Timestamp).toDate();
            final categoryRef = tx.data()['category'] as DocumentReference;
            return txDate.day == now.day &&
                txDate.month == now.month &&
                txDate.year == now.year &&
                categoryRef.path.contains('expense');
          }).toList();

          final progress = todayExpenses.isEmpty ? 1.0 : 0.0;
          final completed = progress >= 1.0;
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('challenges')
              .doc('no_spend_day')
              .update({
            'progress': progress,
            'completed': completed,
            'lastChecked': Timestamp.fromDate(now),
          });

          if (completed && challenge['badge'] != null) {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('badges')
                .doc(challenge['badge']['id'])
                .set(challenge['badge'], SetOptions(merge: true));
            if (challenge['points'] != null) {
              await _awardPoints(userId, challenge['points']);
            }
          }
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _updateChallengeProgress(String userId,
      String challengeId,
      double progress,
      bool completed,
      Map<String, dynamic> challenge,) async {
    final challengeRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc(challengeId);

    if (completed) {
      // Move to completed_challenges
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('completed_challenges')
          .doc(challengeId)
          .set({
        ...challenge,
        'progress': progress,
        'completed': true,
        'completedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      // Delete from challenges
      await challengeRef.delete();

      // Award points and badge
      if (challenge['badge'] != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(challenge['badge']['id'] as String?)
            .set(challenge['badge'], SetOptions(merge: true));
      }
      if (challenge['points'] != null) {
        await _awardPoints(userId, challenge['points'] as int);
      }
    } else {
      // Update progress in challenges
      await challengeRef.update({
        'progress': progress,
        'completed': completed,
      });
    }
  }

  Future<void> _awardPoints(String userId, int points) async {
    final userRef = _firestore.collection('users').doc(userId);
    await userRef.set({
      'points': FieldValue.increment(points),
    }, SetOptions(merge: true));
  }

  Future<void> _loadChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .get();
      setState(() {
        userChallenges = snapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinCommunityChallenge(String challengeId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final communityChallenge = await _firestore
        .collection('community_challenges')
        .doc(challengeId)
        .get();
    if (!communityChallenge.exists) return;

    final challengeData = communityChallenge.data()!;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc(challengeId)
        .set({
      ...challengeData,
      'progress': 0.0,
      'completed': false,
      'joinedAt': Timestamp.now(),
    }, SetOptions(merge: true));

    await _firestore
        .collection('community_challenges')
        .doc(challengeId)
        .update({
      'participants': FieldValue.arrayUnion([userId]),
    });

    await _loadChallenges();
  }

  Future<void> _updateLeaderboardChallenge(String challengeId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final challengeDoc = await _firestore
        .collection('community_challenges')
        .doc(challengeId)
        .get();
    if (!challengeDoc.exists) return;

    final challengeData = challengeDoc.data()!;
    final participants = challengeData['participants'] as List<dynamic>;
    final startDate = (challengeData['startDate'] as Timestamp).toDate();
    final endDate = (challengeData['endDate'] as Timestamp).toDate();
    final targetCategory = challengeData['targetCategory'] ?? 'Dining';

    final diningSpends = <String, double>{};

    for (var participantId in participants) {
      final transactions = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: participantId)
          .where(
          'timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      double diningSpend = 0.0;
      for (var tx in transactions.docs) {
        final categoryRef = tx.data()['category'] as DocumentReference;
        final categorySnap = await categoryRef.get();
        if (categorySnap['name'] == targetCategory &&
            categorySnap['type'] == 'expense') {
          diningSpend += (tx.data()['amount'] as num).toDouble().abs();
        }
      }
      diningSpends[participantId] = diningSpend;
    }

    final sortedUsers = diningSpends.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final top10Percent = sortedUsers
        .take((sortedUsers.length * 0.1).ceil())
        .toList();

    if (top10Percent.any((entry) => entry.key == userId)) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .doc(challengeId)
          .update({
        'progress': 1.0,
        'completed': true,
      });

      final badge = challengeData['badge'];
      if (badge != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badge['id'])
            .set(badge, SetOptions(merge: true));
      }
      if (challengeData['points'] != null) {
        await _awardPoints(userId, challengeData['points']);
      }
    }
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    final progress = (challenge['progress'] as double?)?.clamp(0.0, 1.0) ?? 0.0;
    return Card(
      color: Color.fromRGBO(33, 35, 34, 1),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          challenge['title'],
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              challenge['description'],
              style: TextStyle(color: Colors.grey[400]),
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[700],
              valueColor: AlwaysStoppedAnimation(Colors.teal),
            ),
            SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% Complete',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        trailing: challenge['completed']
            ? Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }

  Widget _buildCommunityChallenges() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('community_challenges').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final challenges = snapshot.data!.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        if (challenges.isEmpty) {
          return Text(
            'No community challenges available',
            style: TextStyle(color: Colors.grey[400]),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community Challenges',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            ...challenges.map((challenge) =>
                Card(
                  color: Color.fromRGBO(33, 35, 34, 1),
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      challenge['title'],
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      challenge['description'],
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        await _joinCommunityChallenge(challenge['id']);
                        if (challenge['type'] == 'leaderboard') {
                          await _updateLeaderboardChallenge(challenge['id']);
                        }
                      },
                      child: Text('Join'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        body: Center(
          child: Text(
            'Please log in to view challenges',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
          // Brighter, larger back button
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Challenges',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white, size: 30),
            // Prominent history button
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => CompletedChallengesPage()),
              );
            },
            tooltip: 'View Completed Challenges',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCommunityChallenges(),
            SizedBox(height: 24),
            Text(
              'Your Challenges',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            userChallenges.isEmpty
                ? Center(
              child: Text(
                'No challenges available',
                style: TextStyle(color: Colors.grey[400]),
              ),
            )
                : Column(
              children: userChallenges
                  .map((challenge) => _buildChallengeCard(challenge))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}