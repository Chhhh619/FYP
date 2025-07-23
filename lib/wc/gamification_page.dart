import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/rewards_page.dart';
import 'package:fyp/ch/settings.dart';
import 'package:fyp/wc/completed_challenges_page.dart';

class GamificationPage extends StatefulWidget {
  const GamificationPage({super.key});

  @override
  _GamificationPageState createState() => _GamificationPageState();
}

class _GamificationPageState extends State<GamificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
    _listenToTransactions();
  }

  void _listenToTransactions() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docChanges.isNotEmpty) {
        _loadChallenges();
      }
    });
  }

  Future<void> _startChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final defaultChallenges = <Map<String, dynamic>>[
        {
          'id': 'save_fixed',
          'title': 'Save RM200',
          'description': 'Add RM200 to your savings via any income transaction this month.',
          'type': 'savings',
          'targetAmount': 200.0,
          'category': 'Savings',
          'progress': 0.0,
          'badge': {
            'id': 'badge_savings_hero',
            'name': 'Savings Hero',
            'description': 'Saved RM200 in income transactions',
            'icon': '💰',
          },
          'completed': false,
          'createdAt': Timestamp.now(),
        },
        {
          'id': 'streak_logging',
          'title': '3-Day Logging Streak',
          'description': 'Log transactions for 3 consecutive days.',
          'type': 'streak',
          'targetDays': 3,
          'progress': 0,
          'badge': {
            'id': 'badge_logging_streak',
            'name': 'Logging Streak',
            'description': 'Logged transactions for 3 consecutive days',
            'icon': '📅',
          },
          'completed': false,
          'createdAt': Timestamp.now(),
        },
      ];

      for (var challenge in defaultChallenges) {
        final challengeId = challenge['id'] as String?;
        if (challengeId != null) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('challenges')
              .doc(challengeId)
              .set(challenge, SetOptions(merge: true));
        }
      }

      await _generateDynamicChallenges(userId);
      await _loadChallenges();
    } catch (e) {
      print('Error starting challenges: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start challenges: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _generateDynamicChallenges(String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final transactionSnapshot = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      Map<String, double> categorySpending = {};
      for (var doc in transactionSnapshot.docs) {
        final data = doc.data();
        final categoryRef = data['category'] as DocumentReference;
        final categorySnapshot = await categoryRef.get();
        final categoryName = categorySnapshot.get('name') as String? ?? 'unknown';
        final categoryType = categorySnapshot.get('type') as String? ?? 'unknown';
        final amount = (data['amount'] is int)
            ? (data['amount'] as int).toDouble()
            : (data['amount'] as double? ?? 0.0);
        if (categoryType == 'expense') {
          categorySpending[categoryName] = (categorySpending[categoryName] ?? 0.0) + amount.abs();
        }
      }

      List<Map<String, dynamic>> dynamicChallenges = [];
      if (categorySpending.isNotEmpty) {
        final highestCategory = categorySpending.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        if (highestCategory.value > 50) {
          dynamicChallenges.add({
            'id': 'reduce_${highestCategory.key.toLowerCase()}',
            'title': 'Reduce ${highestCategory.key} Spending',
            'description':
            'Spend less than RM${(highestCategory.value * 0.75).toStringAsFixed(0)} on ${highestCategory.key} this month.',
            'type': 'spending',
            'targetAmount': highestCategory.value * 0.75,
            'category': highestCategory.key,
            'progress': 0.0,
            'badge': {
              'id': 'badge_${highestCategory.key.toLowerCase()}_saver',
              'name': '${highestCategory.key} Saver',
              'description': 'Reduced ${highestCategory.key} spending by 25%',
              'icon': '🏅',
            },
            'completed': false,
            'createdAt': Timestamp.now(),
          });
        }

        if (categorySpending.length > 1) {
          final lowestCategory = categorySpending.entries
              .reduce((a, b) => a.value < b.value ? a : b);
          if (lowestCategory.value > 0) {
            dynamicChallenges.add({
              'id': 'no_spend_${lowestCategory.key.toLowerCase()}',
              'title': 'No ${lowestCategory.key} Spending',
              'description':
              'Avoid spending on ${lowestCategory.key} for the rest of the month.',
              'type': 'no_spend',
              'targetAmount': 0.0,
              'category': lowestCategory.key,
              'progress': 0.0,
              'badge': {
                'id': 'badge_no_${lowestCategory.key.toLowerCase()}',
                'name': 'No ${lowestCategory.key} Champion',
                'description': 'Avoided spending on ${lowestCategory.key}',
                'icon': '🚫',
              },
              'completed': false,
              'createdAt': Timestamp.now(),
            });
          }
        }
      }

      for (var challenge in dynamicChallenges) {
        final challengeId = challenge['id'] as String?;
        if (challengeId != null) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('challenges')
              .doc(challengeId)
              .set(challenge, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print('Error generating dynamic challenges: $e');
    }
  }

  Future<void> _loadChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);
      final isEndOfMonth = now.day == endOfMonth.day;

      final transactionSnapshot = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      Map<String, double> categorySpending = {};
      Map<String, int> categoryCounts = {};
      List<DateTime> transactionDays = [];

      for (var doc in transactionSnapshot.docs) {
        final data = doc.data();
        final categoryRef = data['category'] as DocumentReference;
        final categorySnapshot = await categoryRef.get();
        final categoryName = categorySnapshot.get('name') as String? ?? 'unknown';
        final categoryType = categorySnapshot.get('type') as String? ?? 'unknown';
        final amount = (data['amount'] is int)
            ? (data['amount'] as int).toDouble()
            : (data['amount'] as double? ?? 0.0);
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final transactionDay =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

        if (categoryType == 'expense') {
          categorySpending[categoryName] =
              (categorySpending[categoryName] ?? 0.0) + amount.abs();
          categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + 1;
        } else if (categoryType == 'income') {
          categorySpending['Savings'] =
              (categorySpending['Savings'] ?? 0.0) + amount;
        }

        if (!transactionDays.any((day) =>
        day.year == transactionDay.year &&
            day.month == transactionDay.month &&
            day.day == transactionDay.day)) {
          transactionDays.add(transactionDay);
        }
      }

      transactionDays.sort((a, b) => b.compareTo(a));
      int streak = 0;
      if (transactionDays.isNotEmpty) {
        DateTime current = transactionDays.first;
        streak = 1;
        for (int i = 1; i < transactionDays.length; i++) {
          final prevDay = transactionDays[i];
          if (current.difference(prevDay).inDays == 1) {
            streak++;
            current = prevDay;
          } else {
            break;
          }
        }
      }

      final challengeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challenges')
          .get();

      List<Map<String, dynamic>> challenges = challengeSnapshot.docs
          .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
          .toList();

      for (var challenge in challenges) {
        final challengeId = challenge['id'] as String?;
        if (challengeId == null) continue;

        bool wasPreviouslyCompleted = challenge['completed'] as bool;

        if (challenge['type'] == 'spending' || challenge['type'] == 'no_spend') {
          final currentSpending = categorySpending[challenge['category']] ?? 0.0;
          challenge['progress'] = currentSpending;
          if (currentSpending <= (challenge['targetAmount'] as num) &&
              !wasPreviouslyCompleted &&
              (isEndOfMonth || transactionSnapshot.docs.isNotEmpty)) {
            challenge['completed'] = true;
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('challenges')
                .doc(challengeId)
                .update({'completed': true});
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('badges')
                .doc(challenge['badge']['id'])
                .set(challenge['badge'] as Map<String, dynamic>);
          }
        } else if (challengeId == 'save_fixed') {
          final savingsAmount = categorySpending['Savings'] ?? 0.0;
          challenge['progress'] = savingsAmount;
          if (savingsAmount >= (challenge['targetAmount'] as num) &&
              !wasPreviouslyCompleted) {
            challenge['completed'] = true;
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('challenges')
                .doc(challengeId)
                .update({'completed': true});
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('badges')
                .doc(challenge['badge']['id'])
                .set(challenge['badge'] as Map<String, dynamic>);
          }
        } else if (challengeId == 'streak_logging') {
          challenge['progress'] = streak;
          if (streak >= (challenge['targetDays'] as num) &&
              !wasPreviouslyCompleted) {
            challenge['completed'] = true;
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('challenges')
                .doc(challengeId)
                .update({'completed': true});
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('badges')
                .doc(challenge['badge']['id'])
                .set(challenge['badge'] as Map<String, dynamic>);
          }
        }
      }

      // Filter to show only incomplete challenges
      challenges = challenges.where((challenge) => !(challenge['completed'] as bool)).toList();

      // Sort challenges by creation date
      challenges.sort((a, b) =>
          (b['createdAt'] as Timestamp).compareTo(a['createdAt'] as Timestamp));

      setState(() {
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() {
        _isLoading = false;
      });
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CompletedChallengesPage()),
              );
            },
            tooltip: 'View Completed Challenges',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _challenges.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No active challenges. Start your journey!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startChallenges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Start Challenges'),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _challenges.length,
        itemBuilder: (context, index) {
          final challenge = _challenges[index];
          return _buildChallengeCard(challenge);
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            // Navigate to FinancialTipsScreen
          } else if (index == 2) {
            // Stay on GamificationPage
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
        },
      ),
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge) {
    double progress = 0.0;
    String progressText = '';

    if (challenge['type'] == 'spending' || challenge['type'] == 'no_spend') {
      progress = ((challenge['progress'] as num) / (challenge['targetAmount'] as num))
          .clamp(0.0, 1.0);
      progressText = 'RM${(challenge['progress'] as num).toStringAsFixed(1)} / RM${(challenge['targetAmount'] as num).toStringAsFixed(1)}';
    } else if (challenge['type'] == 'savings') {
      progress = ((challenge['progress'] as num) / (challenge['targetAmount'] as num))
          .clamp(0.0, 1.0);
      progressText = 'RM${(challenge['progress'] as num).toStringAsFixed(1)} / RM${(challenge['targetAmount'] as num).toStringAsFixed(1)}';
    } else if (challenge['type'] == 'streak') {
      progress = ((challenge['progress'] as num) / (challenge['targetDays'] as num))
          .clamp(0.0, 1.0);
      progressText = '${challenge['progress']} / ${challenge['targetDays']} days';
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
                    challenge['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              challenge['description'] as String,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progressText,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Text(
                  'In Progress',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reward: ${challenge['badge']['name'] as String} Badge',
                  style: const TextStyle(color: Colors.yellow, fontSize: 14),
                ),
                Text(
                  challenge['badge']['icon'] as String,
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
                      width: double.infinity,
                      height: 8,
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