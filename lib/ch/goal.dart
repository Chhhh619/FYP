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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
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
                    return const Center(child: CircularProgressIndicator());
                  }

                  final goals = snapshot.data!.docs;

                  if (goals.isEmpty) {
                    return const Center(
                      child: Text('No goals found.', style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                      final isCompleted = status == 'completed';

                      // Choose colors based on completion status
                      final backgroundColor = isCompleted ? Colors.teal.withOpacity(0.15) : Colors.grey[900];
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
                              title: const Text('Goal Options', style: TextStyle(color: Colors.white)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isCompleted) ...[
                                    ListTile(
                                      leading: const Icon(Icons.check_circle, color: Colors.tealAccent),
                                      title: const Text('Mark as Completed', style: TextStyle(color: Colors.white)),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _markGoalAsCompleted(doc.id);
                                      },
                                    ),
                                  ] else ...[
                                    ListTile(
                                      leading: const Icon(Icons.restart_alt, color: Colors.orange),
                                      title: const Text('Reactivate Goal', style: TextStyle(color: Colors.white)),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        await _reactivateGoal(doc.id);
                                      },
                                    ),
                                  ],
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
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(icon, style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.tealAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
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
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Goal: ${formatter.format(totalAmount)}',
                                      style: const TextStyle(color: Colors.white70)),
                                  Text('Saved: ${formatter.format(depositedAmount)}',
                                      style: const TextStyle(color: Colors.white70)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[800],
                                color: progressColor,
                                minHeight: 8,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('dd MMM yyyy').format(startDate),
                                      style: const TextStyle(color: Colors.white54)),
                                  Text(
                                    hasEndDate
                                        ? DateFormat('dd MMM yyyy').format(endDate!)
                                        : 'No End Date',
                                    style: const TextStyle(color: Colors.white54),
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
          const SnackBar(
            content: Text('Goal marked as completed!'),
            backgroundColor: Colors.tealAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update goal: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _reactivateGoal(String goalId) async {
    try {
      await FirebaseFirestore.instance.collection('goals').doc(goalId).update({
        'status': 'active',
        'completedDate': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal reactivated!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reactivate goal: ${e.toString()}')),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, String goalId, String goalName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Goal', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete the goal "$goalName"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection('goals').doc(goalId).delete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}