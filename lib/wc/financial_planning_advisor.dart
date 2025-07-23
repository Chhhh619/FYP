import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum FinancialScenario { highDebt, lowSavings, majorPurchase, stable }

class FinancialPlan {
  final double monthlyBudget;
  final double savingsTarget;
  final List<ActionItem> actionItems;
  final List<Goal> goals;
  final FinancialScenario scenario;

  FinancialPlan({
    required this.monthlyBudget,
    required this.savingsTarget,
    required this.actionItems,
    required this.goals,
    required this.scenario,
  });
}

class ActionItem {
  final String description;
  final double amount;
  final String category;

  ActionItem({
    required this.description,
    required this.amount,
    required this.category,
  });
}

class Goal {
  final String name;
  final double targetAmount;
  double currentAmount;
  final DateTime deadline;

  Goal({
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.deadline,
  });

  double get progress => targetAmount > 0 ? currentAmount / targetAmount : 0.0;
}

class UserFinancialData {
  final double monthlyIncome;
  final Map<String, double> spendingByCategory;
  final double currentSavings;
  final double totalDebt;
  final Map<String, double>? userDefinedGoals;

  UserFinancialData({
    required this.monthlyIncome,
    required this.spendingByCategory,
    required this.currentSavings,
    required this.totalDebt,
    this.userDefinedGoals,
  });
}

class FinancialAdvisor {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static double _predictSavingsTarget(UserFinancialData data) {
    if (data.monthlyIncome <= 0) return 0.0; // Guard against zero income
    double totalSpending = data.spendingByCategory.isEmpty
        ? 0.0
        : data.spendingByCategory.values.reduce((a, b) => a + b);
    double discretionarySpending = _calculateDiscretionarySpending(data);
    double debtToIncomeRatio = data.totalDebt / data.monthlyIncome;

    double baseSavings = data.monthlyIncome * 0.2;
    if (debtToIncomeRatio > 3) {
      baseSavings = baseSavings * 0.5; // 10% for high debt
    } else if (discretionarySpending > data.monthlyIncome * 0.3) {
      baseSavings = (baseSavings + discretionarySpending * 0.2).clamp(0.0, data.monthlyIncome * 0.4);
    } else if (data.currentSavings < data.monthlyIncome * 0.5) {
      baseSavings = baseSavings * 1.5; // 30% for low savings
    }

    return baseSavings.clamp(0.0, data.monthlyIncome * 0.5);
  }

  static Future<UserFinancialData> fetchUserFinancialData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('No user logged in');

    final now = DateTime.now();
    final startOfPeriod = DateTime(now.year, now.month - 6, 1);
    final endOfPeriod = DateTime(now.year, now.month + 1, 0);

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfPeriod))
        .get();

    double monthlyIncome = 0.0;
    Map<String, double> spendingByCategory = {};
    double currentSavings = 0.0;
    double totalDebt = 0.0;
    Map<String, double>? userDefinedGoals;

    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final amount = (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] as double? ?? 0.0);
      final categoryRef = data['category'] as DocumentReference?;
      if (categoryRef == null) continue;
      final categorySnapshot = await categoryRef.get();
      final categoryData = categorySnapshot.data() as Map<String, dynamic>?;
      if (categoryData == null) continue;
      final categoryName = categoryData['name'] as String? ?? 'Unknown';
      final categoryType = categoryData['type'] as String? ?? 'unknown';
      if (categoryType == 'income') monthlyIncome += amount / 6;
      else if (categoryType == 'expense') spendingByCategory.update(categoryName, (v) => v + amount / 6, ifAbsent: () => amount / 6);
    }

    try {
      final userSnapshot = await _firestore.collection('users').doc(userId).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.data()!;
        currentSavings = (userData['savings'] is int) ? (userData['savings'] as int).toDouble() : (userData['savings'] as double? ?? 0.0);
        totalDebt = (userData['debt'] is int) ? (userData['debt'] as int).toDouble() : (userData['debt'] as double? ?? 0.0);
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    try {
      final goalsSnapshot = await _firestore.collection('goals').where('userid', isEqualTo: userId).get();
      userDefinedGoals = {
        for (var doc in goalsSnapshot.docs)
          doc['name'] as String: (doc['targetAmount'] is int) ? (doc['targetAmount'] as int).toDouble() : (doc['targetAmount'] as double)
      };
    } catch (e) {
      print('Error fetching goals: $e');
      userDefinedGoals = null;
    }

    return UserFinancialData(
      monthlyIncome: monthlyIncome,
      spendingByCategory: spendingByCategory,
      currentSavings: currentSavings,
      totalDebt: totalDebt,
      userDefinedGoals: userDefinedGoals,
    );
  }

  static Future<FinancialPlan> generatePlan() async {
    final data = await fetchUserFinancialData();
    final scenario = _determineScenario(data);
    final savingsTarget = _predictSavingsTarget(data);

    double monthlyBudget;
    List<ActionItem> actionItems = await generatePersonalizedActions(data, savingsTarget);
    List<Goal> goals = [];

    switch (scenario) {
      case FinancialScenario.highDebt:
        monthlyBudget = data.monthlyIncome * 0.6;
        goals.add(Goal(
          name: 'Debt Reduction',
          targetAmount: data.totalDebt * 0.5,
          deadline: DateTime.now().add(Duration(days: 365)),
        ));
        break;
      case FinancialScenario.lowSavings:
        monthlyBudget = data.monthlyIncome * 0.65;
        goals.add(Goal(
          name: 'Emergency Fund',
          targetAmount: data.monthlyIncome * 3,
          deadline: DateTime.now().add(Duration(days: 540)),
        ));
        break;
      case FinancialScenario.majorPurchase:
        monthlyBudget = data.monthlyIncome * 0.6;
        if (data.userDefinedGoals != null) {
          data.userDefinedGoals!.forEach((name, amount) {
            goals.add(Goal(
              name: name,
              targetAmount: amount,
              deadline: DateTime.now().add(Duration(days: 730)),
            ));
          });
        }
        break;
      case FinancialScenario.stable:
        monthlyBudget = data.monthlyIncome * 0.7;
        goals.addAll([
          Goal(
            name: 'Emergency Fund',
            targetAmount: 1000.0,
            deadline: DateTime.now().add(Duration(days: 180)),
          ),
          Goal(
            name: 'Retirement Savings',
            targetAmount: data.monthlyIncome * 2,
            deadline: DateTime.now().add(Duration(days: 730)),
          ),
        ]);
        break;
    }

    for (var goal in goals) {
      if (goal.name == 'Debt Reduction') {
        goal.currentAmount = data.totalDebt > 0 ? (await _calculateDebtPayments(data)) : 0.0;
      } else if (goal.name == 'Emergency Fund' || goal.name == 'Retirement Savings') {
        goal.currentAmount = await _calculateSavingsContributions(data, goal.name);
      }
    }

    return FinancialPlan(
      monthlyBudget: monthlyBudget,
      savingsTarget: savingsTarget,
      actionItems: actionItems,
      goals: goals,
      scenario: scenario,
    );
  }

  static Future<List<ActionItem>> generatePersonalizedActions(UserFinancialData data, double savingsTarget) async {
    List<ActionItem> actions = [];
    actions.add(ActionItem(
      description: 'Allocate to emergency fund',
      amount: savingsTarget * 0.5,
      category: 'Savings',
    ));

    var maxSpending = data.spendingByCategory.entries.isNotEmpty
        ? data.spendingByCategory.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    if (maxSpending != null && maxSpending.value > data.monthlyIncome * 0.2) {
      actions.add(ActionItem(
        description: 'Reduce ${maxSpending.key} by 20%',
        amount: maxSpending.value * 0.2,
        category: maxSpending.key,
      ));
    }

    double discretionary = _calculateDiscretionarySpending(data);
    if (discretionary > data.monthlyIncome * 0.1) {
      actions.add(ActionItem(
        description: 'Cut discretionary spending by 15%',
        amount: discretionary * 0.15,
        category: 'Discretionary',
      ));
    }

    return actions;
  }

  static double _calculateDiscretionarySpending(UserFinancialData data) {
    List<String> discretionaryCategories = ['Entertainment', 'Shopping', 'Dining', 'Travel'];
    return data.spendingByCategory.entries
        .where((entry) => discretionaryCategories.contains(entry.key))
        .fold(0.0, (sum, entry) => sum + entry.value);
  }

  static Future<double> _calculateSavingsContributions(UserFinancialData data, String goalName) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0.0; // Return 0 if no user is logged in
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('category', isEqualTo: _firestore.collection('categories').doc('Savings'))
        .get();
    return transactionsSnapshot.docs.fold<double>(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('amount')) return sum; // Guard against null data
      final amount = (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] as double);
      return sum + amount; // Explicitly typed fold ensures + operates on doubles
    });
  }

  static Future<double> _calculateDebtPayments(UserFinancialData data) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0.0; // Return 0 if no user is logged in
    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('category', isEqualTo: _firestore.collection('categories').doc('Debt Payment'))
        .get();
    return transactionsSnapshot.docs.fold<double>(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null || !data.containsKey('amount')) return sum; // Guard against null data
      final amount = (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] as double);
      return sum + amount; // Explicitly typed fold ensures + operates on doubles
    });
  }

  static FinancialScenario _determineScenario(UserFinancialData data) {
    double debtToIncomeRatio = data.monthlyIncome > 0 ? data.totalDebt / data.monthlyIncome : 0;
    double savingsToIncomeRatio = data.monthlyIncome > 0 ? data.currentSavings / data.monthlyIncome : 0;
    if (debtToIncomeRatio > 3) return FinancialScenario.highDebt;
    else if (savingsToIncomeRatio < 0.5) return FinancialScenario.lowSavings;
    else if (data.userDefinedGoals != null && data.userDefinedGoals!.isNotEmpty) return FinancialScenario.majorPurchase;
    else return FinancialScenario.stable;
  }

  static double predictSavings(FinancialPlan plan, double adherence) {
    double baseSavings = plan.savingsTarget * 12 * adherence;
    return baseSavings.clamp(0.0, plan.monthlyBudget * 12);
  }
}