import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'goal_details.dart';

class GoalProgressPage extends StatefulWidget {
  final String goalId;

  const GoalProgressPage({super.key, required this.goalId});

  @override
  State<GoalProgressPage> createState() => _GoalProgressPageState();
}

class _GoalProgressPageState extends State<GoalProgressPage> {
  DateTime _calculateIntervalDate(
    DateTime startDate,
    String repeatType,
    int intervalIndex,
  ) {
    switch (repeatType.toLowerCase()) {
      case 'daily':
        return startDate.add(Duration(days: intervalIndex));
      case 'weekly':
        return startDate.add(Duration(days: intervalIndex * 7));
      case 'monthly':
        return DateTime(
          startDate.year,
          startDate.month + intervalIndex,
          startDate.day,
        );
      case 'yearly':
        return DateTime(
          startDate.year + intervalIndex,
          startDate.month,
          startDate.day,
        );
      default:
        return DateTime(
          startDate.year,
          startDate.month + intervalIndex,
          startDate.day,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('goals')
          .doc(widget.goalId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: Color.fromRGBO(28, 28, 28, 1),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final goal = snapshot.data!.data() as Map<String, dynamic>;
        return _buildGoalUI(context, goal);
      },
    );
  }

  Widget _buildGoalUI(BuildContext context, Map<String, dynamic> goal) {
    final formatter = NumberFormat.currency(symbol: 'RM');

    final totalAmount = (goal['totalAmount'] ?? 1).toDouble();
    final deposited = (goal['depositedAmount'] ?? 0).toDouble();
    final start = (goal['startDate'] as Timestamp).toDate();
    final repeatCount = (goal['repeatCount'] ?? 1).toInt();
    final repeatType = goal['repeat'] ?? 'Monthly';

    final amountPerInterval = totalAmount / repeatCount;
    final progress = (deposited / totalAmount).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          goal['name'] ?? 'Goal',
          style: const TextStyle(color: Colors.white),
        ),
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
                  Text(
                    goal['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Planned Deposit',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        formatter.format(totalAmount),
                        style: const TextStyle(color: Colors.tealAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saved ${formatter.format(deposited)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Remaining ${formatter.format(totalAmount - deposited)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
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
                      Text(
                        DateFormat('dd MMM yyyy').format(start),
                        style: const TextStyle(color: Colors.white54),
                      ),
                      Text(
                        goal['type'] == 'flexible' && goal['endDate'] != null
                            ? DateFormat(
                                'dd MMM yyyy',
                              ).format((goal['endDate'] as Timestamp).toDate())
                            : 'No End Date',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Savings Progress',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Text(
                    repeatType,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
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
                  final intervalDate = _calculateIntervalDate(
                    start,
                    repeatType,
                    index,
                  );
                  final intervalsDeposited = goal['intervalsDeposited'] ?? {};
                  final intervalData = intervalsDeposited['$index'];
                  final isDeposited = intervalData != null;

                  double amount = amountPerInterval;
                  String? cardUsed;

                  if (intervalData is Map<String, dynamic>) {
                    amount =
                        (intervalData['amount'] as num?)?.toDouble() ??
                        amountPerInterval;
                    cardUsed = intervalData['cardId'];
                  } else if (intervalData is num) {
                    // Support old format
                    amount = intervalData.toDouble();
                  }

                  final now = DateTime.now();
                  final isOverdue = !isDeposited && intervalDate.isBefore(now);
                  final isDueToday =
                      !isDeposited &&
                      intervalDate.year == now.year &&
                      intervalDate.month == now.month &&
                      intervalDate.day == now.day;

                  Color borderColor = Colors.grey[700]!;
                  Color statusColor = Colors.white70;
                  String statusText = 'Pending Deposit';

                  if (isDeposited) {
                    borderColor = Colors.greenAccent;
                    statusColor = Colors.greenAccent;
                    statusText = 'Deposited';
                  } else if (isOverdue) {
                    borderColor = Colors.redAccent;
                    statusColor = Colors.redAccent;
                    statusText = 'Overdue';
                  } else if (isDueToday) {
                    borderColor = Colors.orangeAccent;
                    statusColor = Colors.orangeAccent;
                    statusText = 'Due Today';
                  }

                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GoalDetailsPage(
                            goal: goal,
                            goalId: widget.goalId,
                            intervalIndex: index,
                            intervalDueDate: intervalDate,
                            amountPerInterval: amountPerInterval,
                            selectedFromCardId: isDeposited ? cardUsed : null, // Pass the last used card ID
                            selectedToCardId: null, // Add logic for To Card if needed
                          ),
                        ),
                      );
                      // No need to refresh here; StreamBuilder handles it
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[900],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'RM${amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.tealAccent,
                            ),
                          ),
                          if (cardUsed != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Card: $cardUsed',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            _getFormattedDate(intervalDate, repeatType),
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  );                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate(DateTime date, String repeatType) {
    switch (repeatType.toLowerCase()) {
      case 'yearly':
        return DateFormat('MMM yyyy').format(date);
      default:
        return DateFormat('dd MMM').format(date);
    }
  }
}
