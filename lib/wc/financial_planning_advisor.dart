import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// Enum for financial scenarios
enum FinancialScenario {
  highDebt,
  lowSavings,
  majorPurchase,
  stable,
}

// Data models
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

// Financial Planning Advisor Logic
class FinancialAdvisor {
  static Interpreter? _interpreter;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> initModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/savings_model.tflite');
    } catch (e) {
      print('Error loading TFLite model: $e');
    }
  }

  static Future<double> predictSavingsTarget(UserFinancialData data) async {
    if (_interpreter == null) {
      await initModel();
    }
    double totalSpending = data.spendingByCategory.isEmpty
        ? 0.0
        : data.spendingByCategory.values.reduce((a, b) => a + b);
    var input = [[data.monthlyIncome, totalSpending, data.totalDebt, data.currentSavings]];
    var output = [List.filled(1, 0.0)];
    try {
      _interpreter!.run(input, output);
      return output[0][0].clamp(0.0, data.monthlyIncome * 0.5);
    } catch (e) {
      print('Error running TFLite model: $e');
      return data.monthlyIncome * 0.2; // Fallback
    }
  }

  static Future<UserFinancialData> fetchUserFinancialData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('No user logged in');
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final transactionsSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    double monthlyIncome = 0.0;
    Map<String, double> spendingByCategory = {};
    double currentSavings = 0.0;
    double totalDebt = 0.0;
    Map<String, double>? userDefinedGoals;

    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] as double);
      final categoryRef = data['category'] as DocumentReference;
      final categorySnapshot = await categoryRef.get();
      final categoryData = categorySnapshot.data() as Map<String, dynamic>?;
      if (categoryData == null) continue;
      final categoryName = categoryData['name'] as String? ?? 'Unknown';
      final categoryType = categoryData['type'] as String? ?? 'unknown';
      if (categoryType == 'income') monthlyIncome += amount;
      else if (categoryType == 'expense') spendingByCategory.update(categoryName, (v) => v + amount, ifAbsent: () => amount);
    }

    try {
      final userSnapshot = await _firestore.collection('users').doc(userId).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.data()!;
        currentSavings = (userData['savings'] is int)
            ? (userData['savings'] as int).toDouble()
            : (userData['savings'] as double? ?? 0.0);
        totalDebt = (userData['debt'] is int)
            ? (userData['debt'] as int).toDouble()
            : (userData['debt'] as double? ?? 0.0);
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    try {
      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userid', isEqualTo: userId)
          .get();
      userDefinedGoals = {
        for (var doc in goalsSnapshot.docs)
          doc['name'] as String: (doc['targetAmount'] is int)
              ? (doc['targetAmount'] as int).toDouble()
              : (doc['targetAmount'] as double)
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
    final savingsTarget = await predictSavingsTarget(data);

    double monthlyBudget;
    List<ActionItem> actionItems = generatePersonalizedActions(data, savingsTarget);
    List<Goal> goals = [];

    switch (scenario) {
      case FinancialScenario.highDebt:
        monthlyBudget = data.monthlyIncome * 0.6;
        goals.add(Goal(name: 'Debt Reduction', targetAmount: data.totalDebt * 0.5, deadline: DateTime.now().add(Duration(days: 365))));
        break;
      case FinancialScenario.lowSavings:
        monthlyBudget = data.monthlyIncome * 0.65;
        goals.add(Goal(name: 'Emergency Fund', targetAmount: data.monthlyIncome * 3, deadline: DateTime.now().add(Duration(days: 540))));
        break;
      case FinancialScenario.majorPurchase:
        monthlyBudget = data.monthlyIncome * 0.6;
        if (data.userDefinedGoals != null) {
          data.userDefinedGoals!.forEach((name, amount) {
            goals.add(Goal(name: name, targetAmount: amount, deadline: DateTime.now().add(Duration(days: 730))));
          });
        }
        break;
      case FinancialScenario.stable:
        monthlyBudget = data.monthlyIncome * 0.7;
        goals.addAll([
          Goal(name: 'Emergency Fund', targetAmount: 1000.0, deadline: DateTime.now().add(Duration(days: 180))),
          Goal(name: 'Retirement Savings', targetAmount: data.monthlyIncome * 2, deadline: DateTime.now().add(Duration(days: 730))),
        ]);
        break;
    }

    data.spendingByCategory.forEach((category, amount) {
      if (amount > data.monthlyIncome * 0.15 && scenario != FinancialScenario.highDebt) {
        actionItems.add(ActionItem(description: 'Cut $category spending by 15%', amount: amount * 0.15, category: category));
      }
    });

    return FinancialPlan(
      monthlyBudget: monthlyBudget,
      savingsTarget: savingsTarget,
      actionItems: actionItems,
      goals: goals,
      scenario: scenario,
    );
  }

  static List<ActionItem> generatePersonalizedActions(UserFinancialData data, double savingsTarget) {
    List<ActionItem> actions = [];
    actions.add(ActionItem(description: 'Allocate to emergency fund', amount: savingsTarget * 0.5, category: 'Savings'));
    var maxSpending = data.spendingByCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (maxSpending.value > data.monthlyIncome * 0.2) {
      actions.add(ActionItem(description: 'Reduce ${maxSpending.key} by 20%', amount: maxSpending.value * 0.2, category: maxSpending.key));
    }
    double discretionary = _calculateDiscretionarySpending(data);
    if (discretionary > 0) {
      actions.add(ActionItem(description: 'Cut discretionary spending by 15%', amount: discretionary * 0.15, category: 'Discretionary'));
    }
    return actions;
  }

  static FinancialScenario _determineScenario(UserFinancialData data) {
    double debtToIncomeRatio = data.monthlyIncome > 0 ? data.totalDebt / data.monthlyIncome : 0;
    double savingsToIncomeRatio = data.monthlyIncome > 0 ? data.currentSavings / data.monthlyIncome : 0;
    if (debtToIncomeRatio > 3) return FinancialScenario.highDebt;
    else if (savingsToIncomeRatio < 0.5) return FinancialScenario.lowSavings;
    else if (data.userDefinedGoals != null && data.userDefinedGoals!.isNotEmpty) return FinancialScenario.majorPurchase;
    else return FinancialScenario.stable;
  }

  static double _calculateDiscretionarySpending(UserFinancialData data) {
    List<String> discretionaryCategories = ['Entertainment', 'Shopping', 'Dining', 'Travel'];
    return data.spendingByCategory.entries
        .where((entry) => discretionaryCategories.contains(entry.key))
        .fold(0.0, (sum, entry) => sum + entry.value);
  }

  static double predictSavings(FinancialPlan plan, double adherence) {
    double baseSavings = plan.savingsTarget * 12 * adherence;
    switch (plan.scenario) {
      case FinancialScenario.highDebt: return baseSavings * 0.8;
      case FinancialScenario.lowSavings: return baseSavings * 1.2;
      case FinancialScenario.majorPurchase: return baseSavings * 1.1;
      case FinancialScenario.stable: return baseSavings;
    }
  }
}

// UI Screens
class FinancialPlanningScreen extends StatefulWidget {
  const FinancialPlanningScreen({super.key});

  @override
  _FinancialPlanningScreenState createState() => _FinancialPlanningScreenState();
}

class _FinancialPlanningScreenState extends State<FinancialPlanningScreen> {
  late Future<FinancialPlan> _planFuture;

  @override
  void initState() {
    super.initState();
    _planFuture = FinancialAdvisor.generatePlan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Planning Advisor'),
        backgroundColor: Color.fromRGBO(28, 28, 28, 0),
      ),
      backgroundColor: Color.fromRGBO(28, 28, 28, 0),
      body: FutureBuilder<FinancialPlan>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No plan generated', style: TextStyle(color: Colors.white)));
          }
          final plan = snapshot.data!;
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Card(
                  elevation: 4.0,
                  color: Color.fromRGBO(33, 35, 34, 1),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Financial Scenario: ${_scenarioToString(plan.scenario)}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                        ),
                        SizedBox(height: 8.0),
                        Text('Recommended Budget: RM ${plan.monthlyBudget.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16.0, color: Colors.white)),
                        Text('Savings Target: RM ${plan.savingsTarget.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16.0, color: Colors.white)),
                        Text(
                          'Predicted Yearly Savings: RM ${FinancialAdvisor.predictSavings(plan, 0.9).toStringAsFixed(2)} (90% adherence)',
                          style: TextStyle(fontSize: 16.0, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.0),
                Text('Action Items', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                ...plan.actionItems.map((item) => Expanded(
                  child: Card(
                    color: Color.fromRGBO(33, 35, 34, 1),
                    child: ListTile(
                      title: Text(item.description, style: TextStyle(color: Colors.white)),
                      subtitle: Text('RM ${item.amount.toStringAsFixed(2)} (${item.category})',
                          style: TextStyle(color: Colors.white70)),
                      trailing: Icon(Icons.check_circle_outline, color: Colors.teal),
                    ),
                  ),
                )),
                SizedBox(height: 16.0),
                Text('Goal Tracker', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                ...plan.goals.map((goal) => Card(
                  elevation: 2.0,
                  color: Color.fromRGBO(33, 35, 34, 1),
                  child: ListTile(
                    title: Text(goal.name, style: TextStyle(color: Colors.white)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target: RM ${goal.targetAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.white70)),
                        Text('Current: RM ${goal.currentAmount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.white70)),
                        Text('Deadline: ${DateFormat.yMMMd().format(goal.deadline)}',
                            style: TextStyle(color: Colors.white70)),
                        LinearProgressIndicator(
                          value: goal.progress,
                          backgroundColor: Colors.grey,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goal.progress < 0.2 ? Colors.red : (goal.progress > 0.8 ? Colors.green : Colors.teal),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.add, color: Colors.teal),
                      tooltip: 'Add RM 100 to goal',
                      onPressed: () async {
                        final userId = FinancialAdvisor._auth.currentUser?.uid;
                        if (userId != null) {
                          await FinancialAdvisor._firestore.collection('goals').doc('$userId${goal.name}').set({
                            'userid': userId,
                            'name': goal.name,
                            'targetAmount': goal.targetAmount,
                            'currentAmount': goal.currentAmount + 100.0,
                            'deadline': Timestamp.fromDate(goal.deadline),
                          }, SetOptions(merge: true));
                          setState(() {
                            goal.currentAmount += 100.0;
                            _planFuture = FinancialAdvisor.generatePlan();
                          });
                        }
                      },
                    ),
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  String _scenarioToString(FinancialScenario scenario) {
    switch (scenario) {
      case FinancialScenario.highDebt: return 'High Debt';
      case FinancialScenario.lowSavings: return 'Low Savings';
      case FinancialScenario.majorPurchase: return 'Major Purchase';
      case FinancialScenario.stable: return 'Stable Finances';
    }
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    TextEditingController savingsController = TextEditingController();
    TextEditingController debtController = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: savingsController, decoration: InputDecoration(labelText: 'Savings')),
            TextField(controller: debtController, decoration: InputDecoration(labelText: 'Debt')),
            ElevatedButton(
              onPressed: () async {
                final userId = FinancialAdvisor._auth.currentUser?.uid;
                if (userId != null) {
                  await FinancialAdvisor._firestore.collection('users').doc(userId).update({
                    'savings': double.tryParse(savingsController.text) ?? 0.0,
                    'debt': double.tryParse(debtController.text) ?? 0.0,
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddGoalScreen extends StatefulWidget {
  @override
  _AddGoalScreenState createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  double targetAmount = 0.0;
  DateTime deadline = DateTime.now().add(Duration(days: 365));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Goal')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Goal Name'),
                validator: (value) => value?.isEmpty ?? true ? 'Enter name' : null,
                onSaved: (value) => name = value!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Target Amount'),
                keyboardType: TextInputType.number,
                validator: (value) => double.tryParse(value ?? '') == null ? 'Enter valid amount' : null,
                onSaved: (value) => targetAmount = double.parse(value!),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    final userId = FinancialAdvisor._auth.currentUser?.uid;
                    print('User ID: $userId'); // Debug output
                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not logged in')));
                      return;
                    }
                    await FinancialAdvisor._firestore.collection('goals').doc('$userId$name').set({
                      'userid': userId,
                      'name': name,
                      'targetAmount': targetAmount,
                      'currentAmount': 0.0,
                      'deadline': Timestamp.fromDate(deadline),
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text('Save Goal'),
              ),

            ],
          ),
        ),
      ),
    );
  }
}