import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GamificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> checkAndUpdateChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Get all active challenges
      final challengesSnapshot = await _firestore
          .collection('challenges')
          .where('isActive', isEqualTo: true)
          .get();

      // Get user's transaction data for challenge checking
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfYear = DateTime(now.year, 1, 1);

      for (var challengeDoc in challengesSnapshot.docs) {
        final challenge = challengeDoc.data();
        final challengeId = challengeDoc.id;

        // Check if user already completed this challenge
        final progressDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('challengeProgress')
            .doc(challengeId)
            .get();

        if (progressDoc.exists && progressDoc.data()?['isCompleted'] == true) {
          continue; // Skip completed challenges
        }

        // Calculate progress based on challenge type
        double progress = 0;

        switch (challenge['type']) {
          case 'transaction_count':
            progress = await _getTransactionCount(userId, challenge['period']);
            break;
          case 'spending_limit':
            progress = await _getSpendingAmount(userId, challenge['period']);
            break;
          case 'category_spending':
            progress = await _getCategorySpending(userId, challenge['categoryName'], challenge['period']);
            break;
          case 'savings_goal':
            progress = await _getSavingsAmount(userId, challenge['period']);
            break;
          case 'consecutive_days':
            progress = await _getConsecutiveDays(userId);
            break;
          case 'budget_adherence':
            progress = await _getBudgetAdherence(userId, challenge['period']);
            break;
          default:
            continue;
        }

        // Update user's progress
        final isCompleted = _checkIfCompleted(progress, challenge);

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('challengeProgress')
            .doc(challengeId)
            .set({
          'progress': progress,
          'isCompleted': isCompleted,
          'lastUpdated': FieldValue.serverTimestamp(),
          if (isCompleted && (!progressDoc.exists || progressDoc.data()?['isCompleted'] != true))
            'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('Updated challenge $challengeId: progress=$progress, completed=$isCompleted');
      }
    } catch (e) {
      print('Error updating challenges: $e');
    }
  }

  bool _checkIfCompleted(double progress, Map<String, dynamic> challenge) {
    final targetValue = challenge['targetValue'] ?? 1;
    final comparisonType = challenge['comparisonType'] ?? 'greater_equal';

    switch (comparisonType) {
      case 'greater_equal':
        return progress >= targetValue;
      case 'less_equal':
        return progress <= targetValue;
      case 'equal':
        return progress == targetValue;
      default:
        return progress >= targetValue;
    }
  }

  Future<double> _getTransactionCount(String userId, String period) async {
    final dateRange = _getDateRange(period);

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!))
        .get();

    return transactionsSnapshot.docs.length.toDouble();
  }

  Future<double> _getSpendingAmount(String userId, String period) async {
    final dateRange = _getDateRange(period);

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!))
        .get();

    double totalSpending = 0;

    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final categoryRef = data['category'] as DocumentReference?;

      if (categoryRef != null) {
        final categoryDoc = await categoryRef.get();
        if (categoryDoc.exists && categoryDoc.data() != null) {
          final categoryData = categoryDoc.data() as Map<String, dynamic>;
          if (categoryData['type'] == 'expense') {
            final amount = data['amount'] is int
                ? (data['amount'] as int).toDouble()
                : (data['amount'] as double? ?? 0.0);
            totalSpending += amount.abs();
          }
        }
      }
    }

    return totalSpending;
  }

  Future<double> _getCategorySpending(String userId, String categoryName, String period) async {
    final dateRange = _getDateRange(period);

    // Query the categories collection to find the document with the specified name and userid
    final categoryQuery = await _firestore
        .collection('categories')
        .where('name', isEqualTo: categoryName)
        .where('userid', isEqualTo: userId)
        .limit(1)
        .get();

    if (categoryQuery.docs.isEmpty) {
      print('Category $categoryName not found for user $userId');
      return 0.0; // Return 0 if category is not found
    }

    final String categoryDocId = categoryQuery.docs.first.id;
    final DocumentReference categoryRef = _firestore.collection('categories').doc(categoryDocId);

    // Query transactions for the category
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('category', isEqualTo: categoryRef)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!))
        .get();

    double totalSpending = 0;

    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final amount = data['amount'] is int
          ? (data['amount'] as int).toDouble()
          : (data['amount'] as double? ?? 0.0);
      totalSpending += amount.abs();
    }

    print('Category $categoryName spending for user $userId: $totalSpending');
    return totalSpending;
  }

  Future<double> _getSavingsAmount(String userId, String period) async {
    final dateRange = _getDateRange(period);

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!))
        .get();

    double totalIncome = 0;
    double totalExpenses = 0;

    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final categoryRef = data['category'] as DocumentReference?;

      if (categoryRef != null) {
        final categoryDoc = await categoryRef.get();
        if (categoryDoc.exists && categoryDoc.data() != null) {
          final categoryData = categoryDoc.data() as Map<String, dynamic>;
          final amount = data['amount'] is int
              ? (data['amount'] as int).toDouble()
              : (data['amount'] as double? ?? 0.0);

          if (categoryData['type'] == 'income') {
            totalIncome += amount;
          } else if (categoryData['type'] == 'expense') {
            totalExpenses += amount.abs();
          }
        }
      }
    }

    return totalIncome - totalExpenses; // Net savings
  }

  Future<double> _getConsecutiveDays(String userId) async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('timestamp', descending: true)
        .get();

    Set<String> daysWithTransactions = {};

    for (var doc in transactionsSnapshot.docs) {
      final timestamp = doc.data()['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dayKey = '${date.year}-${date.month}-${date.day}';
        daysWithTransactions.add(dayKey);
      }
    }

    // Count consecutive days from today backwards
    int consecutiveDays = 0;
    DateTime checkDate = DateTime(now.year, now.month, now.day);

    while (consecutiveDays < 30) {
      final dayKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      if (daysWithTransactions.contains(dayKey)) {
        consecutiveDays++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return consecutiveDays.toDouble();
  }

  Future<double> _getBudgetAdherence(String userId, String period) async {
    // This is a simplified budget adherence check
    // You might want to implement a more sophisticated budget system
    final spending = await _getSpendingAmount(userId, period);

    // For now, let's assume a simple budget of 1000 per month
    final budget = 1000.0;
    final adherencePercentage = ((budget - spending) / budget * 100).clamp(0.0, 100.0);

    return adherencePercentage;
  }

  Map<String, DateTime> _getDateRange(String period) {
    final now = DateTime.now();

    switch (period) {
      case 'daily':
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return {'start': startOfDay, 'end': endOfDay};
      case 'weekly':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return {'start': DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day), 'end': endOfWeek};
      case 'monthly':
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return {'start': startOfMonth, 'end': endOfMonth};
      case 'yearly':
        final startOfYear = DateTime(now.year, 1, 1);
        final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);
        return {'start': startOfYear, 'end': endOfYear};
      default:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return {'start': startOfMonth, 'end': endOfMonth};
    }
  }

  // Method to be called when a transaction is recorded
  Future<void> onTransactionRecorded(String userId) async {
    await checkAndUpdateChallenges();
  }

  // Method to create sample challenges (for testing)
  Future<void> createSampleChallenges() async {
    final sampleChallenges = [
      {
        'title': 'Transaction Master',
        'description': 'Record 10 transactions this month',
        'icon': '📝',
        'type': 'transaction_count',
        'period': 'monthly',
        'targetValue': 10,
        'comparisonType': 'greater_equal',
        'rewardPoints': 100,
        'rewardBadge': {
          'id': 'transaction_master',
          'name': 'Transaction Master',
          'description': 'Recorded 10 transactions in a month',
          'icon': '📝',
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Budget Keeper',
        'description': 'Keep spending under RM500 this month',
        'icon': '💰',
        'type': 'spending_limit',
        'period': 'monthly',
        'targetValue': 500,
        'comparisonType': 'less_equal',
        'rewardPoints': 150,
        'rewardBadge': {
          'id': 'budget_keeper',
          'name': 'Budget Keeper',
          'description': 'Kept spending under budget',
          'icon': '💰',
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Daily Tracker',
        'description': 'Record transactions for 7 consecutive days',
        'icon': '📅',
        'type': 'consecutive_days',
        'period': 'daily',
        'targetValue': 7,
        'comparisonType': 'greater_equal',
        'rewardPoints': 75,
        'rewardBadge': {
          'id': 'daily_tracker',
          'name': 'Daily Tracker',
          'description': 'Tracked expenses for 7 consecutive days',
          'icon': '📅',
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'Savings Star',
        'description': 'Save at least RM200 this month',
        'icon': '⭐',
        'type': 'savings_goal',
        'period': 'monthly',
        'targetValue': 200,
        'comparisonType': 'greater_equal',
        'rewardPoints': 200,
        'rewardBadge': {
          'id': 'savings_star',
          'name': 'Savings Star',
          'description': 'Achieved monthly savings goal',
          'icon': '⭐',
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'title': 'First Steps',
        'description': 'Record your first transaction',
        'icon': '🚀',
        'type': 'transaction_count',
        'period': 'monthly',
        'targetValue': 1,
        'comparisonType': 'greater_equal',
        'rewardPoints': 25,
        'rewardBadge': {
          'id': 'first_steps',
          'name': 'First Steps',
          'description': 'Recorded your first transaction',
          'icon': '🚀',
        },
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (var challenge in sampleChallenges) {
      await _firestore.collection('challenges').add(challenge);
    }
  }
}