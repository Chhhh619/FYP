import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: FinancialPlanPage());
  }
}

class FinancialAdvice {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final List<String> recommendations;
  final Map<String, double> spendingInsights;
  final String aiAnalysis;
  final double monthlySavingsTarget;
  final Map<String, String> categoryAdvice;

  FinancialAdvice({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.recommendations,
    required this.spendingInsights,
    required this.aiAnalysis,
    required this.monthlySavingsTarget,
    required this.categoryAdvice,
  });

  factory FinancialAdvice.fromMap(Map<String, dynamic> data, String id) {
    return FinancialAdvice(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      recommendations: List<String>.from(data['recommendations'] ?? []),
      spendingInsights: Map<String, double>.from(
        data['spendingInsights'] ?? {},
      ),
      aiAnalysis: data['aiAnalysis'] ?? '',
      monthlySavingsTarget: (data['monthlySavingsTarget'] ?? 0.0).toDouble(),
      categoryAdvice: Map<String, String>.from(data['categoryAdvice'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'recommendations': recommendations,
      'spendingInsights': spendingInsights,
      'aiAnalysis': aiAnalysis,
      'monthlySavingsTarget': monthlySavingsTarget,
      'categoryAdvice': categoryAdvice,
    };
  }
}

class FinancialPlanPage extends StatefulWidget {
  const FinancialPlanPage({super.key});

  @override
  _FinancialPlanPageState createState() => _FinancialPlanPageState();
}

class _FinancialPlanPageState extends State<FinancialPlanPage>
    with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  GenerativeModel? _model;
  TabController? _tabController;
  bool _isLoading = false;
  bool _isGeneratingAdvice = false;
  int _selectedIndex = 2;
  final ScrollController _scrollController = ScrollController();

  static const String _apiKey = 'AIzaSyAo8tGXkOuvO6ZmJkZJu1bzpgoGnUWxqnk';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<GenerativeModel> _getGenerativeModel() async {
    if (_model == null) {
      _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
    }
    return _model!;
  }

  Future<Map<String, dynamic>> _fetchFinancialData(String userId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final endOfLastMonth = DateTime(now.year, now.month, 1);
      final last3Months = DateTime(now.year, now.month - 3, 1);

      // Fetch current month transactions
      final currentMonthSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      // Fetch last month transactions
      final lastMonthSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfLastMonth))
          .get();

      // Fetch last 3 months for trend analysis
      final last3MonthsSnapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(last3Months),
          )
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      double currentIncome = 0, currentExpenses = 0;
      double lastMonthIncome = 0, lastMonthExpenses = 0;
      Map<String, double> categorySpending = {};
      Map<String, int> transactionCounts = {};
      Map<String, double> monthlyTrends = {};
      List<Map<String, dynamic>> recentTransactions = [];

      // Process current month
      for (var doc in currentMonthSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final type = data['type'] ?? '';
        final timestamp = (data['timestamp'] as Timestamp).toDate();

        if (type == 'income') {
          currentIncome += amount;
        } else if (type == 'expense') {
          currentExpenses += amount;

          final categoryRef = data['category'] as DocumentReference?;
          if (categoryRef != null) {
            try {
              final categoryDoc = await categoryRef.get();
              if (categoryDoc.exists) {
                final categoryName =
                    (categoryDoc.data() as Map<String, dynamic>)?['name'] ??
                    'Other';
                categorySpending[categoryName] =
                    (categorySpending[categoryName] ?? 0) + amount;
                transactionCounts[categoryName] =
                    (transactionCounts[categoryName] ?? 0) + 1;
              }
            } catch (e) {
              categorySpending['Other'] =
                  (categorySpending['Other'] ?? 0) + amount;
            }
          }
        }

        recentTransactions.add({
          'amount': amount,
          'type': type,
          'timestamp': timestamp,
          'category': data['category'],
        });
      }

      // Process last month
      for (var doc in lastMonthSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final type = data['type'] ?? '';

        if (type == 'income') {
          lastMonthIncome += amount;
        } else if (type == 'expense') {
          lastMonthExpenses += amount;
        }
      }

      // Process 3-month trend
      Map<String, double> monthlyExpensesByMonth = {};
      for (var doc in last3MonthsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final type = data['type'] ?? '';
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final monthKey = DateFormat('yyyy-MM').format(timestamp);

        if (type == 'expense') {
          monthlyExpensesByMonth[monthKey] =
              (monthlyExpensesByMonth[monthKey] ?? 0) + amount;
        }
      }

      // Sort recent transactions by date
      recentTransactions.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );
      recentTransactions = recentTransactions.take(20).toList();

      final savingsRate = currentIncome > 0
          ? ((currentIncome - currentExpenses) / currentIncome)
          : 0.0;
      final spendingTrend = currentExpenses - lastMonthExpenses;

      return {
        'currentIncome': currentIncome,
        'currentExpenses': currentExpenses,
        'lastMonthIncome': lastMonthIncome,
        'lastMonthExpenses': lastMonthExpenses,
        'savingsRate': savingsRate,
        'categorySpending': categorySpending,
        'transactionCounts': transactionCounts,
        'spendingTrend': spendingTrend,
        'monthlySavings': currentIncome - currentExpenses,
        'recentTransactions': recentTransactions,
        'monthlyTrends': monthlyExpensesByMonth,
        'averageDailySpending': currentExpenses / DateTime.now().day,
      };
    } catch (e) {
      print('Error fetching financial data: $e');
      return {
        'currentIncome': 0.0,
        'currentExpenses': 0.0,
        'lastMonthIncome': 0.0,
        'lastMonthExpenses': 0.0,
        'savingsRate': 0.0,
        'categorySpending': <String, double>{},
        'transactionCounts': <String, int>{},
        'spendingTrend': 0.0,
        'monthlySavings': 0.0,
        'recentTransactions': [],
        'monthlyTrends': <String, double>{},
        'averageDailySpending': 0.0,
      };
    }
  }

  Future<FinancialAdvice> _generateFinancialAdvice(String userId) async {
    setState(() => _isGeneratingAdvice = true);

    try {
      final model = await _getGenerativeModel();
      final financialData = await _fetchFinancialData(userId);

      final currentIncome = financialData['currentIncome'] as double;
      final currentExpenses = financialData['currentExpenses'] as double;
      final savingsRate = financialData['savingsRate'] as double;
      final categorySpending =
          financialData['categorySpending'] as Map<String, double>;
      final spendingTrend = financialData['spendingTrend'] as double;
      final monthlySavings = financialData['monthlySavings'] as double;
      final averageDailySpending =
          financialData['averageDailySpending'] as double;
      final transactionCounts =
          financialData['transactionCounts'] as Map<String, int>;


      final prompt =
          '''
      You are a professional financial advisor analyzing a user's spending patterns. Provide personalized financial advice based on their actual transaction data.

      CURRENT FINANCIAL SNAPSHOT:
      - Monthly Income: RM${currentIncome.toStringAsFixed(2)}
      - Monthly Expenses: RM${currentExpenses.toStringAsFixed(2)}
      - Net Savings: RM${monthlySavings.toStringAsFixed(2)}
      - Savings Rate: ${(savingsRate * 100).toStringAsFixed(1)}%
      - Average Daily Spending: RM${averageDailySpending.toStringAsFixed(2)}
      - Spending Trend: ${spendingTrend > 0 ? 'Increased by RM${spendingTrend.abs().toStringAsFixed(2)}' : 'Decreased by RM${spendingTrend.abs().toStringAsFixed(2)}'} vs last month

      DETAILED SPENDING BREAKDOWN:
      ${categorySpending.entries.map((e) => '- ${e.key}: RM${e.value.toStringAsFixed(2)} (${transactionCounts[e.key] ?? 0} transactions)').join('\n')}

      MALAYSIAN CONTEXT:
      - Consider local cost of living and salary standards
      - Factor in EPF contributions and Malaysian savings culture
      - Include Malaysian-specific financial products (ASB, unit trusts, etc.)
      - Consider seasonal factors (CNY, Raya, school holidays)

      PROVIDE A COMPREHENSIVE ANALYSIS INCLUDING:
      1. Overall financial health assessment with Malaysian benchmarks
      2. Top 3 areas for improvement with specific RM amounts to cut
      3. Realistic monthly savings target considering Malaysian living costs
      4. Category-specific advice for the biggest spending areas
      5. Emergency fund recommendations (3-6 months expenses)
      6. Investment suggestions appropriate for Malaysian market

      FORMAT YOUR RESPONSE EXACTLY AS FOLLOWS:

      ANALYSIS: [Your detailed analysis incorporating Malaysian financial context - 3-4 sentences]

      SAVINGS_TARGET: [Specific monthly savings amount in RM, just the number]

      RECOMMENDATION_1: [Specific actionable advice with RM amounts and Malaysian context]
      RECOMMENDATION_2: [Specific actionable advice with RM amounts and local relevance]  
      RECOMMENDATION_3: [Specific actionable advice with RM amounts]
      RECOMMENDATION_4: [Malaysian-specific savings/investment advice]
      RECOMMENDATION_5: [Long-term financial planning advice for Malaysia]

      EMERGENCY_FUND: [Recommended emergency fund target in RM]

      CATEGORY_ADVICE_START:
      ${categorySpending.entries.take(4).map((e) => '${e.key}: [Specific advice with Malaysian context for this category]').join('\n')}
      CATEGORY_ADVICE_END:

      INVESTMENT_IDEAS: [2-3 Malaysian investment options suitable for their income level]

      Be specific with amounts and percentages. Focus on practical, culturally relevant advice for Malaysian users.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final aiResponse = response.text ?? '';

      // Parse AI response
      final lines = aiResponse
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      String analysis = '';
      double savingsTarget = currentIncome * 0.15;
      List<String> recommendations = [];
      Map<String, String> categoryAdvice = {};

      bool inCategoryAdvice = false;

      for (var line in lines) {
        if (line.startsWith('ANALYSIS:')) {
          analysis = line.split('ANALYSIS:').last.trim();
        } else if (line.startsWith('SAVINGS_TARGET:')) {
          final targetStr = line.split('SAVINGS_TARGET:').last.trim();
          final match = RegExp(r'[\d,]+\.?\d*').firstMatch(targetStr);
          if (match != null) {
            savingsTarget =
                double.tryParse(match.group(0)!.replaceAll(',', '')) ??
                savingsTarget;
          }
        } else if (line.startsWith('RECOMMENDATION_')) {
          recommendations.add(line.split(':').last.trim());
        } else if (line.contains('CATEGORY_ADVICE_START:')) {
          inCategoryAdvice = true;
        } else if (line.contains('CATEGORY_ADVICE_END:')) {
          inCategoryAdvice = false;
        } else if (inCategoryAdvice && line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            categoryAdvice[parts[0].trim()] = parts.sublist(1).join(':').trim();
          }
        }
      }

      // Ensure we have fallback recommendations
      if (recommendations.isEmpty) {
        recommendations = _generateFallbackRecommendations(
          categorySpending,
          currentIncome,
        );
      }

      // Ensure we have fallback analysis
      if (analysis.isEmpty) {
        analysis = _generateFallbackAnalysis(
          savingsRate,
          spendingTrend,
          categorySpending,
        );
      }

      final advice = FinancialAdvice(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title:
            'AI Financial Analysis - ${DateFormat('MMM yyyy').format(DateTime.now())}',
        description:
            'Personalized financial advice based on your spending patterns',
        createdAt: DateTime.now(),
        recommendations: recommendations.take(5).toList(),
        spendingInsights: categorySpending,
        aiAnalysis: analysis,
        monthlySavingsTarget: savingsTarget,
        categoryAdvice: categoryAdvice,
      );

      // Save to Firestore
      await _firestore.collection('financial_advice').doc(advice.id).set({
        ...advice.toMap(),
        'userId': userId,
      });

      return advice;
    } catch (e) {
      print('Error generating advice: $e');
      return _createFallbackAdvice(userId);
    } finally {
      setState(() => _isGeneratingAdvice = false);
    }
  }

  // Add this method to your _FinancialPlanPageState class

  Future<void> _refreshLatestAdvice(String userId) async {
    setState(() => _isGeneratingAdvice = true);

    try {
      // Get the latest advice document
      final latestAdviceSnapshot = await _firestore
          .collection('financial_advice')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (latestAdviceSnapshot.docs.isEmpty) {
        // No existing advice, create new one
        await _generateNewAdvice(userId);
        return;
      }

      // Get the latest advice document ID
      final latestAdviceDoc = latestAdviceSnapshot.docs.first;
      final adviceId = latestAdviceDoc.id;

      // Generate fresh analysis with current data
      final model = await _getGenerativeModel();
      final financialData = await _fetchFinancialData(userId);

      final currentIncome = financialData['currentIncome'] as double;
      final currentExpenses = financialData['currentExpenses'] as double;
      final savingsRate = financialData['savingsRate'] as double;
      final categorySpending = financialData['categorySpending'] as Map<String, double>;
      final spendingTrend = financialData['spendingTrend'] as double;
      final monthlySavings = financialData['monthlySavings'] as double;
      final averageDailySpending = financialData['averageDailySpending'] as double;
      final transactionCounts = financialData['transactionCounts'] as Map<String, int>;

      // Create the same detailed prompt
      final prompt = '''
      You are a professional financial advisor analyzing UPDATED spending patterns. Provide refreshed financial advice based on the latest transaction data.

      CURRENT FINANCIAL SNAPSHOT (UPDATED):
      - Monthly Income: RM${currentIncome.toStringAsFixed(2)}
      - Monthly Expenses: RM${currentExpenses.toStringAsFixed(2)}
      - Net Savings: RM${monthlySavings.toStringAsFixed(2)}
      - Savings Rate: ${(savingsRate * 100).toStringAsFixed(1)}%
      - Average Daily Spending: RM${averageDailySpending.toStringAsFixed(2)}
      - Spending Trend: ${spendingTrend > 0 ? 'Increased by RM${spendingTrend.abs().toStringAsFixed(2)}' : 'Decreased by RM${spendingTrend.abs().toStringAsFixed(2)}'} vs last month

      DETAILED SPENDING BREAKDOWN:
      ${categorySpending.entries.map((e) => '- ${e.key}: RM${e.value.toStringAsFixed(2)} (${transactionCounts[e.key] ?? 0} transactions)').join('\n')}

      [Rest of your existing prompt...]
    ''';

      final response = await model.generateContent([Content.text(prompt)]);
      final aiResponse = response.text ?? '';

      // Parse the response (same parsing logic)
      final lines = aiResponse.split('\n').where((line) => line.trim().isNotEmpty).toList();
      String analysis = '';
      double savingsTarget = currentIncome * 0.15;
      List<String> recommendations = [];
      Map<String, String> categoryAdvice = {};

      // [Your existing parsing logic here...]
      bool inCategoryAdvice = false;
      for (var line in lines) {
        if (line.startsWith('ANALYSIS:')) {
          analysis = line.split('ANALYSIS:').last.trim();
        } else if (line.startsWith('SAVINGS_TARGET:')) {
          final targetStr = line.split('SAVINGS_TARGET:').last.trim();
          final match = RegExp(r'[\d,]+\.?\d*').firstMatch(targetStr);
          if (match != null) {
            savingsTarget = double.tryParse(match.group(0)!.replaceAll(',', '')) ?? savingsTarget;
          }
        } else if (line.startsWith('RECOMMENDATION_')) {
          recommendations.add(line.split(':').last.trim());
        } else if (line.contains('CATEGORY_ADVICE_START:')) {
          inCategoryAdvice = true;
        } else if (line.contains('CATEGORY_ADVICE_END:')) {
          inCategoryAdvice = false;
        } else if (inCategoryAdvice && line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            categoryAdvice[parts[0].trim()] = parts.sublist(1).join(':').trim();
          }
        }
      }

      // Ensure we have fallback recommendations
      if (recommendations.isEmpty) {
        recommendations = _generateFallbackRecommendations(categorySpending, currentIncome);
      }

      if (analysis.isEmpty) {
        analysis = _generateFallbackAnalysis(savingsRate, spendingTrend, categorySpending);
      }

      // UPDATE the existing document instead of creating new one
      await _firestore.collection('financial_advice').doc(adviceId).update({
        'title': 'AI Financial Analysis - ${DateFormat('MMM yyyy').format(DateTime.now())} (Refreshed)',
        'description': 'Updated analysis based on latest transactions',
        'updatedAt': Timestamp.fromDate(DateTime.now()), // Add update timestamp
        'recommendations': recommendations.take(5).toList(),
        'spendingInsights': categorySpending,
        'aiAnalysis': analysis,
        'monthlySavingsTarget': savingsTarget,
        'categoryAdvice': categoryAdvice,
        'isRefreshed': true, // Mark as refreshed
        'lastRefreshedAt': Timestamp.fromDate(DateTime.now()),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Analysis refreshed with latest data! 🔄'),
          backgroundColor: Colors.teal,
        ),
      );

    } catch (e) {
      print('Error refreshing advice: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to refresh analysis: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingAdvice = false);
    }
  }

  List<String> _generateFallbackRecommendations(
    Map<String, double> categorySpending,
    double income,
  ) {
    List<String> recommendations = [];

    if (categorySpending.isNotEmpty) {
      var sortedSpending = categorySpending.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topCategory = sortedSpending.first;
      final reduction = (topCategory.value * 0.15).toStringAsFixed(0);
      recommendations.add(
        'Reduce ${topCategory.key} spending by RM$reduction (15% reduction)',
      );

      if (sortedSpending.length > 1) {
        final secondCategory = sortedSpending[1];
        recommendations.add(
          'Review ${secondCategory.key} expenses for potential RM50-100 savings',
        );
      }
    }

    recommendations.addAll([
      'Set up automatic savings of RM${(income * 0.1).toStringAsFixed(0)} monthly',
      'Track daily expenses using the spending limit of RM${(income * 0.03).toStringAsFixed(0)}',
      'Review and cancel unused subscriptions to save RM50-150/month',
    ]);

    return recommendations;
  }

  String _generateFallbackAnalysis(
    double savingsRate,
    double spendingTrend,
    Map<String, double> categorySpending,
  ) {
    String trendText = spendingTrend > 0 ? 'increased' : 'decreased';
    String savingsAssessment = savingsRate > 0.2
        ? 'excellent'
        : (savingsRate > 0.1 ? 'good' : 'needs improvement');

    return 'Your savings rate of ${(savingsRate * 100).toStringAsFixed(1)}% is $savingsAssessment. '
        'Your spending has $trendText compared to last month. '
        'Focus on optimizing your largest expense categories for better financial health.';
  }

  FinancialAdvice _createFallbackAdvice(String userId) {
    return FinancialAdvice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Basic Financial Advice',
      description: 'Start tracking your expenses for personalized advice',
      createdAt: DateTime.now(),
      recommendations: [
        'Track all your expenses for better insights',
        'Aim to save at least 20% of your income',
        'Review your subscriptions monthly',
        'Set a daily spending limit',
        'Build an emergency fund gradually',
      ],
      spendingInsights: {},
      aiAnalysis:
          'Start recording your transactions to get personalized financial advice based on your spending patterns.',
      monthlySavingsTarget: 500.0,
      categoryAdvice: {},
    );
  }

  Widget _buildOverviewTab(String userId) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFinancialSummary(userId),
          const SizedBox(height: 20),
          _buildSpendingBreakdown(userId),
          const SizedBox(height: 20),
          _buildQuickActions(userId),
          const SizedBox(height: 20),
          _buildLatestAdvice(userId),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchFinancialData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final income = data['currentIncome'] as double;
        final expenses = data['currentExpenses'] as double;
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
                'This Month\'s Summary',
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
                  _buildSummaryItem(
                    'Income',
                    'RM${income.toStringAsFixed(0)}',
                    Icons.arrow_upward,
                  ),
                  _buildSummaryItem(
                    'Expenses',
                    'RM${expenses.toStringAsFixed(0)}',
                    Icons.arrow_downward,
                  ),
                  _buildSummaryItem(
                    'Savings',
                    'RM${savings.toStringAsFixed(0)}',
                    Icons.savings,
                  ),
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

  Widget _buildSummaryItem(String label, String value, IconData icon) {
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
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSpendingBreakdown(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchFinancialData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categorySpending =
            snapshot.data!['categorySpending'] as Map<String, double>;

        if (categorySpending.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No spending data available.\nStart recording transactions to see insights.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        var sortedSpending = categorySpending.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Spending Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...sortedSpending.take(5).map((entry) {
                final total = categorySpending.values.fold(
                  0.0,
                  (sum, amount) => sum + amount,
                );
                final percentage = total > 0 ? (entry.value / total) : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'RM${entry.value.toStringAsFixed(0)} (${(percentage * 100).toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey[800],
                        color: Colors.teal,
                        minHeight: 4,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(String userId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                'New Advice',
                Icons.auto_awesome,
                Colors.purple,
                    () => _generateNewAdvice(userId),
              ),
              _buildActionButton(
                'Refresh',
                Icons.refresh,
                Colors.teal,
                    () => _refreshLatestAdvice(userId),
              ),
              _buildActionButton(
                'History',
                Icons.history,
                Colors.blue,
                    () {
                  _tabController?.animateTo(1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLatestAdvice(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('financial_advice')
          .where('userId', isEqualTo: userId)
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
            child: Column(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.grey,
                  size: 40,
                ),
                const SizedBox(height: 8),
                const Text(
                  'No AI advice yet',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _generateNewAdvice(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                  ),
                  child: const Text(
                    'Get AI Advice',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }

        final adviceDoc = snapshot.data!.docs.first;
        final adviceData = adviceDoc.data() as Map<String, dynamic>;
        final advice = FinancialAdvice.fromMap(adviceData, adviceDoc.id);

        // Check if advice was refreshed
        final isRefreshed = adviceData['isRefreshed'] ?? false;
        final lastRefreshedAt = adviceData['lastRefreshedAt'] as Timestamp?;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
          children: [
          const Icon(
          Icons.auto_awesome,
            color: Colors.purple,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest AI Advice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isRefreshed && lastRefreshedAt != null)
                  Text(
                    'Refreshed ${_getTimeAgo(lastRefreshedAt.toDate())}',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          // Refresh button
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: _isGeneratingAdvice
                  ? null
                  : () => _refreshLatestAdvice(userId),
              icon: _isGeneratingAdvice
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.purple,
                ),
              )
                  : const Icon(
                Icons.refresh,
                color: Colors.purple,
                size: 18,
              ),
              tooltip: 'Refresh analysis with latest data',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getTimeAgo(advice.createdAt),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          ],
        ),
        const SizedBox(height: 12),

        // AI Analysis Section
        Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
        advice.aiAnalysis,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        ),
        ),
        const SizedBox(height: 12),

        // Savings Target Row
        Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
        children: [
        const Icon(Icons.savings, color: Colors.teal, size: 16),
        const SizedBox(width: 8),
        Text(
        'Savings Target: RM${advice.monthlySavingsTarget.toStringAsFixed(0)}/month',
        style: const TextStyle(
        color: Colors.teal,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        ),
        ),
        ],
        ),
        ),
        const SizedBox(height: 12),

        // Top Recommendations Section
        Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
        'Top Recommendations:',
        style: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        ),
        ),
              const SizedBox(height: 4),
              ...advice.recommendations
                  .take(2)
                  .map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Expanded(
                            child: Text(
                              rec,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _tabController?.animateTo(1),
                child: const Text(
                  'View Full Analysis →',
                  style: TextStyle(color: Colors.purple, fontSize: 12),
                ),
              ),
            ],
          ),
        ]));
      },
    );
  }

  Widget _buildAdviceTab(String userId) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'AI Financial Advice',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              // Refresh button
              IconButton(
                onPressed: _isGeneratingAdvice
                    ? null
                    : () => _refreshLatestAdvice(userId),
                icon: _isGeneratingAdvice
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.refresh, color: Colors.teal),
                tooltip: 'Refresh Latest',
              ),
              const SizedBox(width: 8),
              // Existing New Analysis button
              ElevatedButton.icon(
                onPressed: _isGeneratingAdvice
                    ? null
                    : () => _generateNewAdvice(userId),
                icon: _isGeneratingAdvice
                    ? const SizedBox(
                  width: 22,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.auto_awesome, color: Colors.white, size: 12),
                label: Text(_isGeneratingAdvice ? 'Analyzing...' : 'New Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildAdviceList(userId)),
      ],
    );
  }

  Widget _buildAdviceList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('financial_advice')
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
                      const Icon(
                        Icons.psychology,
                        color: Colors.purple,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No AI Analysis Yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Get personalized financial advice based on your spending patterns',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _generateNewAdvice(userId),
                        icon: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                        ),
                        label: const Text('Get AI Advice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final adviceList = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: adviceList.length,
          itemBuilder: (context, index) {
            final doc = adviceList[index];
            final advice = FinancialAdvice.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.psychology,
                            color: Colors.purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                advice.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Generated ${_getTimeAgo(advice.createdAt)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white54,
                          ),
                          color: Colors.grey[850],
                          onSelected: (value) {
                            if (value == 'delete') {
                              _confirmDeleteAdvice(advice);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // AI Analysis
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.purple,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Analysis',
                                style: TextStyle(
                                  color: Colors.purple,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            advice.aiAnalysis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Savings Target
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.savings, color: Colors.teal),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended Monthly Savings',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                'RM${advice.monthlySavingsTarget.toStringAsFixed(0)}',
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
                  ),

                  const SizedBox(height: 16),

                  // Recommendations
                  if (advice.recommendations.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Recommendations',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...advice.recommendations.asMap().entries.map(
                            (entry) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.purple,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
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
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Category Advice
                  if (advice.categoryAdvice.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category-Specific Advice',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...advice.categoryAdvice.entries.map(
                            (entry) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[850],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    entry.value,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<String, double> spendingData,
  ) {
    final total = spendingData.values.fold(0.0, (sum, amount) => sum + amount);
    final colors = [
      Colors.teal,
      Colors.purple,
      Colors.orange,
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.pink,
    ];

    return spendingData.entries.take(7).map((entry) {
      final index = spendingData.keys.toList().indexOf(entry.key);
      final percentage = total > 0 ? (entry.value / total * 100) : 0.0;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: 60,
      );
    }).toList();
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  Future<void> _generateNewAdvice(String userId) async {
    try {
      await _generateFinancialAdvice(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your AI financial analysis is ready! 🎉'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate advice: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteAdvice(FinancialAdvice advice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Advice?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this financial advice?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAdvice(advice);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAdvice(FinancialAdvice advice) async {
    try {
      await _firestore.collection('financial_advice').doc(advice.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Financial advice deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete advice: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
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
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AI Financial Advisor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Smart insights from your spending',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: const Color.fromRGBO(28, 28, 28, 1),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'AI Advice'),
              ],
              labelColor: Colors.purple,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.purple,
              indicatorWeight: 3,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildOverviewTab(userId), _buildAdviceTab(userId)],
            ),
          ),
        ],
      ),
      floatingActionButton: PersistentAddButton(
        scrollController: _scrollController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _handleNavigation,
      ),
    );
  }
}
