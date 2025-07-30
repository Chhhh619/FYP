import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FinancialPlanPage extends StatefulWidget {
  const FinancialPlanPage({super.key});

  @override
  _FinancialPlanPageState createState() => _FinancialPlanPageState();
}

class _FinancialPlanPageState extends State<FinancialPlanPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Interpreter? _interpreter;

  Future<Interpreter> _getInterpreter() async {
    if (_interpreter == null) {
      try {
        final ref = FirebaseStorage.instance.ref('models/spending_model.tflite'); // Verify this path
        final bytes = await ref.getData();
        if (bytes == null) {
          throw Exception('Model file not found or empty at models/spending_model.tflite');
        }
        _interpreter = await Interpreter.fromBuffer(bytes);
      } catch (e) {
        print('Interpreter error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load model: $e. Check Storage configuration.')),
        );
        rethrow; // Let the caller handle the fallback
      }
    }
    return _interpreter!;
  }

  Future<double> _predictNextMonthSpending(String userId) async {
    try {
      final interpreter = await _getInterpreter();
      final spendingData = await _fetchMonthlySpending(userId);
      var input = spendingData; // Adjust based on model input shape
      var output = List.filled(1, 0.0);
      interpreter.run(input, output);
      print('Input: $input, Output: $output');
      return output[0].clamp(0.0, double.infinity);
    } catch (e) {
      print('Prediction error: $e');
      return 0.0; // Fallback
    }
  }

  Future<List<String>> _generateRecommendations(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final snapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .get();
    double totalExpenses = 0.0;
    double totalIncome = 0.0;
    Map<String, double> categorySpending = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final categoryRef = data['category'] as DocumentReference?;
      final type = data['type'] as String? ?? '';
      if (type == 'expense' && categoryRef != null) {
        final categoryDoc = await categoryRef.get();
        final categoryName = categoryDoc['name'] as String? ?? 'Unknown';
        totalExpenses += amount;
        categorySpending[categoryName] = (categorySpending[categoryName] ?? 0.0) + amount;
      } else if (type == 'income') {
        totalIncome += amount;
      }
    }
    final goalsSnapshot = await _firestore
        .collection('goals')
        .where('userId', isEqualTo: userId)
        .get();
    List<String> recommendations = [];
    categorySpending.forEach((category, amount) {
      if (amount / totalExpenses > 0.3 && totalExpenses > 0) {
        recommendations.add(
            'You spent RM${amount.toStringAsFixed(2)} on $category this month. Consider reducing by 20% to save more.');
      }
    });
    if (totalExpenses > totalIncome * 0.8 && totalIncome > 0) {
      recommendations.add(
          'Your expenses (RM${totalExpenses.toStringAsFixed(2)}) are high compared to income (RM${totalIncome.toStringAsFixed(2)}). Aim to keep expenses below 70% of income.');
    }
    for (var goal in goalsSnapshot.docs) {
      final data = goal.data();
      final target = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
      final current = (data['currentAmount'] as num?)?.toDouble() ?? 0.0;
      final deadline = (data['deadline'] as Timestamp?)?.toDate();
      if (deadline != null && deadline.isAfter(now)) {
        final monthsLeft = deadline.difference(now).inDays / 30;
        if (monthsLeft > 0) {
          final monthlySavings = (target - current) / monthsLeft;
          recommendations.add(
              'To reach your ${data['name']} goal by ${DateFormat('MMM dd, yyyy').format(deadline)}, save RM${monthlySavings.toStringAsFixed(2)} monthly.');
        }
      }
    }
    final predictedSpending = await _predictNextMonthSpending(userId);
    if (predictedSpending > totalExpenses * 1.2 && totalExpenses > 0) {
      recommendations.add(
          'AI predicts you may spend RM${predictedSpending.toStringAsFixed(2)} next month, higher than this month’s RM${totalExpenses.toStringAsFixed(2)}. Consider budgeting to avoid overspending.');
    }
    return recommendations.isEmpty
        ? ['No specific recommendations at this time. Keep tracking your finances!']
        : recommendations;
  }

  Future<List<double>> _fetchMonthlySpending(String userId) async {
    final now = DateTime.now();
    List<double> spendingData = List.filled(6, 0.0); // Last 6 months
    for (int i = 0; i < 6; i++) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 1);
      final snapshot = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('type', isEqualTo: 'expense')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('timestamp', isLessThan: Timestamp.fromDate(monthEnd))
          .get();
      double total = 0.0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      }
      spendingData[5 - i] = total;
    }
    return spendingData;
  }

  Widget _buildSpendingChart(String userId) {
    return FutureBuilder<List<double>>(
      future: _fetchMonthlySpending(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text(
            'Error loading spending data',
            style: TextStyle(color: Colors.white70),
          );
        }
        final spendingData = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spending Trends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'RM${value.toInt()}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final now = DateTime.now();
                          final month = DateTime(now.year, now.month - 5 + value.toInt(), 1);
                          return Text(
                            DateFormat('MMM').format(month),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.white54)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spendingData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 2,
                      belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.3)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGoalsList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('goals').where('userId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No goals set yet. Add a goal to start planning!',
            style: TextStyle(color: Colors.white70),
          );
        }
        final goals = snapshot.data!.docs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Goals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ...goals.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final target = (data['targetAmount'] as num?)?.toDouble() ?? 0.0;
              final current = (data['currentAmount'] as num?)?.toDouble() ?? 0.0;
              final progress = target > 0 ? (current / target * 100).clamp(0, 100) : 0.0;
              return Card(
                color: const Color(0xFF323232),
                child: ListTile(
                  title: Text(
                    data['name'] ?? 'Unnamed Goal',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RM${current.toStringAsFixed(2)} / RM${target.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.white54,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                      ),
                      Text(
                        'Deadline: ${data['deadline'] != null ? DateFormat('MMM dd, yyyy').format((data['deadline'] as Timestamp).toDate()) : 'Unknown'}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.teal),
                    onPressed: () => Navigator.pushNamed(context, '/edit_goal', arguments: doc.id),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildRecommendations(String userId) {
    return FutureBuilder<List<String>>(
      future: _generateRecommendations(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text(
            'Error loading recommendations',
            style: TextStyle(color: Colors.white70),
          );
        }
        final recommendations = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Recommendations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ...recommendations.map(
                  (rec) => Card(
                color: const Color(0xFF323232),
                child: ListTile(
                  leading: const Icon(Icons.lightbulb, color: Colors.teal),
                  title: Text(
                    rec,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrediction(String userId) {
    return FutureBuilder<double>(
      future: _predictNextMonthSpending(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Text('Error loading prediction', style: TextStyle(color: Colors.white70));
        }
        final predicted = snapshot.data!;
        return Card(
          color: const Color(0xFF323232),
          child: ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.teal),
            title: Text(
              'Predicted Next Month Spending: RM${predicted.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1C),
        body: const Center(
          child: Text('Please log in to view financial plan', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      appBar: AppBar(
        title: const Text('Financial Plan', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/add_goal'),
            tooltip: 'Add Goal',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        color: Colors.teal,
        backgroundColor: const Color(0xFF323232),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSpendingChart(userId),
              const SizedBox(height: 20),
              _buildGoalsList(userId),
              const SizedBox(height: 20),
              _buildRecommendations(userId),
              const SizedBox(height: 20),
              _buildPrediction(userId),
            ],
          ),
        ),
      ),
    );
  }
}