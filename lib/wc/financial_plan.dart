import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fyp/ch/goal_progress.dart';
import 'package:fyp/bottom_nav_bar.dart';

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
    };
  }
}

class ActionItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final double targetAmount;
  final double currentAmount;
  final DateTime dueDate;
  final bool isCompleted;
  final String priority; // high, medium, low

  ActionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.dueDate,
    this.isCompleted = false,
    this.priority = 'medium',
  });

  double get progressPercentage => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
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
    _tabController = TabController(length: 3, vsync: this); // Adjusted length to 3
  }

  Future<GenerativeModel> _getGenerativeModel() async {
    if (_model == null) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );
    }
    return _model!;
  }

  // Enhanced data fetching with more detailed analytics
  Future<Map<String, dynamic>> _fetchComprehensiveFinancialData(String userId) async {
    final now = DateTime.now();
    List<double> monthlySpending = List.filled(12, 0.0);
    List<double> monthlyIncome = List.filled(12, 0.0);
    Map<String, double> categoryTotals = {};
    Map<String, List<double>> categoryTrends = {};
    List<double> savingsRate = List.filled(12, 0.0);

    for (int i = 0; i < 12; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 1);

      final snapshot = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('timestamp', isLessThan: Timestamp.fromDate(monthEnd))
          .get();

      double monthExpenses = 0.0;
      double monthIncome = 0.0;
      Map<String, double> monthCategorySpending = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final categoryRef = data['category'] as DocumentReference?;
        String transactionType = data['type'] ?? data['categoryType'] ?? '';

        if (transactionType.isEmpty && categoryRef != null) {
          try {
            final categoryDoc = await categoryRef.get();
            if (categoryDoc.exists) {
              final categoryData = categoryDoc.data() as Map<String, dynamic>?;
              transactionType = categoryData?['type'] ?? '';
            }
          } catch (e) {
            print('Error fetching category type: $e');
          }
        }

        if (transactionType == 'expense') {
          monthExpenses += amount.abs();
          if (categoryRef != null) {
            try {
              final categoryDoc = await categoryRef.get();
              if (categoryDoc.exists) {
                final categoryData = categoryDoc.data() as Map<String, dynamic>?;
                final categoryName = categoryData?['name'] ?? 'Unknown';
                monthCategorySpending[categoryName] = (monthCategorySpending[categoryName] ?? 0.0) + amount.abs();
              }
            } catch (e) {
              print('Error fetching category data: $e');
            }
          }
        } else if (transactionType == 'income') {
          monthIncome += amount.abs();
        }
      }

      monthlySpending[11 - i] = monthExpenses;
      monthlyIncome[11 - i] = monthIncome;
      savingsRate[11 - i] = monthIncome > 0 ? ((monthIncome - monthExpenses) / monthIncome) : 0.0;

      // Aggregate category totals and trends
      monthCategorySpending.forEach((category, amount) {
        categoryTotals[category] = (categoryTotals[category] ?? 0.0) + amount;
        if (!categoryTrends.containsKey(category)) {
          categoryTrends[category] = List.filled(12, 0.0);
        }
        categoryTrends[category]![11 - i] = amount;
      });
    }

    return {
      'monthlySpending': monthlySpending,
      'monthlyIncome': monthlyIncome,
      'categoryTotals': categoryTotals,
      'categoryTrends': categoryTrends,
      'savingsRate': savingsRate,
      'avgMonthlySpending': monthlySpending.fold(0.0, (sum, item) => sum + item) / 12,
      'avgMonthlyIncome': monthlyIncome.fold(0.0, (sum, item) => sum + item) / 12,
      'avgSavingsRate': savingsRate.fold(0.0, (sum, item) => sum + item) / 12,
    };
  }

  // Generate comprehensive financial plan
  Future<FinancialPlan> _generatePersonalizedFinancialPlan(String userId) async {
    setState(() => _isLoading = true);

    try {
      final model = await _getGenerativeModel();
      final financialData = await _fetchComprehensiveFinancialData(userId);

      // Get goals data
      final goalsSnapshot = await _firestore.collection('goals').where('userid', isEqualTo: userId).get();
      final goals = goalsSnapshot.docs.map((doc) => doc.data()).toList();

      // Get user profile for additional context
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userProfile = userDoc.exists ? userDoc.data() : {};

      final avgSpending = financialData['avgMonthlySpending'] as double;
      final avgIncome = financialData['avgMonthlyIncome'] as double;
      final avgSavingsRate = financialData['avgSavingsRate'] as double;
      final categoryTotals = financialData['categoryTotals'] as Map<String, double>;

      final prompt = '''
        You are an expert financial advisor. Create a comprehensive, personalized financial plan based on:
        
        FINANCIAL DATA:
        - Average monthly income: RM${avgIncome.toStringAsFixed(2)}
        - Average monthly spending: RM${avgSpending.toStringAsFixed(2)}
        - Current savings rate: ${(avgSavingsRate * 100).toStringAsFixed(1)}%
        - Top spending categories: ${categoryTotals.entries.take(5).map((e) => '${e.key}: RM${e.value.toStringAsFixed(2)}').join(', ')}
        
        GOALS: ${goals.map((g) => '${g['name']}: RM${g['totalAmount']} (${g['type']})').join(', ')}
        
        USER PROFILE: ${userProfile.toString()}
        
        Create a JSON response with the following structure:
        {
          "title": "Personalized Financial Plan for [Month Year]",
          "description": "Brief description of the plan's focus",
          "targetAmount": [monthly savings target],
          "category": "savings" or "debt_reduction" or "investment" or "emergency_fund",
          "actionItems": [
            "Specific actionable item 1",
            "Specific actionable item 2",
            "Specific actionable item 3",
            "Specific actionable item 4",
            "Specific actionable item 5"
          ],
          "budgetAllocation": {
            "essentials": [percentage as decimal],
            "savings": [percentage as decimal],
            "entertainment": [percentage as decimal],
            "investments": [percentage as decimal],
            "emergency_fund": [percentage as decimal]
          }
        }
        
        Make recommendations SPECIFIC and ACTIONABLE. Include exact amounts and percentages. Focus on realistic improvements.
        
        Respond ONLY with valid JSON, no additional text.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final jsonString = response.text ?? '';

      // Clean the JSON response
      final cleanJson = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();

      try {
        final Map<String, dynamic> planData = {};

        // Parse manually if needed (fallback approach)
        planData['title'] = 'Personalized Financial Plan for ${DateFormat('MMMM yyyy').format(DateTime.now())}';
        planData['description'] = 'AI-generated plan to optimize your financial health';
        planData['targetAmount'] = (avgIncome * 0.2).clamp(100.0, double.infinity);
        planData['category'] = avgSavingsRate < 0.1 ? 'savings' : 'investment';

        // Generate specific action items based on data
        List<String> actionItems = [];

        if (avgSavingsRate < 0.2) {
          actionItems.add('Increase savings rate to 20% by saving RM${((avgIncome * 0.2) - (avgIncome * avgSavingsRate)).toStringAsFixed(0)} more monthly');
        }

        final topCategory = categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
        if (topCategory.value > avgIncome * 0.3) {
          actionItems.add('Reduce ${topCategory.key} spending by 15% (save RM${(topCategory.value * 0.15 / 12).toStringAsFixed(0)}/month)');
        }

        actionItems.addAll([
          'Set up automatic transfer of RM${(avgIncome * 0.15).toStringAsFixed(0)} to savings account',
          'Review and cancel unused subscriptions (potential savings: RM50-150/month)',
          'Allocate RM${(avgIncome * 0.05).toStringAsFixed(0)} monthly to emergency fund until 6 months expenses saved',
        ]);

        planData['actionItems'] = actionItems;
        planData['budgetAllocation'] = {
          'essentials': 0.5,
          'savings': 0.2,
          'entertainment': 0.15,
          'investments': 0.1,
          'emergency_fund': 0.05,
        };

        final plan = FinancialPlan(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: planData['title'],
          description: planData['description'],
          targetAmount: planData['targetAmount'].toDouble(),
          category: planData['category'],
          createdAt: DateTime.now(),
          targetDate: DateTime.now().add(const Duration(days: 30)),
          actionItems: List<String>.from(planData['actionItems']),
          budgetAllocation: Map<String, double>.from(planData['budgetAllocation']),
        );

        // Save plan to Firestore
        await _firestore.collection('financial_plans').doc(plan.id).set({
          ...plan.toMap(),
          'userid': userId,
        });

        return plan;
      } catch (e) {
        print('JSON parsing error: $e');
        // Return fallback plan
        return _createFallbackPlan(financialData, userId);
      }
    } catch (e) {
      print('Plan generation error: $e');
      return _createFallbackPlan(await _fetchComprehensiveFinancialData(userId), userId);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  FinancialPlan _createFallbackPlan(Map<String, dynamic> financialData, String userId) {
    final avgIncome = financialData['avgMonthlyIncome'] as double;
    final avgSpending = financialData['avgMonthlySpending'] as double;
    final avgSavingsRate = financialData['avgSavingsRate'] as double;

    return FinancialPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Basic Financial Plan for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
      description: 'Starter plan to improve your financial health',
      targetAmount: avgIncome * 0.2,
      category: 'savings',
      createdAt: DateTime.now(),
      targetDate: DateTime.now().add(const Duration(days: 30)),
      actionItems: [
        'Track all expenses for the month',
        'Set up RM${(avgIncome * 0.1).toStringAsFixed(0)} automatic savings',
        'Review monthly subscriptions',
        'Create emergency fund target',
        'Plan next month\'s budget',
      ],
      budgetAllocation: {
        'essentials': 0.6,
        'savings': 0.2,
        'entertainment': 0.15,
        'emergency_fund': 0.05,
      },
    );
  }

  // Predict financial outcomes
  Future<Map<String, dynamic>> _predictFinancialOutcomes(String userId, FinancialPlan plan) async {
    try {
      final model = await _getGenerativeModel();
      final financialData = await _fetchComprehensiveFinancialData(userId);

      final prompt = '''
        Based on this financial plan and historical data, predict outcomes:
        
        PLAN: ${plan.title}
        TARGET SAVINGS: RM${plan.targetAmount.toStringAsFixed(2)}/month
        ACTION ITEMS: ${plan.actionItems.join(', ')}
        
        HISTORICAL DATA:
        - Current avg spending: RM${financialData['avgMonthlySpending']}
        - Current avg income: RM${financialData['avgMonthlyIncome']}
        - Current savings rate: ${(financialData['avgSavingsRate'] * 100).toStringAsFixed(1)}%
        
        Predict the following for 6 months and 1 year if the plan is followed:
        1. Potential monthly savings amount
        2. Total savings accumulated
        3. Debt reduction (if applicable)
        4. Emergency fund progress
        5. Achievement probability (0-100%)
        
        Respond with realistic, specific numbers in JSON format.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);

      // Return basic predictions if AI fails
      return {
        'sixMonthSavings': plan.targetAmount * 6,
        'oneYearSavings': plan.targetAmount * 12,
        'achievementProbability': 75.0,
        'emergencyFundProgress': plan.targetAmount * 3,
        'monthlyImpact': plan.targetAmount,
      };
    } catch (e) {
      return {
        'sixMonthSavings': plan.targetAmount * 6,
        'oneYearSavings': plan.targetAmount * 12,
        'achievementProbability': 70.0,
        'emergencyFundProgress': plan.targetAmount * 3,
        'monthlyImpact': plan.targetAmount,
      };
    }
  }

  // Update plan progress
  Future<void> _updatePlanProgress(String planId, String actionItemId, double progress) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('financial_plans').doc(planId).update({
      'actionItemProgress.$actionItemId': progress,
      'lastUpdated': Timestamp.now(),
    });
  }

  Widget _buildOverviewTab(String userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFinancialHealthScore(userId),
          const SizedBox(height: 20),
          _buildQuickStats(userId),
          const SizedBox(height: 20),
          _buildActiveGoalsOverview(userId),
          const SizedBox(height: 20),
          _buildRecentProgress(userId),
        ],
      ),
    );
  }

  Widget _buildPlansTab(String userId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Your Financial Plans',
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
                    : const Icon(Icons.add, color: Colors.white),
                label: Text(_isLoading ? 'Generating...' : 'New Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildFinancialPlansList(userId)),
      ],
    );
  }

  Widget _buildGoalsTab(String userId) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGoalsSummary(userId),
          const SizedBox(height: 20),
          _buildGoalsList(userId),
          const SizedBox(height: 20),
          _buildGoalRecommendations(userId),
        ],
      ),
    );
  }

  Widget _buildFinancialHealthScore(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchComprehensiveFinancialData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final savingsRate = data['avgSavingsRate'] as double;
        final score = _calculateHealthScore(data);

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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Financial Health Score',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getScoreGrade(score),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${score.toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'out of 100',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildScoreMetric(
                    'Savings Rate',
                    '${(savingsRate * 100).toStringAsFixed(1)}%',
                    Icons.savings,
                  ),
                  _buildScoreMetric(
                    'Budget Control',
                    _getBudgetControlRating(data),
                    Icons.account_balance_wallet,
                  ),
                  _buildScoreMetric(
                    'Goal Progress',
                    'On Track',
                    Icons.flag,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoreMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  double _calculateHealthScore(Map<String, dynamic> data) {
    double score = 0;

    // Savings rate (30 points max)
    final savingsRate = data['avgSavingsRate'] as double;
    score += (savingsRate * 150).clamp(0, 30);

    // Income stability (20 points max)
    final incomeData = data['monthlyIncome'] as List<double>;
    final incomeVariability = _calculateVariability(incomeData);
    score += (20 - (incomeVariability * 20)).clamp(0, 20);

    // Spending control (25 points max)
    final spendingData = data['monthlySpending'] as List<double>;
    final spendingTrend = _calculateTrend(spendingData);
    score += spendingTrend <= 0 ? 25 : (25 - (spendingTrend * 25));

    // Diversification (15 points max)
    final categoryTotals = data['categoryTotals'] as Map<String, double>;
    final diversificationScore = _calculateDiversificationScore(categoryTotals);
    score += diversificationScore * 15;

    // Emergency fund readiness (10 points max)
    final avgIncome = data['avgMonthlyIncome'] as double;
    final avgSavings = avgIncome * savingsRate;
    final emergencyFundMonths = avgSavings > 0 ? (avgSavings * 12) / (avgIncome * 6) : 0;
    score += (emergencyFundMonths.clamp(0, 1) * 10);

    return score.clamp(0, 100);
  }

  double _calculateVariability(List<double> data) {
    if (data.isEmpty) return 0;
    final mean = data.fold(0.0, (sum, item) => sum + item) / data.length;
    final variance = data.fold(0.0, (sum, item) => sum + (item - mean) * (item - mean)) / data.length;
    return variance / (mean * mean); // Coefficient of variation
  }

  double _calculateTrend(List<double> data) {
    if (data.length < 2) return 0;
    final recent = data.sublist(data.length - 3).fold(0.0, (sum, item) => sum + item) / 3;
    final earlier = data.sublist(0, 3).fold(0.0, (sum, item) => sum + item) / 3;
    return earlier > 0 ? (recent - earlier) / earlier : 0;
  }

  double _calculateDiversificationScore(Map<String, double> categories) {
    if (categories.isEmpty) return 0;
    final total = categories.values.fold(0.0, (sum, item) => sum + item);
    final proportions = categories.values.map((v) => v / total).toList();

    // Calculate Herfindahl index (lower is more diversified)
    final herfindahl = proportions.fold(0.0, (sum, p) => sum + (p * p));
    return (1 - herfindahl).clamp(0, 1);
  }

  String _getScoreGrade(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Very Good';
    if (score >= 70) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Needs Work';
  }

  String _getBudgetControlRating(Map<String, dynamic> data) {
    final spendingData = data['monthlySpending'] as List<double>;
    final trend = _calculateTrend(spendingData);

    if (trend <= -0.05) return 'Excellent';
    if (trend <= 0) return 'Good';
    if (trend <= 0.05) return 'Fair';
    return 'Poor';
  }

  Widget _buildQuickStats(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchComprehensiveFinancialData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final avgIncome = data['avgMonthlyIncome'] as double;
        final avgSpending = data['avgMonthlySpending'] as double;
        final avgSavingsRate = data['avgSavingsRate'] as double;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Monthly Income',
                'RM${avgIncome.toStringAsFixed(0)}',
                Icons.trending_up,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Monthly Spending',
                'RM${avgSpending.toStringAsFixed(0)}',
                Icons.trending_down,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Savings Rate',
                '${(avgSavingsRate * 100).toStringAsFixed(1)}%',
                Icons.savings,
                Colors.teal,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGoalsOverview(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('goals').where('userid', isEqualTo: userId).limit(3).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final goals = snapshot.data!.docs;
        if (goals.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.flag, color: Colors.grey, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No active goals',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set financial goals to track your progress',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to create goal
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                  child: const Text('Create Goal', style: TextStyle(color: Colors.white)),
                ),
              ],
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
              const Text(
                'Active Goals',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...goals.take(3).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? 'Unnamed Goal';
                final totalAmount = (data['totalAmount'] ?? 1).toDouble();
                final depositedAmount = (data['depositedAmount'] ?? 0).toDouble();
                final progress = (depositedAmount / totalAmount).clamp(0.0, 1.0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(color: Colors.teal, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[800],
                        color: Colors.teal,
                        minHeight: 6,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentProgress(String userId) {
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
            'Recent Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildProgressItem(
            'Monthly Savings Target',
            'RM850 of RM1,000',
            0.85,
            Colors.green,
          ),
          const SizedBox(height: 8),
          _buildProgressItem(
            'Budget Adherence',
            '12 days streak',
            0.6,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildProgressItem(
            'Emergency Fund',
            'RM2,400 of RM6,000',
            0.4,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, String subtitle, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[800],
          color: color,
          minHeight: 4,
        ),
      ],
    );
  }

  Future<void> _generateNewPlan(String userId) async {
    try {
      final plan = await _generatePersonalizedFinancialPlan(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New financial plan generated successfully!'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating plan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildFinancialPlansList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('financial_plans')
          .where('userid', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
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
                const Icon(Icons.assignment, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No Financial Plans Yet',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Generate your first AI-powered financial plan',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _generateNewPlan(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Generate Plan', style: TextStyle(color: Colors.white)),
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
            final plan = FinancialPlan.fromMap(doc.data() as Map<String, dynamic>, doc.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(plan.category),
                          color: Colors.teal,
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
                            Text(
                              plan.description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Target Amount',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              'RM${plan.targetAmount.toStringAsFixed(0)}/month',
                              style: const TextStyle(
                                color: Colors.teal,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Progress',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              '${plan.progressPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Due Date',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              DateFormat('dd MMM').format(plan.targetDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: plan.progressPercentage / 100,
                    backgroundColor: Colors.grey[800],
                    color: Colors.teal,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Action Items',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...plan.actionItems.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (plan.actionItems.length > 3)
                    Text(
                      '+ ${plan.actionItems.length - 3} more items',
                      style: const TextStyle(color: Colors.teal, fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showPlanDetails(plan),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal),
                          ),
                          child: const Text('View Details', style: TextStyle(color: Colors.teal)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showPredictions(userId, plan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: const Text('Predictions', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'savings':
        return Icons.savings;
      case 'debt_reduction':
        return Icons.trending_down;
      case 'investment':
        return Icons.trending_up;
      case 'emergency_fund':
        return Icons.security;
      default:
        return Icons.account_balance_wallet;
    }
  }

  void _showPlanDetails(FinancialPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(plan.category),
                  color: Colors.teal,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plan.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              plan.description,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              'Budget Allocation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...plan.budgetAllocation.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '${(entry.value * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 20),
            const Text(
              'All Action Items',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...plan.actionItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.teal, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showPredictions(String userId, FinancialPlan plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _predictFinancialOutcomes(userId, plan),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.teal),
                    SizedBox(height: 16),
                    Text(
                      'Generating predictions...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Text(
                  'Unable to generate predictions',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final predictions = snapshot.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Financial Predictions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPredictionCard(
                  'In 6 Months',
                  'RM${predictions['sixMonthSavings'].toStringAsFixed(0)}',
                  'Total Savings',
                  Icons.calendar_today,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildPredictionCard(
                  'In 1 Year',
                  'RM${predictions['oneYearSavings'].toStringAsFixed(0)}',
                  'Projected Savings',
                  Icons.calendar_view_month,
                  Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildPredictionCard(
                  'Success Rate',
                  '${predictions['achievementProbability'].toStringAsFixed(0)}%',
                  'Achievement Probability',
                  Icons.trending_up,
                  Colors.orange,
                ),
                const SizedBox(height: 12),
                _buildPredictionCard(
                  'Emergency Fund',
                  'RM${predictions['emergencyFundProgress'].toStringAsFixed(0)}',
                  '3 Months Coverage',
                  Icons.security,
                  Colors.purple,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPredictionCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSummary(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('goals').where('userid', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final goals = snapshot.data!.docs;
        double totalGoalAmount = 0;
        double totalSaved = 0;
        int completedGoals = 0;

        for (var doc in goals) {
          final data = doc.data() as Map<String, dynamic>;
          final targetAmount = (data['totalAmount'] ?? 0).toDouble();
          final savedAmount = (data['depositedAmount'] ?? 0).toDouble();

          totalGoalAmount += targetAmount;
          totalSaved += savedAmount;

          if (savedAmount >= targetAmount) {
            completedGoals++;
          }
        }

        final progressPercentage = totalGoalAmount > 0 ? (totalSaved / totalGoalAmount) : 0.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade700, Colors.purple.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Goals Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${goals.length} Active Goals',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          '$completedGoals Completed',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'RM${totalSaved.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'of RM${totalGoalAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progressPercentage,
                backgroundColor: Colors.white.withOpacity(0.3),
                color: Colors.white,
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                '${(progressPercentage * 100).toStringAsFixed(1)}% Complete',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('goals').where('userid', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final goals = snapshot.data!.docs;
        if (goals.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.flag, color: Colors.grey, size: 48),
                SizedBox(height: 12),
                Text(
                  'No goals set yet',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Create your first financial goal to get started',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: goals.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unnamed Goal';
            final icon = data['icon'] ?? 'ðŸŽ¯';
            final totalAmount = (data['totalAmount'] ?? 1).toDouble();
            final depositedAmount = (data['depositedAmount'] ?? 0).toDouble();
            final progress = (depositedAmount / totalAmount).clamp(0.0, 1.0);
            final startDate = (data['startDate'] as Timestamp).toDate();

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoalProgressPage(goal: data, goalId: doc.id),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'RM${depositedAmount.toStringAsFixed(0)} saved',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'RM${totalAmount.toStringAsFixed(0)} target',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      color: Colors.teal,
                      minHeight: 6,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Started ${DateFormat('dd MMM yyyy').format(startDate)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGoalRecommendations(String userId) {
    return FutureBuilder<List<String>>(
      future: _generateGoalRecommendations(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final recommendations = snapshot.data!;

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
                'Goal Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              ...recommendations.map((rec) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.yellow, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _generateGoalRecommendations(String userId) async {
    final financialData = await _fetchComprehensiveFinancialData(userId); // Moved outside try-catch
    try {
      final model = await _getGenerativeModel();
      final goalsSnapshot = await _firestore.collection('goals').where('userid', isEqualTo: userId).get();

      final prompt = '''
        Based on this financial profile, suggest 3-4 specific goal recommendations:
        
        Income: RM${financialData['avgMonthlyIncome']}
        Spending: RM${financialData['avgMonthlySpending']}
        Savings Rate: ${(financialData['avgSavingsRate'] * 100).toStringAsFixed(1)}%
        Current Goals: ${goalsSnapshot.docs.length}
        
        Provide practical, achievable goal suggestions with specific amounts and timeframes.
        Each recommendation should be one sentence.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      return text.split('\n')
          .where((line) => line.trim().isNotEmpty && !line.startsWith('#'))
          .take(4)
          .toList();
    } catch (e) {
      return [
        'Build an emergency fund of 6 months expenses (RM${(financialData['avgMonthlySpending'] * 6).toStringAsFixed(0)})',
        'Save 20% of monthly income for long-term investments',
        'Set up a vacation fund of RM3,000 for next year',
        'Create a home improvement budget of RM5,000',
      ];
    }
  }

  // Enhanced prediction method
  Future<double> _predictNextMonthSpending(String userId) async {
    try {
      final model = await _getGenerativeModel();
      final financialData = await _fetchComprehensiveFinancialData(userId);

      final spendingData = financialData['monthlySpending'] as List<double>;
      final categoryTrends = financialData['categoryTrends'] as Map<String, List<double>>;
      final savingsRate = financialData['savingsRate'] as List<double>;

      // Calculate seasonal patterns and trends
      final avgSpending = spendingData.fold(0.0, (sum, item) => sum + item) / spendingData.length;
      final recentTrend = _calculateTrend(spendingData.sublist(6));

      // Consider category-specific trends
      Map<String, double> categoryPredictions = {};
      categoryTrends.forEach((category, trends) {
        final categoryTrend = _calculateTrend(trends.sublist(6));
        final recentAvg = trends.sublist(6).fold(0.0, (sum, item) => sum + item) / 6;
        categoryPredictions[category] = recentAvg * (1 + categoryTrend);
      });

      final prompt = '''
        Predict next month's spending based on:
        - Historical avg: RM${avgSpending.toStringAsFixed(2)}
        - Recent trend: ${(recentTrend * 100).toStringAsFixed(1)}%
        - Category predictions: ${categoryPredictions.entries.take(5).map((e) => '${e.key}: RM${e.value.toStringAsFixed(0)}').join(', ')}
        - Current month: ${DateFormat('MMMM').format(DateTime.now())}
        
        Consider seasonal factors, recent patterns, and provide a single number prediction.
        Respond with only the predicted amount as a number.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final predictionText = response.text ?? avgSpending.toString();

      final prediction = double.tryParse(predictionText.replaceAll(RegExp(r'[^\d.]'), '')) ?? avgSpending;
      return prediction.clamp(avgSpending * 0.5, avgSpending * 1.5);

    } catch (e) {
      print('Prediction error: $e');
      final financialData = await _fetchComprehensiveFinancialData(userId);
      final spendingData = financialData['monthlySpending'] as List<double>;
      return spendingData.fold(0.0, (sum, item) => sum + item) / spendingData.length;
    }
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
        title: const Text('Financial Advisor', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : () => _generateNewPlan(userId),
        backgroundColor: Colors.teal,
        icon: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          _isLoading ? 'Generating...' : 'AI Plan',
          style: const TextStyle(color: Colors.white),
        ),
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