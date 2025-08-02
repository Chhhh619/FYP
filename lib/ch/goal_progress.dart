import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'goal_details.dart';

class GoalProgressPage extends StatelessWidget {
  final Map<String, dynamic> goal;
  final String goalId;

  const GoalProgressPage({super.key, required this.goal, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: 'RM');

    // Total amount
    final totalRaw = goal['totalAmount'] ?? 1;
    final totalAmount = totalRaw is String
        ? double.tryParse(totalRaw) ?? 1
        : (totalRaw as num).toDouble();

    // Deposited amount
    final depositedRaw = goal['depositedAmount'] ?? 0;
    final deposited = depositedRaw is String
        ? double.tryParse(depositedRaw) ?? 0
        : (depositedRaw as num).toDouble();

    // Start date
    final start = (goal['startDate'] as Timestamp).toDate();

    // Number of intervals
    final repeatCountRaw = goal['repeatCount'] ?? 1;
    final repeatCount = repeatCountRaw is String
        ? int.tryParse(repeatCountRaw) ?? 1
        : (repeatCountRaw as num).toInt();

    final amountPerInterval = totalAmount / repeatCount;
    final progress = (deposited / totalAmount).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(goal['name'] ?? 'Goal', style: const TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal['name'] ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Planned Deposit', style: TextStyle(color: Colors.white70)),
                      Text(formatter.format(totalAmount), style: const TextStyle(color: Colors.tealAccent)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Saved ${formatter.format(deposited)}',
                          style: const TextStyle(color: Colors.white)),
                      Text('Remaining ${formatter.format(totalAmount - deposited)}',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[800],
                    color: Colors.cyan,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMM yyyy').format(start), style: const TextStyle(color: Colors.white54)),
                      Text(
                        goal['type'] == 'flexible' && goal['endDate'] != null
                            ? DateFormat('dd MMM yyyy').format((goal['endDate'] as Timestamp).toDate())
                            : 'No End Date',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Savings Progress', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: repeatCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final intervalDate = DateTime(start.year, start.month + index, start.day);
                  final intervalsDeposited = goal['intervalsDeposited'] ?? {};
                  final depositedValue = intervalsDeposited['$index'];
                  final isDeposited = depositedValue != null;

                  final amount = depositedValue is String
                      ? double.tryParse(depositedValue) ?? amountPerInterval
                      : (depositedValue as num?)?.toDouble() ?? amountPerInterval;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GoalDetailsPage(
                            goal: goal,
                            goalId: goalId,
                            intervalIndex: index,
                            intervalDueDate: intervalDate,
                            amountPerInterval: amountPerInterval,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[700]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[900],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isDeposited ? 'Deposited' : 'Pending Deposit',
                              style: TextStyle(
                                color: isDeposited ? Colors.greenAccent : Colors.white70,
                              )),
                          const SizedBox(height: 6),
                          Text('RM${amount.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, color: Colors.tealAccent)),
                          const SizedBox(height: 6),
                          Text(DateFormat('dd MMM').format(intervalDate),
                              style: const TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
