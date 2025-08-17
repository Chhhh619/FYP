import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'goal_progress.dart';
import 'goal_type.dart';

class GoalPage extends StatefulWidget {
  const GoalPage({super.key});

  @override
  State<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends State<GoalPage> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  // Helper method to calculate completion date for regular goals
  DateTime? _calculateCompletionDate(Map<String, dynamic> goal) {
    final type = goal['type'] ?? 'regular';
    final totalAmount = (goal['totalAmount'] ?? 1).toDouble();
    final intervalsDeposited = Map<String, dynamic>.from(goal['intervalsDeposited'] ?? {});

    if (type == 'flexible') {
      // For flexible goals, use the completedDate from Firestore
      if (goal['completedDate'] != null) {
        return (goal['completedDate'] as Timestamp).toDate();
      }
      return null;
    } else {
      // For regular goals, find the interval where the goal was completed
      final startDate = (goal['startDate'] as Timestamp).toDate();
      final repeatType = goal['repeat'] ?? 'Monthly';
      final repeatCount = (goal['repeatCount'] ?? 1).toInt();
      final amountPerInterval = totalAmount / repeatCount;

      double runningTotal = 0.0;

      // Sort intervals by index to process in order
      final sortedIntervals = intervalsDeposited.entries.toList()
        ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

      for (final entry in sortedIntervals) {
        final intervalIndex = int.parse(entry.key);
        final intervalData = entry.value;

        double depositAmount = 0.0;
        if (intervalData is Map<String, dynamic>) {
          depositAmount = (intervalData['amount'] as num?)?.toDouble() ?? 0.0;
        } else if (intervalData is num) {
          depositAmount = intervalData.toDouble();
        }

        runningTotal += depositAmount;

        // If this deposit completed the goal, return the interval date
        if (runningTotal >= totalAmount) {
          return _calculateIntervalDate(startDate, repeatType, intervalIndex);
        }
      }
    }

    return null;
  }

  // Helper method to calculate interval date
  DateTime _calculateIntervalDate(DateTime startDate, String repeatType, int intervalIndex) {
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
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      body: SafeArea(
        child: Column(
          children: [
            // Enhanced header with proper centering
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  // Centered title with proper flex
                  const Expanded(
                    child: Text(
                      "My Goals",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Add button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GoalTypeSelectionPage()),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Goal list from Firestore
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('goals')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.tealAccent),
                    );
                  }

                  final goals = snapshot.data!.docs;

                  if (goals.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        margin: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey[700]!, width: 1),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.flag_outlined,
                                color: Colors.grey,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No goals found',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap the + button above to create your first savings goal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = goals[index];
                      final goal = doc.data() as Map<String, dynamic>;
                      final name = goal['name'] ?? '';
                      final icon = goal['icon'] ?? '🎯';
                      final totalRaw = goal['totalAmount'] ?? 1;
                      final depositedRaw = goal['depositedAmount'] ?? 0;
                      final status = goal['status'] ?? 'active';

                      final totalAmount = totalRaw is String
                          ? double.tryParse(totalRaw) ?? 1
                          : (totalRaw as num).toDouble();
                      final depositedAmount = depositedRaw is String
                          ? double.tryParse(depositedRaw) ?? 0
                          : (depositedRaw as num).toDouble();

                      final startDate = (goal['startDate'] as Timestamp).toDate();
                      final hasEndDate = goal['type'] == 'flexible' && goal['endDate'] != null;
                      final endDate = hasEndDate
                          ? (goal['endDate'] as Timestamp).toDate()
                          : null;

                      final progress = (depositedAmount / totalAmount).clamp(0.0, 1.0);
                      final formatter = NumberFormat.currency(symbol: 'RM');
                      bool isCompleted = status == 'completed' && depositedAmount >= totalAmount;

                      // Get completion date
                      final completionDate = isCompleted ? _calculateCompletionDate(goal) : null;

                      // Enhanced colors and styling based on completion status
                      final backgroundColor = isCompleted ? Colors.teal.withOpacity(0.15) : Colors.grey[850];
                      final borderColor = isCompleted ? Colors.tealAccent.withOpacity(0.5) : Colors.grey[700];
                      final progressColor = isCompleted ? Colors.tealAccent[100] : Colors.tealAccent;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GoalProgressPage(goalId: doc.id),
                            ),
                          );
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: Colors.grey[900],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text('Goal Options', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isCompleted)
                                    ListTile(
                                      leading: const Icon(Icons.check_circle, color: Colors.tealAccent),
                                      title: const Text('Mark as Completed', style: TextStyle(color: Colors.white)),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _markGoalAsCompleted(doc.id);
                                      },
                                    ),
                                  ListTile(
                                    leading: const Icon(Icons.delete, color: Colors.redAccent),
                                    title: const Text('Delete Goal', style: TextStyle(color: Colors.white)),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      _showDeleteConfirmation(context, doc.id, name);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(icon, style: const TextStyle(fontSize: 24)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  if (isCompleted)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.tealAccent.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.tealAccent, width: 1),
                                          ),
                                          child: const Text(
                                            'COMPLETED',
                                            style: TextStyle(
                                              color: Colors.tealAccent,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (completionDate != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('dd MMM yyyy').format(completionDate),
                                            style: const TextStyle(
                                              color: Colors.tealAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Goal: ${formatter.format(totalAmount)}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                  Text('Saved: ${formatter.format(depositedAmount)}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[800],
                                  color: progressColor,
                                  minHeight: 10,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Started', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text(DateFormat('dd MMM yyyy').format(startDate),
                                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Target Date', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text(
                                        hasEndDate
                                            ? DateFormat('dd MMM yyyy').format(endDate!)
                                            : 'No End Date',
                                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markGoalAsCompleted(String goalId) async {
    try {
      await FirebaseFirestore.instance.collection('goals').doc(goalId).update({
        'status': 'completed',
        'completedDate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Goal marked as completed!'),
            backgroundColor: Colors.tealAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update goal: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, String goalId, String goalName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Goal', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete the goal "$goalName"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('goals').doc(goalId).delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Goal deleted successfully'),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}