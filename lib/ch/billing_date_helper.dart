import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Save this as billing_date_helper.dart

class BillingDateHelper {

  /// Get the user's billing start date from Firestore
  static Future<int> getBillingStartDate() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return 23; // Default fallback

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data()!.containsKey('billStartDate')) {
        return userDoc.data()!['billStartDate'] ?? 23;
      }
      return 23; // Default fallback
    } catch (e) {
      print('Error getting billing start date: $e');
      return 23; // Default fallback
    }
  }

  /// Get the current billing period start and end dates
  static Future<Map<String, DateTime>> getCurrentBillingPeriod() async {
    final billStartDate = await getBillingStartDate();
    final now = DateTime.now();

    DateTime startDate;
    DateTime endDate;

    // Calculate the start date of current billing period
    if (now.day >= billStartDate) {
      // We're in the current month's billing period
      startDate = DateTime(now.year, now.month, billStartDate);
      endDate = DateTime(now.year, now.month + 1, billStartDate - 1, 23, 59, 59);
    } else {
      // We're in the previous month's billing period
      startDate = DateTime(now.year, now.month - 1, billStartDate);
      endDate = DateTime(now.year, now.month, billStartDate - 1, 23, 59, 59);
    }

    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  /// Get billing period for a specific date
  static Future<Map<String, DateTime>> getBillingPeriodForDate(DateTime date) async {
    final billStartDate = await getBillingStartDate();

    DateTime startDate;
    DateTime endDate;

    if (date.day >= billStartDate) {
      // The date is in its own month's billing period
      startDate = DateTime(date.year, date.month, billStartDate);
      endDate = DateTime(date.year, date.month + 1, billStartDate - 1, 23, 59, 59);
    } else {
      // The date is in the previous month's billing period
      startDate = DateTime(date.year, date.month - 1, billStartDate);
      endDate = DateTime(date.year, date.month, billStartDate - 1, 23, 59, 59);
    }

    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  /// Get the budget document ID for the current billing period
  static Future<String> getCurrentBudgetDocId() async {
    final period = await getCurrentBillingPeriod();
    final startDate = period['startDate']!;

    // Format: "2024-08-23" (year-month-day format for the billing start date)
    return "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
  }

  /// Get budget document ID for a specific date's billing period
  static Future<String> getBudgetDocIdForDate(DateTime date) async {
    final period = await getBillingPeriodForDate(date);
    final startDate = period['startDate']!;

    return "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
  }

  /// Check if a transaction date falls within a specific billing period
  static Future<bool> isTransactionInCurrentPeriod(DateTime transactionDate) async {
    final period = await getCurrentBillingPeriod();
    final startDate = period['startDate']!;
    final endDate = period['endDate']!;

    return transactionDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
        transactionDate.isBefore(endDate.add(const Duration(days: 1)));
  }

  /// Get all transactions for the current billing period
  static Future<List<QueryDocumentSnapshot>> getCurrentPeriodTransactions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final period = await getCurrentBillingPeriod();
    final startDate = period['startDate']!;
    final endDate = period['endDate']!;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs;
    } catch (e) {
      print('Error getting current period transactions: $e');
      return [];
    }
  }

  /// Get all transactions for a specific billing period
  static Future<List<QueryDocumentSnapshot>> getTransactionsForPeriod(DateTime periodStartDate, DateTime periodEndDate) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStartDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(periodEndDate))
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs;
    } catch (e) {
      print('Error getting period transactions: $e');
      return [];
    }
  }

  /// Calculate total spending for current billing period
  static Future<double> getCurrentPeriodSpending() async {
    final transactions = await getCurrentPeriodTransactions();
    double totalSpending = 0.0;

    for (var transaction in transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0.0).toDouble();
      final type = data['type'] ?? 'expense';

      if (type == 'expense') {
        totalSpending += amount;
      }
    }

    return totalSpending;
  }

  /// Calculate total income for current billing period
  static Future<double> getCurrentPeriodIncome() async {
    final transactions = await getCurrentPeriodTransactions();
    double totalIncome = 0.0;

    for (var transaction in transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0.0).toDouble();
      final type = data['type'] ?? 'expense';

      if (type == 'income') {
        totalIncome += amount;
      }
    }

    return totalIncome;
  }

  /// Get budget for current billing period
  static Future<double?> getCurrentPeriodBudget() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    try {
      final budgetDocId = await getCurrentBudgetDocId();

      final budgetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc(budgetDocId)
          .get();

      if (budgetDoc.exists) {
        final data = budgetDoc.data()!;

        // Try different possible field names for the budget amount
        if (data.containsKey('amount')) {
          return data['amount']?.toDouble();
        } else if (data.containsKey('budget')) {
          return data['budget']?.toDouble();
        } else if (data.containsKey('budgetAmount')) {
          return data['budgetAmount']?.toDouble();
        } else if (data.containsKey('totalBudget')) {
          return data['totalBudget']?.toDouble();
        }
      }

      return null;
    } catch (e) {
      print('Error getting current period budget: $e');
      return null;
    }
  }

  /// Get remaining days in current billing period
  static Future<int> getRemainingDaysInPeriod() async {
    final period = await getCurrentBillingPeriod();
    final endDate = period['endDate']!;
    final now = DateTime.now();

    return endDate.difference(now).inDays + 1; // +1 to include today
  }

  /// Get progress percentage of current billing period (0-100)
  static Future<double> getBillingPeriodProgress() async {
    final period = await getCurrentBillingPeriod();
    final startDate = period['startDate']!;
    final endDate = period['endDate']!;
    final now = DateTime.now();

    final totalDays = endDate.difference(startDate).inDays + 1;
    final elapsedDays = now.difference(startDate).inDays + 1;

    return (elapsedDays / totalDays * 100).clamp(0.0, 100.0);
  }

  /// Format billing period as readable string
  static Future<String> getCurrentPeriodString() async {
    final period = await getCurrentBillingPeriod();
    final startDate = period['startDate']!;
    final endDate = period['endDate']!;

    final startFormatted = "${startDate.day}/${startDate.month}/${startDate.year}";
    final endFormatted = "${endDate.day}/${endDate.month}/${endDate.year}";

    return "$startFormatted - $endFormatted";
  }
}