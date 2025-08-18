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

        // Get the challenge creation date
        final challengeCreatedAt = challenge['createdAt'] as Timestamp?;
        if (challengeCreatedAt == null) {
          print('Warning: Challenge $challengeId has no creation date');
          continue;
        }

        // Get user's assignment date
        DateTime trackingStartDate = challengeCreatedAt.toDate();

        if (progressDoc.exists) {
          final assignedAt = progressDoc.data()?['assignedAt'] as Timestamp?;
          if (assignedAt != null) {
            trackingStartDate = assignedAt.toDate();
          }
        }

        print('DEBUG: Tracking progress for challenge $challengeId from $trackingStartDate');

        // Calculate progress based on challenge type
        double progress = 0;
        Map<String, dynamic> additionalData = {};

        switch (challenge['type']) {
          case 'transaction_count':
            progress = await _getTransactionCount(userId, challenge['period'], trackingStartDate);
            break;
          case 'spending_limit':
            progress = await _getSpendingAmount(userId, challenge['period'], trackingStartDate);
            if (progress >= 0) {
              additionalData['currentSpending'] = progress;
            }
            break;
          case 'category_spending':
            progress = await _getCategorySpending(userId, challenge['categoryName'], challenge['period'], challenge['comparisonType'], trackingStartDate);
            if (progress >= 0) {
              additionalData['currentSpending'] = progress;
            }
            break;
          case 'savings_goal':
            final savingsData = await _getSavingsProgress(userId, challenge['period'], trackingStartDate);
            progress = savingsData['isPeriodComplete'] ? savingsData['currentSavings'] : -1;
            additionalData['currentSavings'] = savingsData['currentSavings'];
            additionalData['totalIncome'] = savingsData['totalIncome'];
            additionalData['totalExpenses'] = savingsData['totalExpenses'];
            break;
          case 'consecutive_days':
            progress = await _getConsecutiveDays(userId, trackingStartDate);
            break;
          case 'budget_adherence':
            progress = await _getBudgetAdherence(userId, challenge['period'], trackingStartDate);
            break;
          default:
            continue;
        }

        // Update user's progress
        final isCompleted = _checkIfCompleted(progress, challenge);

        // For display purposes, if progress is -1 (period not complete), show as 0
        final displayProgress = progress == -1 ? 0.0 : progress;

        // Prepare the update data
        Map<String, dynamic> updateData = {
          'progress': displayProgress, // Ensure this is always double
          'isCompleted': isCompleted,
          'lastUpdated': FieldValue.serverTimestamp(),
          'trackingStartDate': Timestamp.fromDate(trackingStartDate),
          'periodNotComplete': progress == -1, // Add flag to indicate waiting for period
          ...additionalData, // Include currentSpending/currentSavings as double
        };

        if (isCompleted && (!progressDoc.exists || progressDoc.data()?['isCompleted'] != true)) {
          updateData['completedAt'] = FieldValue.serverTimestamp();
        }

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('challengeProgress')
            .doc(challengeId)
            .set(updateData, SetOptions(merge: true));

        print('Updated challenge $challengeId: progress=$displayProgress, completed=$isCompleted, periodNotComplete=${progress == -1}');
      }
    } catch (e) {
      print('Error updating challenges: $e');
    }
  }

  // Counts how many transactions a user has made within a specific time period.
  Future<double> _getTransactionCount(String userId, String period, DateTime trackingStartDate) async {
    final dateRange = _getDateRangeFromStartDate(period, trackingStartDate);

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(dateRange['end']!))
        .get();

    print('DEBUG: Transaction count for period $period from ${dateRange['start']} to ${dateRange['end']}: ${transactionsSnapshot.docs.length}');
    return transactionsSnapshot.docs.length.toDouble();
  }

  bool _shouldEvaluateChallenge(String challengeType, String period, DateTime trackingStartDate, String? comparisonType) {
    final now = DateTime.now();
    final daysSinceStart = now.difference(trackingStartDate).inDays;

    // For spending and savings challenges, check comparison type
    if (challengeType == 'spending_limit' ||
        challengeType == 'savings_goal') {
      // These always require period completion
      switch (period) {
        case 'daily':
          final endOfDay = DateTime(
              trackingStartDate.year,
              trackingStartDate.month,
              trackingStartDate.day,
              23, 59, 59
          );
          return now.isAfter(endOfDay);

        case 'weekly':
          final endOfWeek = trackingStartDate.add(const Duration(days: 7));
          return now.isAfter(endOfWeek);

        case 'monthly':
          final nextMonth = DateTime(
            trackingStartDate.year,
            trackingStartDate.month + 1,
            1,
          );
          final endOfMonth = nextMonth.subtract(const Duration(seconds: 1));
          return now.isAfter(endOfMonth);

        default:
          return daysSinceStart >= 1;
      }
    }

    // For category spending, check comparison type
    if (challengeType == 'category_spending') {
      // If it's "at least" (greater_equal), evaluate immediately
      if (comparisonType == 'greater_equal') {
        return true; // Always evaluate for "at least" challenges
      }

      // If it's "at most" (less_equal), require period completion
      if (comparisonType == 'less_equal') {
        switch (period) {
          case 'daily':
            final endOfDay = DateTime(
                trackingStartDate.year,
                trackingStartDate.month,
                trackingStartDate.day,
                23, 59, 59
            );
            return now.isAfter(endOfDay);

          case 'weekly':
            final endOfWeek = trackingStartDate.add(const Duration(days: 7));
            return now.isAfter(endOfWeek);

          case 'monthly':
            final nextMonth = DateTime(
              trackingStartDate.year,
              trackingStartDate.month + 1,
              1,
            );
            final endOfMonth = nextMonth.subtract(const Duration(seconds: 1));
            return now.isAfter(endOfMonth);

          default:
            return daysSinceStart >= 1;
        }
      }
    }

    // For other challenge types, evaluate immediately
    return true;
  }

  //Calculates total spending (expenses only) within a period.
  Future<double> _getSpendingAmount(String userId, String period, DateTime trackingStartDate) async {
    final dateRange = _getDateRangeFromStartDate(period, trackingStartDate);
    final now = DateTime.now();

    // For spending limit challenges, check if period is complete
    if (!_shouldEvaluateChallenge('spending_limit', period, trackingStartDate, null)) {
      print('DEBUG: Spending limit period not complete. Period: $period, Start: $trackingStartDate');
      return -1;
    }

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
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

    print('DEBUG: Total spending for completed period $period: $totalSpending');
    return totalSpending;
  }

  Future<double> _getCategorySpending(String userId, String categoryName, String period, String? comparisonType, DateTime trackingStartDate) async {
    final dateRange = _getDateRangeFromStartDate(period, trackingStartDate);
    final now = DateTime.now();

    // Check if we should evaluate this challenge based on comparison type
    if (!_shouldEvaluateChallenge('category_spending', period, trackingStartDate, comparisonType)) {
      print('DEBUG: Category spending period not complete. Period: $period, Category: $categoryName, Comparison: $comparisonType');
      return -1; // Indicate period not complete (only for "at most" challenges)
    }

    // For "at least" challenges, use current time instead of period end
    // For "at most" challenges that passed the evaluation check, use period end
    final endTime = (comparisonType == 'greater_equal') ? now : dateRange['end']!;

    print('DEBUG: Searching for category "$categoryName" spending from ${dateRange['start']} to $endTime (comparison: $comparisonType)');

    // Try multiple approaches to find the category
    QuerySnapshot categoryQuery;

    // First try: search by name and userId
    categoryQuery = await _firestore
        .collection('categories')
        .where('name', isEqualTo: categoryName)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    // If no results, try with userid (lowercase)
    if (categoryQuery.docs.isEmpty) {
      categoryQuery = await _firestore
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .where('userid', isEqualTo: userId)
          .limit(1)
          .get();
    }

    // If still no results, try case-insensitive search
    if (categoryQuery.docs.isEmpty) {
      final allCategoriesSnapshot = await _firestore
          .collection('categories')
          .get();

      final filteredDocs = allCategoriesSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final docName = (data['name'] as String?)?.toLowerCase();
        final docUserId = data['userId'] ?? data['userid'];
        return docName == categoryName.toLowerCase() &&
            (docUserId == null || docUserId == '' || docUserId == userId);
      }).toList();

      if (filteredDocs.isEmpty) {
        print('DEBUG: Category "$categoryName" not found for user $userId');
        return 0.0;
      }

      final categoryDoc = filteredDocs.first;
      final DocumentReference categoryRef = _firestore.collection('categories').doc(categoryDoc.id);

      // Query transactions for the category
      final transactionsSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: categoryRef)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
          .get();

      double totalSpending = 0;
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final amount = data['amount'] is int
            ? (data['amount'] as int).toDouble()
            : (data['amount'] as double? ?? 0.0);
        totalSpending += amount.abs();
      }

      print('DEBUG: Category $categoryName spending: $totalSpending (comparison: $comparisonType)');
      return totalSpending;
    }

    final categoryDoc = categoryQuery.docs.first;
    final DocumentReference categoryRef = _firestore.collection('categories').doc(categoryDoc.id);

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: categoryRef)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endTime))
        .get();

    double totalSpending = 0;
    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final amount = data['amount'] is int
          ? (data['amount'] as int).toDouble()
          : (data['amount'] as double? ?? 0.0);
      totalSpending += amount.abs();
    }

    print('DEBUG: Category $categoryName spending: $totalSpending (comparison: $comparisonType)');
    return totalSpending;
  }

  // Replace the _getSavingsAmount method with this updated version
  Future<double> _getSavingsAmount(String userId, String period, DateTime trackingStartDate) async {
    final dateRange = _getDateRangeFromStartDate(period, trackingStartDate);

    // Check if period is complete for savings goals
    if (!_shouldEvaluateChallenge('savings_goal', period, trackingStartDate, null)) {
      print('DEBUG: Savings period not complete. Period: $period');
      return -1; // Indicate period not complete
    }

    // Only calculate actual savings if the period is complete
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
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

    final savings = totalIncome - totalExpenses;
    print('DEBUG: Savings (period complete): Income=$totalIncome, Expenses=$totalExpenses, Net=$savings');
    return savings;
  }

  bool _checkIfCompleted(double progress, Map<String, dynamic> challenge) {
    final targetValue = challenge['targetValue'] ?? 1;
    final comparisonType = challenge['comparisonType'] ?? 'greater_equal';
    final challengeType = challenge['type'] ?? '';

    // If progress is -1, it means the period is not complete
    // Don't mark as complete regardless of comparison type
    if (progress == -1) {
      return false;
    }

    // For spending and savings challenges, additional validation
    if (challengeType == 'spending_limit' ||
        challengeType == 'savings_goal') {
      // If the progress indicates period not complete, don't mark as complete
      if (progress < 0) {
        return false;
      }
    }

    // For category spending with "at least" comparison, complete when target is reached
    if (challengeType == 'category_spending' && comparisonType == 'greater_equal') {
      return progress >= targetValue;
    }

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

  //Calculates net savings (income - expenses) and period completion status.
  Future<Map<String, dynamic>> _getSavingsProgress(String userId, String period, DateTime trackingStartDate) async {
    final dateRange = _getDateRangeFromStartDate(period, trackingStartDate);
    final now = DateTime.now();

    // Calculate how much of the period has passed
    final totalPeriodDuration = dateRange['end']!.difference(dateRange['start']!).inSeconds;
    final elapsedDuration = now.difference(dateRange['start']!).inSeconds;
    final periodProgress = (elapsedDuration / totalPeriodDuration).clamp(0.0, 1.0);

    // Get current transactions
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange['start']!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(now)) // Use current time instead of period end
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

    final currentSavings = totalIncome - totalExpenses;

    return {
      'currentSavings': currentSavings,
      'periodProgress': periodProgress,
      'isPeriodComplete': periodProgress >= 1.0,
      'totalIncome': totalIncome,
      'totalExpenses': totalExpenses,
      'daysRemaining': dateRange['end']!.difference(now).inDays,
    };
  }

  // Tracks streak of consecutive days with transactions.
  Future<double> _getConsecutiveDays(String userId, DateTime trackingStartDate) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Get all transactions from tracking start date
    final startSearchDate = trackingStartDate.isAfter(today.subtract(const Duration(days: 365)))
        ? trackingStartDate
        : today.subtract(const Duration(days: 365));

    print('DEBUG: Checking consecutive days from $startSearchDate to $now');

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startSearchDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('timestamp', descending: true)
        .get();

    if (transactionsSnapshot.docs.isEmpty) {
      print('DEBUG: No transactions found for consecutive days');
      return 0;
    }

    // Create a set of dates with transactions (normalized to start of day)
    Set<DateTime> datesWithTransactions = {};

    for (var doc in transactionsSnapshot.docs) {
      final timestamp = doc.data()['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        // Only count days from tracking start date forward
        if (date.isAfter(trackingStartDate.subtract(const Duration(days: 1)))) {
          final normalizedDate = DateTime(date.year, date.month, date.day);
          datesWithTransactions.add(normalizedDate);
        }
      }
    }

    if (datesWithTransactions.isEmpty) {
      print('DEBUG: No valid transaction dates found');
      return 0;
    }

    // Sort dates in descending order (most recent first)
    final sortedDates = datesWithTransactions.toList()
      ..sort((a, b) => b.compareTo(a));

    print('DEBUG: Dates with transactions: ${sortedDates.map((d) => '${d.year}-${d.month}-${d.day}').toList()}');

    // Count consecutive days starting from today or the most recent transaction
    int consecutiveDays = 0;
    DateTime checkDate = today;

    // If there's no transaction today, check if there was one yesterday
    if (!datesWithTransactions.contains(today)) {
      final yesterday = today.subtract(const Duration(days: 1));
      if (datesWithTransactions.contains(yesterday)) {
        // Start counting from yesterday if there's a transaction there
        checkDate = yesterday;
      } else {
        // No transaction today or yesterday - streak is broken
        print('DEBUG: No transaction today or yesterday - streak broken');
        return 0;
      }
    }

    // Count consecutive days going backwards
    while (datesWithTransactions.contains(checkDate)) {
      consecutiveDays++;
      checkDate = checkDate.subtract(const Duration(days: 1));

      // Don't count days before tracking started
      if (checkDate.isBefore(trackingStartDate.subtract(const Duration(days: 1)))) {
        break;
      }

      // Limit to reasonable maximum (e.g., 365 days)
      if (consecutiveDays >= 365) {
        break;
      }
    }

    print('DEBUG: Consecutive days count: $consecutiveDays');
    return consecutiveDays.toDouble();
  }

  Future<double> _getBudgetAdherence(String userId, String period, DateTime trackingStartDate) async {
    // This is a simplified budget adherence check
    final spending = await _getSpendingAmount(userId, period, trackingStartDate);

    // assume a simple budget of 1000 per month
    final budget = 1000.0;
    final adherencePercentage = ((budget - spending) / budget * 100).clamp(0.0, 100.0);

    print('DEBUG: Budget adherence from tracking start: Spending=$spending, Budget=$budget, Adherence=$adherencePercentage%');
    return adherencePercentage;
  }

  // calculates date range considering the tracking start date
  Map<String, DateTime> _getDateRangeFromStartDate(String period, DateTime trackingStartDate) {
    final now = DateTime.now();
    final standardRange = _getDateRange(period);

    // Use the later of the tracking start date or the standard period start
    final effectiveStartDate = trackingStartDate.isAfter(standardRange['start']!)
        ? trackingStartDate
        : standardRange['start']!;

    return {
      'start': effectiveStartDate,
      'end': standardRange['end']!,
    };
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

  // Method to create sample challenges
  Future<void> createSampleChallenges() async {
    final sampleChallenges = [
      {
        'title': 'Transaction Master',
        'description': 'Record 10 transactions this month',
        'icon': '📊',
        'type': 'transaction_count',
        'period': 'monthly',
        'targetValue': 10,
        'comparisonType': 'greater_equal',
        'rewardPoints': 100,
        'rewardBadge': {
          'id': 'transaction_master',
          'name': 'Transaction Master',
          'description': 'Recorded 10 transactions in a month',
          'icon': '📊',
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