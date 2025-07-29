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
    _listenToWeeklySpending();
    _listenToConsistentLogging();
    _listenToCategoryDiversification();
    _listenToBigSpender();
    _listenToIncomeBooster();
    _listenToFrugalShopper();
    _listenToDiverseIncome();
    _listenToSideHustle();
    _listenToBigIncome();
    _listenToCollectiveIncome();
    _listenToIncomeCategoryCompetition();
    _listenToBigIncomeLeader();
  }

  Future<void> _initializeChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for challenge initialization');
      return;
    }

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
      {
        'id': 'weekly_spending_limit',
        'title': 'Weekly Spending Limit',
        'description': 'Keep your weekly expenses below RM100 or 50% of your average weekly spending.',
        'type': 'spending_limit',
        'targetAmount': 1,
        'progress': 0.0,
        'points': 20,
        'badge': {
          'id': 'badge_weekly_saver',
          'name': 'Weekly Saver',
          'description': 'Kept weekly expenses below the limit',
          'icon': '🏦',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
        'weekStart': Timestamp.fromDate(now.subtract(Duration(days: now.weekday - 1))),
      },
      {
        'id': 'consistent_logging',
        'title': 'Consistent Transaction Logging',
        'description': 'Log at least one transaction for 3 consecutive days.',
        'type': 'consistent_logging',
        'targetAmount': 3,
        'progress': 0.0,
        'points': 10,
        'badge': {
          'id': 'badge_consistent_logger',
          'name': 'Consistent Logger',
          'description': 'Logged transactions for 3 consecutive days',
          'icon': '📝',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
        'consecutiveDays': 0,
        'lastTransactionDate': null,
      },
      {
        'id': 'category_diversification',
        'title': 'Category Diversification',
        'description': 'Record expenses in at least 3 different categories this month.',
        'type': 'category_diversification',
        'targetAmount': 3,
        'progress': 0.0,
        'points': 15,
        'badge': {
          'id': 'badge_diverse_spender',
          'name': 'Diverse Spender',
          'description': 'Spent in 3 different categories',
          'icon': '🌈',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
        'month': DateFormat('yyyy-MM').format(now),
      },
      {
        'id': 'big_spender',
        'title': 'Big Spender',
        'description': 'Record a single expense transaction of RM500 or more.',
        'type': 'big_spender',
        'targetAmount': 500.0,
        'progress': 0.0,
        'points': 15,
        'badge': {
          'id': 'badge_big_spender',
          'name': 'Big Spender',
          'description': 'Recorded a single expense of RM500 or more',
          'icon': '💸',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'id': 'income_booster',
        'title': 'Income Booster',
        'description': 'Record a total of RM1000 in income transactions.',
        'type': 'income_booster',
        'targetAmount': 1000.0,
        'progress': 0.0,
        'points': 20,
        'badge': {
          'id': 'badge_income_booster',
          'name': 'Income Booster',
          'description': 'Recorded RM1000 in income',
          'icon': '💰',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'id': 'frugal_shopper',
        'title': 'Frugal Shopper',
        'description': 'Record 5 expense transactions each under RM50.',
        'type': 'frugal_shopper',
        'targetAmount': 5,
        'progress': 0.0,
        'points': 10,
        'badge': {
          'id': 'badge_frugal_shopper',
          'name': 'Frugal Shopper',
          'description': 'Recorded 5 expenses under RM50 each',
          'icon': '🛒',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'id': 'diverse_income',
        'title': 'Diverse Income Sources',
        'description': 'Record income transactions in at least 3 different income categories.',
        'type': 'diverse_income',
        'targetAmount': 3,
        'progress': 0.0,
        'points': 15,
        'badge': {
          'id': 'badge_diverse_income',
          'name': 'Income Diversifier',
          'description': 'Recorded income in 3 different categories',
          'icon': '🌟',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'id': 'side_hustle',
        'title': 'Side Hustle Star',
        'description': 'Record 5 income transactions in non-Salary categories.',
        'type': 'side_hustle',
        'targetAmount': 5,
        'progress': 0.0,
        'points': 10,
        'badge': {
          'id': 'badge_side_hustle',
          'name': 'Side Hustle Star',
          'description': 'Recorded 5 non-Salary income transactions',
          'icon': '💼',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'id': 'big_income',
        'title': 'Big Income Win',
        'description': 'Record a single income transaction of RM1000 or more.',
        'type': 'big_income',
        'targetAmount': 1000.0,
        'progress': 0.0,
        'points': 20,
        'badge': {
          'id': 'badge_big_income',
          'name': 'Big Income Winner',
          'description': 'Recorded a single income of RM1000 or more',
          'icon': '🏆',
        },
        'completed': false,
        'createdAt': Timestamp.fromDate(now),
      },
    ];

    for (var challenge in defaultChallenges) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('challenges')
            .doc(challenge['id'] as String?)
            .set(challenge, SetOptions(merge: true));
        print('Initialized challenge: ${challenge['id']} for user: $userId');
      } catch (e) {
        print('Error saving challenge ${challenge['id']}: $e');
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
    if (userId == null) {
      print('No user logged in for No-Spend Day listener');
      return;
    }

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
        final lastChecked = (challenge['lastChecked'] as Timestamp?)?.toDate() ?? DateTime.now();
        final now = DateTime.now();
        final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
        final endOfYesterday = startOfYesterday.add(Duration(days: 1));

        if (now.day != lastChecked.day) {
          final yesterdayExpenses = transactions.where((tx) {
            final txDate = (tx.data()['timestamp'] as Timestamp).toDate();
            return txDate.isAfter(startOfYesterday) &&
                txDate.isBefore(endOfYesterday);
          }).toList();

          bool hasExpenses = false;
          for (var tx in yesterdayExpenses) {
            final categoryRef = tx.data()['category'] as DocumentReference;
            final categorySnap = await categoryRef.get();
            if (categorySnap.exists && categorySnap['type'] == 'expense') {
              hasExpenses = true;
              break;
            }
          }

          final progress = hasExpenses ? 0.0 : 1.0;
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Challenge completed: No-Spend Day! +${challenge['points']} points')),
              );
              print('No-Spend Day completed for user: $userId');
            }
          } else {
            print('No-Spend Day not completed for $startOfYesterday, expenses: $hasExpenses');
          }
        } else {
          print('No-Spend Day already checked today for user: $userId');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToWeeklySpending() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Weekly Spending listener');
      return;
    }

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
          .doc('weekly_spending_limit')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        final weekStart = (challenge['weekStart'] as Timestamp).toDate();
        final weekEnd = weekStart.add(Duration(days: 7));
        final now = DateTime.now();

        if (now.isAfter(weekEnd)) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('challenges')
              .doc('weekly_spending_limit')
              .update({
            'weekStart': Timestamp.fromDate(now.subtract(Duration(days: now.weekday - 1))),
            'progress': 0.0,
            'completed': false,
          });
          print('Weekly Spending Limit reset for new week: ${DateFormat('yyyy-MM-dd').format(now)}');
          return;
        }

        double avgWeeklySpending = 100.0;
        final allTransactions = await _firestore
            .collection('transactions')
            .where('userid', isEqualTo: userId)
            .get();
        if (allTransactions.docs.isNotEmpty) {
          final expenses = allTransactions.docs.where((tx) {
            final categoryRef = tx.data()['category'] as DocumentReference;
            return categoryRef.path.contains('expense');
          }).toList();
          if (expenses.isNotEmpty) {
            double total = 0.0;
            for (var tx in expenses) {
              total += (tx.data()['amount'] as num).toDouble().abs();
            }
            avgWeeklySpending = total / (expenses.length / 7);
            avgWeeklySpending = avgWeeklySpending * 0.5;
            avgWeeklySpending = avgWeeklySpending > 100.0 ? avgWeeklySpending : 100.0;
          }
        }

        double weeklyExpenses = 0.0;
        for (var tx in transactions) {
          final txDate = (tx.data()['timestamp'] as Timestamp).toDate();
          if (txDate.isAfter(weekStart) && txDate.isBefore(weekEnd)) {
            final categoryRef = tx.data()['category'] as DocumentReference;
            final categorySnap = await categoryRef.get();
            if (categorySnap.exists && categorySnap['type'] == 'expense') {
              weeklyExpenses += (tx.data()['amount'] as num).toDouble().abs();
            }
          }
        }

        final progress = weeklyExpenses <= avgWeeklySpending ? 1.0 : weeklyExpenses / avgWeeklySpending;
        final completed = weeklyExpenses <= avgWeeklySpending;
        await _updateChallengeProgress(
          userId,
          'weekly_spending_limit',
          progress.clamp(0.0, 1.0),
          completed,
          challenge,
        );

        if (completed) {
          print('Weekly Spending Limit completed for user: $userId, expenses: $weeklyExpenses, threshold: $avgWeeklySpending');
        } else {
          print('Weekly Spending Limit progress: ${(progress * 100).toStringAsFixed(1)}%, expenses: $weeklyExpenses, threshold: $avgWeeklySpending');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToConsistentLogging() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Consistent Logging listener');
      return;
    }

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
          .doc('consistent_logging')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        final now = DateTime.now();
        final lastTransactionDate = (challenge['lastTransactionDate'] as Timestamp?)?.toDate();
        int consecutiveDays = (challenge['consecutiveDays'] as int?) ?? 0;

        final transactionDays = transactions.map((tx) {
          final txDate = (tx.data()['timestamp'] as Timestamp).toDate();
          return DateTime(txDate.year, txDate.month, txDate.day);
        }).toSet().toList()
          ..sort((a, b) => b.compareTo(a));

        if (transactionDays.isNotEmpty) {
          final latestDay = transactionDays.first;
          if (lastTransactionDate == null || lastTransactionDate.isBefore(latestDay.subtract(Duration(days: 1)))) {
            consecutiveDays = 1;
          } else if (lastTransactionDate.day == now.day - 1) {
            consecutiveDays = (consecutiveDays + 1).clamp(0, 3);
          }
        } else if (lastTransactionDate != null && now.day != lastTransactionDate.day) {
          consecutiveDays = 0;
        }

        final progress = consecutiveDays / 3.0;
        final completed = consecutiveDays >= 3;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('challenges')
            .doc('consistent_logging')
            .update({
          'progress': progress,
          'completed': completed,
          'consecutiveDays': consecutiveDays,
          'lastTransactionDate': transactionDays.isNotEmpty ? Timestamp.fromDate(transactionDays.first) : null,
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Challenge completed: Consistent Transaction Logging! +${challenge['points']} points')),
            );
            print('Consistent Logging completed for user: $userId, consecutive days: $consecutiveDays');
          }
        } else {
          print('Consistent Logging progress: ${(progress * 100).toStringAsFixed(1)}%, consecutive days: $consecutiveDays');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToCategoryDiversification() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Category Diversification listener');
      return;
    }

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
          .doc('category_diversification')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        final now = DateTime.now();
        final month = DateFormat('yyyy-MM').format(now);
        if (challenge['month'] != month) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('challenges')
              .doc('category_diversification')
              .update({
            'progress': 0.0,
            'completed': false,
            'month': month,
          });
          print('Category Diversification reset for new month: $month');
          return;
        }

        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        final uniqueCategories = <String>{};
        for (var tx in transactions) {
          final txDate = (tx.data()['timestamp'] as Timestamp).toDate();
          if (txDate.isAfter(startOfMonth) && txDate.isBefore(endOfMonth)) {
            final categoryRef = tx.data()['category'] as DocumentReference;
            final categorySnap = await categoryRef.get();
            if (categorySnap.exists && categorySnap['type'] == 'expense') {
              uniqueCategories.add(categorySnap['name'] as String);
            }
          }
        }

        final progress = uniqueCategories.length / 3.0;
        final completed = uniqueCategories.length >= 3;
        await _updateChallengeProgress(
          userId,
          'category_diversification',
          progress.clamp(0.0, 1.0),
          completed,
          challenge,
        );

        if (completed) {
          print('Category Diversification completed for user: $userId, categories: ${uniqueCategories.toList()}');
        } else {
          print('Category Diversification progress: ${(progress * 100).toStringAsFixed(1)}%, categories: ${uniqueCategories.toList()}');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToBigSpender() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Big Spender listener');
      return;
    }

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
          .doc('big_spender')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        double maxExpense = 0.0;
        for (var tx in transactions) {
          final categoryRef = tx.data()['category'] as DocumentReference;
          final categorySnap = await categoryRef.get();
          if (categorySnap.exists && categorySnap['type'] == 'expense') {
            final amount = (tx.data()['amount'] as num).toDouble().abs();
            maxExpense = amount > maxExpense ? amount : maxExpense;
          }
        }

        final progress = (maxExpense / 500.0).clamp(0.0, 1.0);
        final completed = maxExpense >= 500.0;
        await _updateChallengeProgress(
          userId,
          'big_spender',
          progress,
          completed,
          challenge,
        );

        if (completed) {
          print('Big Spender completed for user: $userId, max expense: $maxExpense');
        } else {
          print('Big Spender progress: ${(progress * 100).toStringAsFixed(1)}%, max expense: $maxExpense');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToIncomeBooster() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Income Booster listener');
      return;
    }

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
          .doc('income_booster')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        double totalIncome = 0.0;
        for (var tx in transactions) {
          final categoryRef = tx.data()['category'] as DocumentReference;
          final categorySnap = await categoryRef.get();
          if (categorySnap.exists && categorySnap['type'] == 'income') {
            totalIncome += (tx.data()['amount'] as num).toDouble();
          }
        }

        final progress = (totalIncome / 1000.0).clamp(0.0, 1.0);
        final completed = totalIncome >= 1000.0;
        await _updateChallengeProgress(
          userId,
          'income_booster',
          progress,
          completed,
          challenge,
        );

        if (completed) {
          print('Income Booster completed for user: $userId, total income: $totalIncome');
        } else {
          print('Income Booster progress: ${(progress * 100).toStringAsFixed(1)}%, total income: $totalIncome');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToFrugalShopper() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Frugal Shopper listener');
      return;
    }

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
          .doc('frugal_shopper')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        int smallExpenses = 0;
        for (var tx in transactions) {
          final categoryRef = tx.data()['category'] as DocumentReference;
          final categorySnap = await categoryRef.get();
          if (categorySnap.exists && categorySnap['type'] == 'expense') {
            final amount = (tx.data()['amount'] as num).toDouble().abs();
            if (amount <= 50.0) {
              smallExpenses++;
            }
          }
        }

        final progress = (smallExpenses / 5.0).clamp(0.0, 1.0);
        final completed = smallExpenses >= 5;
        await _updateChallengeProgress(
          userId,
          'frugal_shopper',
          progress,
          completed,
          challenge,
        );

        if (completed) {
          print('Frugal Shopper completed for user: $userId, small expenses: $smallExpenses');
        } else {
          print('Frugal Shopper progress: ${(progress * 100).toStringAsFixed(1)}%, small expenses: $smallExpenses');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToDiverseIncome() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Diverse Income listener');
      return;
    }

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
          .doc('diverse_income')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        final uniqueIncomeCategories = <String>{};
        for (var tx in transactions) {
          final categoryRef = tx.data()['category'] as DocumentReference;
          final categorySnap = await categoryRef.get();
          if (categorySnap.exists && categorySnap['type'] == 'income') {
            uniqueIncomeCategories.add(categorySnap['name'] as String);
          }
        }

        final progress = (uniqueIncomeCategories.length / 3.0).clamp(0.0, 1.0);
        final completed = uniqueIncomeCategories.length >= 3;
        await _updateChallengeProgress(
          userId,
          'diverse_income',
          progress,
          completed,
          challenge,
        );

        if (completed) {
          print('Diverse Income completed for user: $userId, categories: ${uniqueIncomeCategories.toList()}');
        } else {
          print('Diverse Income progress: ${(progress * 100).toStringAsFixed(1)}%, categories: ${uniqueIncomeCategories.toList()}');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToSideHustle() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Side Hustle listener');
      return;
    }

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
          .doc('side_hustle')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        int nonSalaryIncome = 0;
        for (var tx in transactions) {
          final categoryRef = tx.data()['category'] as DocumentReference;
          final categorySnap = await categoryRef.get();
          if (categorySnap.exists &&
              categorySnap['type'] == 'income' &&
              categorySnap['name'] != 'Salary') {
            nonSalaryIncome++;
          }
        }

        final progress = (nonSalaryIncome / 5.0).clamp(0.0, 1.0);
        final completed = nonSalaryIncome >= 5;
        await _updateChallengeProgress(
          userId,
          'side_hustle',
          progress,
          completed,
          challenge,
        );

        if (completed) {
          print('Side Hustle completed for user: $userId, non-Salary transactions: $nonSalaryIncome');
        } else {
          print('Side Hustle progress: ${(progress * 100).toStringAsFixed(1)}%, non-Salary transactions: $nonSalaryIncome');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToBigIncome() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Big Income listener');
      return;
    }

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
          .doc('big_income')
          .get();

      if (challengeDoc.exists) {
        final challenge = challengeDoc.data()!;
        double maxIncome = 0.0;
        for (var tx in transactions) {
          final categoryRef = tx.data()['category'] as DocumentReference;
          final categorySnap = await categoryRef.get();
          if (categorySnap.exists && categorySnap['type'] == 'income') {
            final amount = (tx.data()['amount'] as num).toDouble();
            maxIncome = amount > maxIncome ? amount : maxIncome;
          }
        }

        final progress = (maxIncome / 1000.0).clamp(0.0, 1.0);
        final completed = maxIncome >= 1000.0;
        await _updateChallengeProgress(
          userId,
          'big_income',
          progress,
          completed,
          challenge,
        );

        if (completed) {
          print('Big Income completed for user: $userId, max income: $maxIncome');
        } else {
          print('Big Income progress: ${(progress * 100).toStringAsFixed(1)}%, max income: $maxIncome');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToCollectiveIncome() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Collective Income listener');
      return;
    }

    _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc('collective_income')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final challenge = snapshot.data()!;
      final communityChallengeDoc = await _firestore
          .collection('community_challenges')
          .doc('collective_income')
          .get();

      if (communityChallengeDoc.exists) {
        final participants = (communityChallengeDoc.data()!['participants'] as List<dynamic>?) ?? [];
        double totalIncome = 0.0;
        for (var participantId in participants) {
          final transactions = await _firestore
              .collection('transactions')
              .where('userid', isEqualTo: participantId)
              .where('category', whereIn: [
            _firestore.doc('categories/Salary'),
            _firestore.doc('categories/Freelance'),
            _firestore.doc('categories/Investments'),
          ])
              .get();
          for (var tx in transactions.docs) {
            final categoryRef = tx.data()['category'] as DocumentReference;
            final categorySnap = await categoryRef.get();
            if (categorySnap.exists && categorySnap['type'] == 'income') {
              totalIncome += (tx.data()['amount'] as num).toDouble();
            }
          }
        }

        await _firestore
            .collection('community_challenges')
            .doc('collective_income')
            .update({'totalIncome': totalIncome});

        final progress = (totalIncome / 50000.0).clamp(0.0, 1.0);
        final completed = totalIncome >= 50000.0;
        await _updateChallengeProgress(
          userId,
          'collective_income',
          progress,
          completed,
          challenge,
        );

        if (completed) {
          print('Collective Income completed for user: $userId, total income: $totalIncome');
        } else {
          print('Collective Income progress: ${(progress * 100).toStringAsFixed(1)}%, total income: $totalIncome');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToIncomeCategoryCompetition() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Income Category Competition listener');
      return;
    }

    _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc('income_category_competition')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final challenge = snapshot.data()!;
      final communityChallengeDoc = await _firestore
          .collection('community_challenges')
          .doc('income_category_competition')
          .get();

      if (communityChallengeDoc.exists) {
        final participants = (communityChallengeDoc.data()!['participants'] as List<dynamic>?) ?? [];
        final userCategoryCounts = <String, Map<String, int>>{};
        int maxCount = 0;

        for (var participantId in participants) {
          final transactions = await _firestore
              .collection('transactions')
              .where('userid', isEqualTo: participantId)
              .where('category', whereIn: [
            _firestore.doc('categories/Salary'),
            _firestore.doc('categories/Freelance'),
            _firestore.doc('categories/Investments'),
          ])
              .get();

          final categoryCounts = <String, int>{};
          for (var tx in transactions.docs) {
            final categoryRef = tx.data()['category'] as DocumentReference;
            final categorySnap = await categoryRef.get();
            if (categorySnap.exists && categorySnap['type'] == 'income') {
              final categoryName = categorySnap['name'] as String;
              categoryCounts[categoryName] = (categoryCounts[categoryName] ?? 0) + 1;
            }
          }

          if (categoryCounts.isNotEmpty) {
            final topCategory = categoryCounts.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
            userCategoryCounts[participantId] = {topCategory: categoryCounts[topCategory]!};
            maxCount = maxCount > categoryCounts[topCategory]! ? maxCount : categoryCounts[topCategory]!;
          }
        }

        double userProgress = 0.0;
        bool completed = false;
        if (userCategoryCounts.containsKey(userId) && maxCount > 0) {
          final userCount = userCategoryCounts[userId]!.values.first;
          userProgress = (userCount / maxCount).clamp(0.0, 1.0);
          final sortedUsers = userCategoryCounts.entries.toList()
            ..sort((a, b) => b.value.values.first.compareTo(a.value.values.first));
          final top10Percent = sortedUsers
              .take((sortedUsers.length * 0.1).ceil())
              .toList();
          completed = top10Percent.any((entry) => entry.key == userId);
        }

        await _updateChallengeProgress(
          userId,
          'income_category_competition',
          userProgress,
          completed,
          challenge,
        );

        if (completed) {
          print('Income Category Competition completed for user: $userId, top category: ${userCategoryCounts[userId]!.keys.first}, count: ${userCategoryCounts[userId]!.values.first}');
        } else {
          print('Income Category Competition progress: ${(userProgress * 100).toStringAsFixed(1)}%, max count: $maxCount');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _listenToBigIncomeLeader() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for Big Income Leader listener');
      return;
    }

    _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc('big_income_leader')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) return;
      final challenge = snapshot.data()!;
      final communityChallengeDoc = await _firestore
          .collection('community_challenges')
          .doc('big_income_leader')
          .get();

      if (communityChallengeDoc.exists) {
        final participants = (communityChallengeDoc.data()!['participants'] as List<dynamic>?) ?? [];
        final userMaxIncomes = <String, double>{};
        double maxIncome = 0.0;

        for (var participantId in participants) {
          final transactions = await _firestore
              .collection('transactions')
              .where('userid', isEqualTo: participantId)
              .where('category', whereIn: [
            _firestore.doc('categories/Salary'),
            _firestore.doc('categories/Freelance'),
            _firestore.doc('categories/Investments'),
          ])
              .get();

          double userMaxIncome = 0.0;
          for (var tx in transactions.docs) {
            final categoryRef = tx.data()['category'] as DocumentReference;
            final categorySnap = await categoryRef.get();
            if (categorySnap.exists && categorySnap['type'] == 'income') {
              final amount = (tx.data()['amount'] as num).toDouble();
              userMaxIncome = amount > userMaxIncome ? amount : userMaxIncome;
            }
          }
          userMaxIncomes[participantId] = userMaxIncome;
          maxIncome = userMaxIncome > maxIncome ? userMaxIncome : maxIncome;
        }

        double userProgress = 0.0;
        bool completed = false;
        if (userMaxIncomes.containsKey(userId) && maxIncome > 0) {
          userProgress = (userMaxIncomes[userId]! / maxIncome).clamp(0.0, 1.0);
          final sortedUsers = userMaxIncomes.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          completed = sortedUsers.isNotEmpty && sortedUsers.first.key == userId;
        }

        await _updateChallengeProgress(
          userId,
          'big_income_leader',
          userProgress,
          completed,
          challenge,
        );

        if (completed) {
          print('Big Income Leader completed for user: $userId, max income: ${userMaxIncomes[userId]}');
        } else {
          print('Big Income Leader progress: ${(userProgress * 100).toStringAsFixed(1)}%, max income: $maxIncome');
        }
      }
      await _loadChallenges();
    });
  }

  Future<void> _updateChallengeProgress(String userId,
      String challengeId,
      double progress,
      bool completed,
      Map<String, dynamic> challenge) async {
    final challengeRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('challenges')
        .doc(challengeId);

    if (completed) {
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

      await challengeRef.delete();

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Challenge completed: ${challenge['title']}! +${challenge['points']} points')),
        );
      }
    } else {
      await challengeRef.update({
        'progress': progress,
        'completed': completed,
      });
    }
    print('Updated challenge $challengeId for user: $userId, progress: ${(progress * 100).toStringAsFixed(1)}%, completed: $completed');
  }

  Future<void> _awardPoints(String userId, int points) async {
    final userRef = _firestore.collection('users').doc(userId);
    await userRef.set({
      'points': FieldValue.increment(points),
    }, SetOptions(merge: true));
    print('Awarded $points points to user: $userId');
  }

  Future<void> _loadChallenges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for loading challenges');
      return;
    }

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
      print('Loaded ${userChallenges.length} challenges for user: $userId');
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load challenges: $e')),
      );
    }
  }

  Future<void> _joinCommunityChallenge(String challengeId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for joining community challenge');
      return;
    }

    final communityChallenge = await _firestore
        .collection('community_challenges')
        .doc(challengeId)
        .get();
    if (!communityChallenge.exists) {
      print('Community challenge $challengeId does not exist');
      return;
    }

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
    print('User $userId joined community challenge: $challengeId');
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
            ...challenges.map((challenge) {
              final userChallenge = userChallenges.firstWhere(
                    (uc) => uc['id'] == challenge['id'],
                orElse: () => {},
              );
              final isJoined = userChallenge.isNotEmpty;
              return Card(
                color: Color.fromRGBO(33, 35, 34, 1),
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    challenge['title'],
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge['description'],
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      if (isJoined) ...[
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (userChallenge['progress'] as double?)?.clamp(0.0, 1.0) ?? 0.0,
                          backgroundColor: Colors.grey[700],
                          valueColor: AlwaysStoppedAnimation(Colors.teal),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${((userChallenge['progress'] as double?) ?? 0.0) * 100}% Complete',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  trailing: isJoined
                      ? Icon(Icons.check, color: Colors.green)
                      : ElevatedButton(
                    onPressed: () async {
                      await _joinCommunityChallenge(challenge['id']);
                    },
                    child: Text('Join'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              );
            }),
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