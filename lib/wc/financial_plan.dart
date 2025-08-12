import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fyp/ch/goal_progress.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/goal.dart';
import 'package:fyp/ch/goal_type.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FinancialPlanPage(),
    );
  }
}

class FinancialPlan {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final String category;
  final DateTime createdAt;
  final DateTime targetDate;
  final List<String> actionItems;
  final Map<String, double> budgetAllocation;
  final double progressPercentage;
  final bool isActive;
  final Map<String, double>? monthlyTargets;

  FinancialPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.category,
    required this.createdAt,
    required this.targetDate,
    required this.actionItems,
    required this.budgetAllocation,
    this.progressPercentage = 0.0,
    this.isActive = true,
    this.monthlyTargets,
  });

  factory FinancialPlan.fromMap(Map<String, dynamic> data, String id) {
    return FinancialPlan(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      targetAmount: (data['targetAmount'] ?? 0.0).toDouble(),
      category: data['category'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      targetDate: (data['targetDate'] as Timestamp).toDate(),
      actionItems: List<String>.from(data['actionItems'] ?? []),
      budgetAllocation: Map<String, double>.from(data['budgetAllocation'] ?? {}),
      progressPercentage: (data['progressPercentage'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
      monthlyTargets: data['monthlyTargets'] != null
          ? Map<String, double>.from(data['monthlyTargets'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'targetAmount': targetAmount,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetDate': Timestamp.fromDate(targetDate),
      'actionItems': actionItems,
      'budgetAllocation': budgetAllocation,
      'progressPercentage': progressPercentage,
      'isActive': isActive,
      'monthlyTargets': monthlyTargets,
    };
  }
}

class FinancialPlanPage extends StatefulWidget {
  const FinancialPlanPage({super.key});

  @override
  _FinancialPlanPageState createState() => _FinancialPlanPageState();
}

class _FinancialPlanPageState extends State<FinancialPlanPage> with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  GenerativeModel? _model;
  TabController? _tabController;
  bool _isLoading = false;
  int _selectedIndex = 2;

  static const String _apiKey = 'AIzaSyAo8tGXkOuvO6ZmJkZJu1bzpgoGnUWxqnk';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<GenerativeModel> _getGenerativeModel() async {
    if (_model == null) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: 'AIzaSyAo8tGXkOuvO6ZmJkZJu1bzpgoGnUWxqnk',
      );
    }
    return _model!;
  }

  // Fixed data fetching with better error handling
  Future<Map<String, dynamic>> _fetchFinancialData(String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);

      // Get current month transactions
      final transactionsSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      double monthlyIncome = 0;
      double monthlyExpenses = 0;
      Map<String, double> categorySpending = {};

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final type = data['type'] ?? '';

        if (type == 'income') {
          monthlyIncome += amount;
        } else if (type == 'expense') {
          monthlyExpenses += amount;

          // Get category name
          final categoryRef = data['category'] as DocumentReference?;
          if (categoryRef != null) {
            try {
              final categoryDoc = await categoryRef.get();
              if (categoryDoc.exists) {
                final categoryName = (categoryDoc.data() as Map<String, dynamic>)?['name'] ?? 'Other';
                categorySpending[categoryName] =
                    (categorySpending[categoryName] ?? 0) + amount;
              }
            } catch (e) {
              print('Error fetching category: $e');
            }
          }
        }
      }

      // Calculate savings rate
      final savingsRate = monthlyIncome > 0
          ? ((monthlyIncome - monthlyExpenses) / monthlyIncome)
          : 0.0;

      return {
        'monthlyIncome': monthlyIncome,
        'monthlyExpenses': monthlyExpenses,
        'savingsRate': savingsRate,
        'categorySpending': categorySpending,
        'monthlySavings': monthlyIncome - monthlyExpenses,
      };
    } catch (e) {
      print('Error fetching financial data: $e');
      return {
        'monthlyIncome': 0.0,
        'monthlyExpenses': 0.0,
        'savingsRate': 0.0,
        'categorySpending': <String, double>{},
        'monthlySavings': 0.0,
      };
    }
  }

  // SIMPLIFIED AI plan generation
  Future<FinancialPlan> _generatePersonalizedFinancialPlan(String userId) async {
    setState(() => _isLoading = true);

    try {
      final model = await _getGenerativeModel();
      final financialData = await _fetchFinancialData(userId);

      // Get user's goals - FIXED QUERY
      final goalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['active', 'in_progress'])
          .get();

      // Also check goals without status field (default to active)
      final allGoalsSnapshot = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .get();

      // Combine and filter goals
      final allGoals = allGoalsSnapshot.docs.where((doc) {
        final data = doc.data();
        final status = data['status'] ?? 'active'; // Default to active if no status
        return status != 'completed';
      }).toList();

      final goals = allGoals.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Goal',
          'targetAmount': (data['totalAmount'] ?? 0).toDouble(),
          'depositedAmount': (data['depositedAmount'] ?? 0).toDouble(),
          'type': data['type'] ?? 'regular',
          'progress': _calculateGoalProgress(data),
        };
      }).toList();

      final monthlyIncome = financialData['monthlyIncome'] as double;
      final monthlyExpenses = financialData['monthlyExpenses'] as double;
      final savingsRate = financialData['savingsRate'] as double;
      final categorySpending = financialData['categorySpending'] as Map<String, double>;
      final monthlySavings = financialData['monthlySavings'] as double;

      // SIMPLIFIED AI PROMPT
      final prompt = '''
        Create a simple financial plan for this month based on:
        
        MONEY SITUATION:
        - Income: RM${monthlyIncome.toStringAsFixed(0)}
        - Expenses: RM${monthlyExpenses.toStringAsFixed(0)}
        - Left over: RM${monthlySavings.toStringAsFixed(0)}
        
        GOALS (${goals.length} active):
        ${goals.map((g) => '- ${g['name']}: Need RM${(g['targetAmount'] - g['depositedAmount']).toStringAsFixed(0)} more').join('\n')}
        
        TOP SPENDING:
        ${categorySpending.entries.take(3).map((e) => '- ${e.key}: RM${e.value.toStringAsFixed(0)}').join('\n')}
        
        Give me:
        1. One realistic monthly savings goal in RM
        2. 3-5 simple action steps
        3. Which goal to focus on first
        
        Keep it simple and easy to understand!
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final aiResponse = response.text ?? '';

      // SIMPLIFIED parsing
      List<String> actionItems = _parseSimpleActionItems(aiResponse, goals, categorySpending, monthlyIncome);
      double monthlyTarget = _calculateRealisticTarget(monthlyIncome, monthlyExpenses, goals);
      Map<String, double> budgetAllocation = _createSimpleBudget(monthlyIncome, monthlyExpenses);

      final plan = FinancialPlan(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Your Money Plan - ${DateFormat('MMM yyyy').format(DateTime.now())}',
        description: goals.isNotEmpty
            ? 'Focus on ${goals.first['name']} and save RM${monthlyTarget.toStringAsFixed(0)} this month'
            : 'Build your emergency fund and start saving RM${monthlyTarget.toStringAsFixed(0)} monthly',
        targetAmount: monthlyTarget,
        category: 'savings',
        createdAt: DateTime.now(),
        targetDate: DateTime.now().add(const Duration(days: 30)),
        actionItems: actionItems,
        budgetAllocation: budgetAllocation,
        monthlyTargets: {
          'savings': monthlyTarget,
          'goal_focus': goals.isNotEmpty ? monthlyTarget * 0.6 : 0,
          'emergency': monthlyTarget * 0.4,
        },
      );

      // Save plan to Firestore
      await _firestore.collection('financial_plans').doc(plan.id).set({
        ...plan.toMap(),
        'userId': userId,
      });

      return plan;
    } catch (e) {
      print('Error generating plan: $e');
      return _createSimpleFallbackPlan(userId);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // SIMPLIFIED action items parsing
  List<String> _parseSimpleActionItems(
      String aiResponse,
      List<Map<String, dynamic>> goals,
      Map<String, double> categorySpending,
      double monthlyIncome
      ) {
    List<String> actionItems = [];

    // Priority 1: Address top spending category
    if (categorySpending.isNotEmpty) {
      final topCategory = categorySpending.entries.first;
      final reduction = (topCategory.value * 0.15).toStringAsFixed(0);
      actionItems.add('Cut ${topCategory.key} spending by RM$reduction this month');
    }

    // Priority 2: Focus on main goal
    if (goals.isNotEmpty) {
      final mainGoal = goals.first;
      final needed = (mainGoal['targetAmount'] - mainGoal['depositedAmount']).toDouble();
      final monthlyGoalAmount = (needed / 6).clamp(50, monthlyIncome * 0.3);
      actionItems.add('Save RM${monthlyGoalAmount.toStringAsFixed(0)} for ${mainGoal['name']}');
    }

    // Priority 3: Build emergency fund
    actionItems.add('Set aside RM${(monthlyIncome * 0.1).toStringAsFixed(0)} for emergencies');

    // Priority 4: Track spending
    actionItems.add('Check your expenses every 3 days using the app');

    // Priority 5: Review subscriptions
    actionItems.add('Cancel unused subscriptions (target: save RM50-100)');

    return actionItems;
  }

  double _calculateRealisticTarget(
      double income,
      double expenses,
      List<Map<String, dynamic>> goals
      ) {
    // Start with 15% of income as baseline
    double baseTarget = income * 0.15;

    // If spending more than earning, reduce target
    if (expenses > income) {
      baseTarget = income * 0.05; // Just 5% to start
    }

    // If have goals, consider them
    if (goals.isNotEmpty) {
      final totalNeeded = goals.fold(0.0, (sum, goal) =>
      sum + (goal['targetAmount'] - goal['depositedAmount']));
      final monthlyGoalNeed = totalNeeded / 12; // Spread over a year

      // Use the higher of base target or goal need, but cap at 30% of income
      baseTarget = (baseTarget + monthlyGoalNeed * 0.5).clamp(50, income * 0.3);
    }

    return baseTarget.clamp(50, income * 0.4);
  }

  Map<String, double> _createSimpleBudget(double income, double expenses) {
    final expenseRatio = (expenses / income).clamp(0.4, 0.8);
    final savingsRatio = 0.2;
    final remainingRatio = 1.0 - expenseRatio - savingsRatio;

    return {
      'needs': expenseRatio,
      'savings': savingsRatio,
      'wants': remainingRatio.clamp(0.05, 0.3),
    };
  }

  double _calculateGoalProgress(Map<String, dynamic> goalData) {
    final total = (goalData['totalAmount'] ?? 1).toDouble();
    final deposited = (goalData['depositedAmount'] ?? 0).toDouble();
    return (deposited / total * 100).clamp(0, 100);
  }

  // Simple fallback plan
  FinancialPlan _createSimpleFallbackPlan(String userId) {
    return FinancialPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Your Starter Money Plan',
      description: 'Simple steps to improve your finances',
      targetAmount: 300.0,
      category: 'savings',
      createdAt: DateTime.now(),
      targetDate: DateTime.now().add(const Duration(days: 30)),
      actionItems: [
        'Save RM300 this month (RM10 per day)',
        'Track all your spending for one week',
        'Find one subscription to cancel',
        'Cook at home 3 times this week',
        'Set up automatic savings of RM100',
      ],
      budgetAllocation: {
        'needs': 0.6,
        'savings': 0.2,
        'wants': 0.2,
      },
    );
  }

  Widget _buildOverviewTab(String userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthlyOverview(userId),
          const SizedBox(height: 20),
          _buildQuickActions(userId),
          const SizedBox(height: 20),
          _buildGoalsProgress(userId),
          const SizedBox(height: 20),
          _buildCurrentPlanSummary(userId),
        ],
      ),
    );
  }

  Widget _buildMonthlyOverview(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchFinancialData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final income = data['monthlyIncome'] as double;
        final expenses = data['monthlyExpenses'] as double;
        final savings = data['monthlySavings'] as double;
        final savingsRate = data['savingsRate'] as double;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.teal.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This Month',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildOverviewItem('Income', 'RM${income.toStringAsFixed(0)}', Icons.arrow_upward),
                  _buildOverviewItem('Expenses', 'RM${expenses.toStringAsFixed(0)}', Icons.arrow_downward),
                  _buildOverviewItem('Saved', 'RM${savings.toStringAsFixed(0)}', Icons.savings),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: savingsRate.clamp(0, 1),
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  savingsRate > 0.2 ? Colors.greenAccent : Colors.orangeAccent,
                ),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                'Savings Rate: ${(savingsRate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(String userId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                'New Plan',
                Icons.add_chart,
                Colors.teal,
                    () => _generateNewPlan(userId),
              ),
              _buildActionButton(
                'Add Goal',
                Icons.flag,
                Colors.purple,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalTypeSelectionPage()),
                  );
                },
              ),
              _buildActionButton(
                'View Goals',
                Icons.list_alt,
                Colors.blue,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GoalPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // FIXED Goals Progress Widget
  Widget _buildGoalsProgress(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter out completed goals
        final activeGoals = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'active'; // Default to active
          return status != 'completed';
        }).toList();

        if (activeGoals.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.flag, color: Colors.grey, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'No active goals',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GoalTypeSelectionPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text('Create Goal', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Goals',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${activeGoals.length} active',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...activeGoals.take(3).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'Unnamed Goal';
                final totalAmount = (data['totalAmount'] ?? 1).toDouble();
                final depositedAmount = (data['depositedAmount'] ?? 0).toDouble();
                final progress = (depositedAmount / totalAmount).clamp(0.0, 1.0);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoalProgressPage(goalId: doc.id),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(color: Colors.teal, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[700],
                          color: Colors.teal,
                          minHeight: 4,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RM${depositedAmount.toStringAsFixed(0)} of RM${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentPlanSummary(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('financial_plans')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.analytics, color: Colors.grey, size: 40),
                  const SizedBox(height: 8),
                  const Text(
                    'No active plan',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _generateNewPlan(userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text('Generate Plan', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        final planDoc = snapshot.data!.docs.first;
        final plan = FinancialPlan.fromMap(
          planDoc.data() as Map<String, dynamic>,
          planDoc.id,
        );

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Plan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${plan.progressPercentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                plan.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.track_changes, color: Colors.teal, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Target: RM${plan.targetAmount.toStringAsFixed(0)}/month',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: plan.progressPercentage / 100,
                backgroundColor: Colors.grey[800],
                color: Colors.teal,
                minHeight: 6,
              ),
              const SizedBox(height: 12),
              const Text(
                'Top Actions:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...plan.actionItems.take(2).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _tabController?.animateTo(1);
                },
                child: const Text(
                  'View Full Plan →',
                  style: TextStyle(color: Colors.teal, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // SIMPLIFIED Plans Tab
  Widget _buildPlansTab(String userId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Money Plans',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _generateNewPlan(userId),
                icon: _isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                label: Text(_isLoading ? 'Creating...' : 'New Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildPlansList(userId)),
      ],
    );
  }

  // SIMPLIFIED Plans List
  Widget _buildPlansList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('financial_plans')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[700]!, width: 1),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.teal, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'No Money Plans Yet',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Get personalized advice based on your spending and goals',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _generateNewPlan(userId),
                        icon: const Icon(Icons.auto_awesome, color: Colors.white),
                        label: const Text('Create My First Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final plans = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final doc = plans[index];
            final plan = FinancialPlan.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: plan.isActive ? Colors.teal.withOpacity(0.3) : Colors.grey[700]!,
                ),
              ),
              child: Column(
                children: [
                  // Simple Plan Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: plan.isActive ? Colors.teal.withOpacity(0.2) : Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.lightbulb,
                                color: plan.isActive ? Colors.teal : Colors.white54,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.description,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (plan.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Simple Target Display
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Monthly Target',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              Text(
                                'RM${plan.targetAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Simple Action Items
                  if (plan.actionItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Action Steps',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...plan.actionItems.take(3).map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.teal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          if (plan.actionItems.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '+${plan.actionItems.length - 3} more steps',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Simple Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showSimplePlanDetails(plan),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.teal),
                            ),
                            child: const Text(
                              'View Full Plan',
                              style: TextStyle(color: Colors.teal),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (plan.isActive)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showProgressHelp(plan),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                              ),
                              child: const Text(
                                'How Am I Doing?',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGoalsTab(String userId) {
    return const GoalPage();
  }

  Future<void> _generateNewPlan(String userId) async {
    try {
      await _generatePersonalizedFinancialPlan(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your new money plan is ready! 🎉'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Oops! Couldn\'t create plan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // SIMPLIFIED plan details dialog
  void _showSimplePlanDetails(FinancialPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.8,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Simple Plan Title
                Text(
                  plan.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  plan.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Monthly Goal
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.track_changes, color: Colors.teal),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Monthly Goal',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            'Save RM${plan.targetAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action Steps
                const Text(
                  'Your Action Steps',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...plan.actionItems.asMap().entries.map((entry) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // SIMPLIFIED progress help
  void _showProgressHelp(FinancialPlan plan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'How Am I Doing?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your goal: Save RM${plan.targetAmount.toStringAsFixed(0)} this month',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'To track your progress:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Record all your spending in the app\n'
                  '• Check your savings rate regularly\n'
                  '• Follow your action steps\n'
                  '• Update your goal deposits',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 Tip: Small consistent steps work better than big changes!',
                style: TextStyle(color: Colors.teal, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(int index) {
    if (index == _selectedIndex) return;

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/trending');
    } else if (index == 2) {
      // Already on financial plan page
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1C),
        body: const Center(
          child: Text(
            'Please log in to access Financial Planning',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _handleNavigation,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      appBar: AppBar(
        title: const Text('Money Advisor', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Plans'),
            Tab(text: 'Goals'),
          ],
          labelColor: Colors.teal,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.teal,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(userId),
          _buildPlansTab(userId),
          _buildGoalsTab(userId),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _handleNavigation,
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }
}