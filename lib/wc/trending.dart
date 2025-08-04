import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fyp/bottom_nav_bar.dart';

class TrendingPage extends StatefulWidget {
  const TrendingPage({super.key});

  @override
  _TrendingPageState createState() => _TrendingPageState();
}

class _TrendingPageState extends State<TrendingPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  int _selectedIndex = 1;
  DateTime _selectedMonth = DateTime.now();

  Future<Map<String, dynamic>> _fetchMonthlyData(String userId, DateTime month) async {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);

    final snapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('timestamp', isLessThan: Timestamp.fromDate(monthEnd))
        .get();

    double totalExpenses = 0.0;
    double totalIncome = 0.0;
    int transactionCount = 0;
    Map<String, double> categoryTotals = {};
    List<double> dailyExpenses = List.filled(DateTime(month.year, month.month + 1, 0).day, 0.0);

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final timestamp = data['timestamp'] as Timestamp?;
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

      transactionCount++;

      if (transactionType == 'expense') {
        totalExpenses += amount.abs();

        // Add to daily expenses for chart
        if (timestamp != null) {
          final day = timestamp.toDate().day - 1;
          if (day >= 0 && day < dailyExpenses.length) {
            dailyExpenses[day] += amount.abs();
          }
        }

        // Get category name for breakdown
        if (categoryRef != null) {
          try {
            final categoryDoc = await categoryRef.get();
            if (categoryDoc.exists) {
              final categoryData = categoryDoc.data() as Map<String, dynamic>?;
              final categoryName = categoryData?['name'] ?? 'Unknown';
              categoryTotals[categoryName] = (categoryTotals[categoryName] ?? 0.0) + amount.abs();
            }
          } catch (e) {
            print('Error fetching category data: $e');
          }
        }
      } else if (transactionType == 'income') {
        totalIncome += amount.abs();
      }
    }

    return {
      'totalExpenses': totalExpenses,
      'totalIncome': totalIncome,
      'balance': totalIncome - totalExpenses,
      'transactionCount': transactionCount,
      'categoryTotals': categoryTotals,
      'dailyExpenses': dailyExpenses,
    };
  }

  Future<Map<String, dynamic>> _fetchComparisonData(String userId) async {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
    final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);

    // Get current month data
    final currentData = await _fetchMonthlyData(userId, currentMonth);

    // Get last month data
    final lastMonthData = await _fetchMonthlyData(userId, lastMonth);

    // Get average for last 3 months
    double threeMonthTotal = 0.0;
    for (int i = 1; i <= 3; i++) {
      final monthData = await _fetchMonthlyData(userId, DateTime(now.year, now.month - i, 1));
      threeMonthTotal += monthData['totalExpenses'] as double;
    }

    // Get average for last 6 months
    double sixMonthTotal = 0.0;
    for (int i = 1; i <= 6; i++) {
      final monthData = await _fetchMonthlyData(userId, DateTime(now.year, now.month - i, 1));
      sixMonthTotal += monthData['totalExpenses'] as double;
    }

    return {
      'current': currentData,
      'lastMonth': lastMonthData,
      'threeMonthAvg': threeMonthTotal / 3,
      'sixMonthAvg': sixMonthTotal / 6,
      'dailyAvgCurrent': (currentData['totalExpenses'] as double) / now.day,
      'dailyAvgLast': (lastMonthData['totalExpenses'] as double) / DateTime(lastMonth.year, lastMonth.month + 1, 0).day,
    };
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1C),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Trending',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          backgroundColor: Colors.black,
        ),
        body: const Center(
          child: Text(
            'Please log in to access Trending',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            _handleNavigation(index);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              DateFormat('MMM').format(_selectedMonth),
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Summary',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchComparisonData(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!;
            final currentData = data['current'] as Map<String, dynamic>;
            final lastMonthData = data['lastMonth'] as Map<String, dynamic>;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(currentData),
                const SizedBox(height: 20),
                _buildComparisonCard('Compared to last month',
                    currentData['totalExpenses'] as double,
                    lastMonthData['totalExpenses'] as double),
                const SizedBox(height: 20),
                _buildComparisonCard('Compared with the daily average of the last month',
                    data['dailyAvgCurrent'] as double,
                    data['dailyAvgLast'] as double),
                const SizedBox(height: 20),
                _buildComparisonCard('Compared to the past three months',
                    currentData['totalExpenses'] as double,
                    data['threeMonthAvg'] as double,
                    showAverage: true),
                const SizedBox(height: 20),
                _buildComparisonCard('Compared to the past six months',
                    currentData['totalExpenses'] as double,
                    data['sixMonthAvg'] as double,
                    showAverage: true),
                const SizedBox(height: 20),
                _buildExpenseDistribution(currentData['categoryTotals'] as Map<String, double>),
                const SizedBox(height: 20),
                _buildExpenseChart(currentData['dailyExpenses'] as List<double>),
                const SizedBox(height: 20),
                _buildAIPredictions(userId, currentData),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          _handleNavigation(index);
        },
      ),
    );
  }

  Widget _buildOverviewCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('MMM').format(_selectedMonth)} Overview',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expenses',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM${(data['totalExpenses'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
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
                      'Income',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM${(data['totalIncome'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RM${(data['balance'] as double).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: (data['balance'] as double) >= 0 ? Colors.green : Colors.red,
                        fontSize: 24,
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
                      'Times',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data['transactionCount']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(String title, double current, double comparison, {bool showAverage = false}) {
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white54,
                  ),
                ),
              ),
              const Icon(Icons.more_vert, color: Colors.white54, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Current Expenses',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'RM${current.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showAverage ? 'AVG Expenses' : 'Last Expenses',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                Text(
                  'RM${comparison.toStringAsFixed(2)}',
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
    );
  }

  Widget _buildExpenseDistribution(Map<String, double> categoryTotals) {
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = categoryTotals.values.fold(0.0, (sum, item) => sum + item);

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
                'Expenses distribution',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                ),
              ),
              const Icon(Icons.more_vert, color: Colors.white54, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedCategories.take(4).map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _getCategoryIcon(entry.key),
                        color: _getCategoryColor(entry.key),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${entry.key} ${percentage.toStringAsFixed(2)}%',
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                Text(
                                  'RM${entry.value.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[700],
                              valueColor: AlwaysStoppedAnimation<Color>(_getCategoryColor(entry.key)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpenseChart(List<double> dailyExpenses) {
    // Find max expense for scaling
    double maxExpense = dailyExpenses.isEmpty ? 100 : dailyExpenses.reduce((a, b) => a > b ? a : b);
    if (maxExpense == 0) maxExpense = 100;

    // Calculate average
    double avgExpense = dailyExpenses.isEmpty ? 0 : dailyExpenses.fold(0.0, (sum, item) => sum + item) / dailyExpenses.length;

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
                'Expenses details',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white54,
                ),
              ),
              const Icon(Icons.more_vert, color: Colors.white54, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          // Show current day highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${DateTime.now().day} ${DateFormat('MMM').format(DateTime.now())}    RM${dailyExpenses.isNotEmpty && DateTime.now().day - 1 < dailyExpenses.length ? dailyExpenses[DateTime.now().day - 1].toStringAsFixed(0) : '0'}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(dailyExpenses.length, (index) {
                final expense = dailyExpenses[index];
                final height = maxExpense > 0 ? (expense / maxExpense * 100).clamp(1.0, 100.0) : 1.0;
                final isToday = index == DateTime.now().day - 1;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 4,
                      height: height,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.white : Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (index % 7 == 0) // Show date every 7 days
                      Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          // Date labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${DateFormat('d MMM').format(DateTime(_selectedMonth.year, _selectedMonth.month, 1))}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '${DateFormat('d MMM').format(DateTime.now())}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                '${DateFormat('d MMM').format(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0))}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Average line indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'AVG',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                'RM${avgExpense.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'housing':
        return Icons.home;
      case 'dining':
        return Icons.restaurant;
      case 'necessities':
        return Icons.shopping_bag;
      case 'app':
        return Icons.phone_android;
      case 'transport':
        return Icons.directions_car;
      case 'entertainment':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'housing':
        return Colors.blue;
      case 'dining':
        return Colors.orange;
      case 'necessities':
        return Colors.grey;
      case 'app':
        return Colors.purple;
      case 'transport':
        return Colors.green;
      case 'entertainment':
        return Colors.pink;
      default:
        return Colors.teal;
    }
  }

  Widget _buildAIPredictions(String userId, Map<String, dynamic> currentData) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchComprehensiveFinancialData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        final monthlySpending = data['monthlySpending'] as List<double>;
        final monthlyIncome = data['monthlyIncome'] as List<double>;
        final avgSpending = data['avgMonthlySpending'] as double;
        final savingsRate = data['savingsRate'] as List<double>;
        final latestSavingsRate = savingsRate.isNotEmpty ? savingsRate.last : 0.0;

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
                'AI Predictions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<double>(
                future: _predictNextMonthSpending(userId),
                builder: (context, predSnapshot) {
                  if (!predSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final predictedSpending = predSnapshot.data!;
                  final currentIncome = monthlyIncome.isNotEmpty ? monthlyIncome.last : 0.0;
                  final predictedSavings = currentIncome - predictedSpending;
                  final advice = predictedSavings < 0
                      ? 'Consider reducing expenses to avoid a deficit next month.'
                      : 'You\'re on track! Aim to save RM${(predictedSavings * 0.2).toStringAsFixed(2)} more.';

                  return Column(
                    children: [
                      _buildPredictionRow(
                        'Predicted Spending (${DateFormat('MMM yyyy').format(DateTime.now().add(Duration(days: 30)))})',
                        'RM${predictedSpending.toStringAsFixed(2)}',
                        Icons.trending_up,
                        Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _buildPredictionRow(
                        'Predicted Savings',
                        'RM${predictedSavings.toStringAsFixed(2)}',
                        Icons.savings,
                        predictedSavings < 0 ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildPredictionRow(
                        'Current Savings Rate',
                        '${(latestSavingsRate * 100).toStringAsFixed(1)}%',
                        Icons.percent,
                        latestSavingsRate >= 0.2 ? Colors.green : Colors.yellow,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                advice,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPredictionRow(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

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
    };
  }

  Future<double> _predictNextMonthSpending(String userId) async {
    final financialData = await _fetchComprehensiveFinancialData(userId);
    final spendingData = financialData['monthlySpending'] as List<double>;

    // Simple moving average prediction (can be enhanced with more sophisticated algorithms)
    final recentMonths = spendingData.take(3).toList(); // Last 3 months
    final avgSpending = recentMonths.fold(0.0, (sum, item) => sum + item) / recentMonths.length;

    // Add some seasonality factor (can be customized based on user patterns)
    final currentMonth = DateTime.now().month;
    final seasonalityFactor = _getSeasonalityFactor(currentMonth);

    return avgSpending * seasonalityFactor;
  }

  double _getSeasonalityFactor(int month) {
    // Simple seasonality factors (can be customized based on historical data)
    switch (month) {
      case 1: // January - New Year, more spending
        return 1.15;
      case 2: // February - Valentine's Day
        return 1.1;
      case 3: // March - Normal
        return 1.0;
      case 4: // April - Normal
        return 1.0;
      case 5: // May - Normal
        return 1.0;
      case 6: // June - Mid-year
        return 1.05;
      case 7: // July - Summer
        return 1.1;
      case 8: // August - Normal
        return 1.0;
      case 9: // September - Back to school
        return 1.08;
      case 10: // October - Normal
        return 1.0;
      case 11: // November - Pre-holiday
        return 1.12;
      case 12: // December - Holidays, more spending
        return 1.2;
      default:
        return 1.0;
    }
  }

  void _handleNavigation(int index) {
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      // Stay on TrendingPage
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/financial_plan');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/settings');
    }
  }
}