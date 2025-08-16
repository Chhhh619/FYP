import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:fyp/ch/record_transaction.dart';

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
  final ScrollController _scrollController = ScrollController();

  Future<Map<String, dynamic>> _fetchMonthlyData(String userId, DateTime month) async {
    try {
      print('Fetching data for user: $userId, month: ${DateFormat('yyyy-MM').format(month)}');

      // Fix date calculations
      final monthStart = DateTime(month.year, month.month, 1);
      DateTime monthEnd;
      if (month.month == 12) {
        monthEnd = DateTime(month.year + 1, 1, 1);
      } else {
        monthEnd = DateTime(month.year, month.month + 1, 1);
      }

      print('Date range: $monthStart to $monthEnd');

      final snapshot = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('timestamp', isLessThan: Timestamp.fromDate(monthEnd))
          .get();

      print('Found ${snapshot.docs.length} transactions');

      double totalExpenses = 0.0;
      double totalIncome = 0.0;
      int transactionCount = 0;
      Map<String, double> categoryTotals = {};

      // Fix daily expenses array size
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      List<double> dailyExpenses = List.filled(daysInMonth, 0.0);

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          final timestamp = data['timestamp'] as Timestamp?;
          final categoryRef = data['category'] as DocumentReference?;

          String transactionType = data['type'] ?? data['categoryType'] ?? '';

          // If type is not directly available, fetch from category
          if (transactionType.isEmpty && categoryRef != null) {
            try {
              final categoryDoc = await categoryRef.get();
              if (categoryDoc.exists) {
                final categoryData = categoryDoc.data() as Map<String, dynamic>?;
                transactionType = categoryData?['type'] ?? '';
              }
            } catch (e) {
              print('Error fetching category type: $e');
              continue; // Skip this transaction
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
                categoryTotals['Unknown'] = (categoryTotals['Unknown'] ?? 0.0) + amount.abs();
              }
            }
          } else if (transactionType == 'income') {
            totalIncome += amount.abs();
          }
        } catch (e) {
          print('Error processing transaction ${doc.id}: $e');
          continue;
        }
      }

      final result = {
        'totalExpenses': totalExpenses,
        'totalIncome': totalIncome,
        'balance': totalIncome - totalExpenses,
        'transactionCount': transactionCount,
        'categoryTotals': categoryTotals,
        'dailyExpenses': dailyExpenses,
      };

      print('Monthly data result: Expenses: $totalExpenses, Income: $totalIncome, Transactions: $transactionCount');
      return result;
    } catch (e) {
      print('Error in _fetchMonthlyData: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchComparisonData(String userId) async {
    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month, 1);

      // Get current month
      final currentData = await _fetchMonthlyData(userId, currentMonth);

      // Get last month
      DateTime lastMonth;
      if (now.month == 1) {
        lastMonth = DateTime(now.year - 1, 12, 1);
      } else {
        lastMonth = DateTime(now.year, now.month - 1, 1);
      }
      final lastMonthData = await _fetchMonthlyData(userId, lastMonth);

      // Calculate averages
      double threeMonthTotal = 0.0;
      double sixMonthTotal = 0.0;

      for (int i = 0; i < 6; i++) { // Start from 0 (current month)
        DateTime targetMonth;
        if (now.month - i <= 0) {
          targetMonth = DateTime(now.year - 1, 12 + (now.month - i), 1);
        } else {
          targetMonth = DateTime(now.year, now.month - i, 1);
        }

        final monthData = await _fetchMonthlyData(userId, targetMonth);
        final expenses = monthData['totalExpenses'] as double;

        // Always add to totals
        if (i < 3) threeMonthTotal += expenses;
        sixMonthTotal += expenses;
      }

      // Calculate averages
      final threeMonthAvg = threeMonthTotal / 3;
      final sixMonthAvg = sixMonthTotal / 6;

      //Daily averages
      final dailyAvgCurrent = (currentData['totalExpenses'] as double) / now.day;
      final dailyAvgLast = (lastMonthData['totalExpenses'] as double) /
          DateTime(lastMonth.year, lastMonth.month + 1, 0).day;

      return {
        'current': currentData,
        'lastMonth': lastMonthData,
        'threeMonthAvg': threeMonthAvg,
        'sixMonthAvg': sixMonthAvg,
        'dailyAvgCurrent': dailyAvgCurrent,
        'dailyAvgLast': dailyAvgLast,
      };
    } catch (e) {
      print('Error in _fetchComparisonData: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    print('Building TrendingPage with userId: $userId');

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
        backgroundColor: const Color(0xFF1C1C1C),
        automaticallyImplyLeading: false,
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
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchComparisonData(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.teal),
                    SizedBox(height: 16),
                    Text(
                      'Loading your financial data...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              print('Error in FutureBuilder: ${snapshot.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading data: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {}); // Trigger rebuild
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final data = snapshot.data!;
            final currentData = data['current'] as Map<String, dynamic>;
            final lastMonthData = data['lastMonth'] as Map<String, dynamic>;

            print('Rendering data with current expenses: ${currentData['totalExpenses']}');

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
                _buildCategoryBreakdown(currentData['categoryTotals'] as Map<String, double>),
                const SizedBox(height: 20),
                _buildDailySpendingChart(currentData['dailyExpenses'] as List<double>),
                const SizedBox(height: 20),
                _buildPredictionsSection(userId),
              ],
            );
          },
        ),
      ),
      floatingActionButton: PersistentAddButton(
        scrollController: _scrollController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  // Replace the _buildDailySpendingChart with this:
  Widget _buildDailySpendingChart(List<double> dailyExpenses) {
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
                'Daily Spending',
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
            child: dailyExpenses.isEmpty
                ? const Center(
              child: Text(
                'No expense data available',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            )
                : Row(
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
        ],
      ),
    );
  }

// Replace the _buildPredictionsSection with this:
  Widget _buildPredictionsSection(String userId) {
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
                'Predictions',
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

  Widget _buildCategoryBreakdown(Map<String, double> categoryTotals) {
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
          if (sortedCategories.isEmpty)
            const Text(
              'No expense data available',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            )
          else
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
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
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
                'Predictions',
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
    try {
      final now = DateTime.now();
      List<double> monthlySpending = List.filled(12, 0.0);
      List<double> monthlyIncome = List.filled(12, 0.0);
      Map<String, double> categoryTotals = {};
      Map<String, List<double>> categoryTrends = {};
      List<double> savingsRate = List.filled(12, 0.0);

      for (int i = 0; i < 12; i++) {
        DateTime targetMonth;
        if (now.month - i <= 0) {
          int targetYear = now.year;
          int targetMonthNum = now.month - i;
          while (targetMonthNum <= 0) {
            targetYear--;
            targetMonthNum += 12;
          }
          targetMonth = DateTime(targetYear, targetMonthNum, 1);
        } else {
          targetMonth = DateTime(now.year, now.month - i, 1);
        }

        final monthStart = DateTime(targetMonth.year, targetMonth.month, 1);
        DateTime monthEnd;
        if (targetMonth.month == 12) {
          monthEnd = DateTime(targetMonth.year + 1, 1, 1);
        } else {
          monthEnd = DateTime(targetMonth.year, targetMonth.month + 1, 1);
        }

        print('Fetching transactions for user: $userId, month: ${DateFormat('yyyy-MM').format(targetMonth)}');
        final snapshot = await _firestore
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
            .where('timestamp', isLessThan: Timestamp.fromDate(monthEnd))
            .get();

        print('Found ${snapshot.docs.length} transactions for ${DateFormat('yyyy-MM').format(targetMonth)}');

        double monthExpenses = 0.0;
        double monthIncome = 0.0;
        Map<String, double> monthCategorySpending = {};

        for (var doc in snapshot.docs) {
          try {
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
                continue;
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
                  monthCategorySpending['Unknown'] = (monthCategorySpending['Unknown'] ?? 0.0) + amount.abs();
                }
              }
            } else if (transactionType == 'income') {
              monthIncome += amount.abs();
            }
          } catch (e) {
            print('Error processing transaction ${doc.id}: $e');
            continue;
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
    } catch (e) {
      print('Error in _fetchComprehensiveFinancialData: $e');
      rethrow;
    }
  }

  Future<double> _predictNextMonthSpending(String userId) async {
    try {
      final financialData = await _fetchComprehensiveFinancialData(userId);
      final spendingData = financialData['monthlySpending'] as List<double>;

      // Debug: Verify fetched data
      print('Spending data: $spendingData'); // Should show [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3907, 4229]

      // Use the most recent non-zero months
      final recentSpending = spendingData.reversed.take(3).toList(); // Take last 3 months (Aug, Jul, Jun)
      print('Recent spending: $recentSpending'); // Should show [4229, 3907, 0]

      // Define weights for up to 3 months
      final weights = [0.5, 0.3, 0.2];
      double weightedSum = 0.0;
      int validMonths = 0;

      // Calculate weighted sum for non-zero months
      for (int i = 0; i < recentSpending.length; i++) {
        if (recentSpending[i] > 0) {
          weightedSum += recentSpending[i] * weights[i];
          validMonths++;
        }
      }

      // If no valid months, return 0 or a fallback value
      if (validMonths == 0) {
        print('No spending data available for prediction');
        return 0.0;
      }

      // Normalize weights if fewer than 3 months are available
      double weightSum = weights.take(validMonths).fold(0.0, (sum, weight) => sum + weight);
      double weightedAverage = weightedSum / weightSum;

      // Apply seasonality factor for the next month
      final nextMonth = DateTime.now().month + 1;
      final seasonalityFactor = _getSeasonalityFactor(nextMonth);
      print('Seasonality factor: $seasonalityFactor'); // Should be 1.08 for September

      double predictedSpending = weightedAverage * seasonalityFactor;
      print('Predicted spending: $predictedSpending');

      return predictedSpending;
    } catch (e) {
      print('Prediction error: $e');
      return 0.0;
    }
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

  @override
  void dispose() {
    _scrollController.dispose(); // Dispose ScrollController
    super.dispose();
  }
}

