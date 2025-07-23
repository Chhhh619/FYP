import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'financial_planning_advisor.dart';

class FinancialPlanningScreen extends StatefulWidget {
  const FinancialPlanningScreen({super.key});

  @override
  _FinancialPlanningScreenState createState() => _FinancialPlanningScreenState();
}

class _FinancialPlanningScreenState extends State<FinancialPlanningScreen> {
  late Future<FinancialPlan?> _planFuture;

  @override
  void initState() {
    super.initState();
    _planFuture = FinancialAdvisor.generatePlan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
        title: const Text(
          'Financial Planning',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/add_goal');
            },
          ),
        ],
      ),
      body: FutureBuilder<FinancialPlan?>(
        future: _planFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingSkeleton();
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading plan: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }
          final plan = snapshot.data;
          if (plan == null) {
            return const Center(
              child: Text(
                'No financial plan available. Add transactions to get started.',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.grey[900],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Budget: RM${plan.monthlyBudget.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Savings Target: RM${plan.savingsTarget.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scenario: ${plan.scenario.toString().split('.').last}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Action Items',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: plan.actionItems.length,
                    itemBuilder: (context, index) {
                      final item = plan.actionItems[index];
                      return Card(
                        color: Colors.grey[900],
                        child: ListTile(
                          title: Text(
                            item.description,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'RM${item.amount.toStringAsFixed(1)} (${item.category})',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Goals',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: plan.goals.length,
                    itemBuilder: (context, index) {
                      final goal = plan.goals[index];
                      return Card(
                        color: Colors.grey[900],
                        child: ListTile(
                          title: Text(
                            goal.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Progress: RM${goal.currentAmount.toStringAsFixed(1)} / RM${goal.targetAmount.toStringAsFixed(1)} '
                                '(${goal.progress.toStringAsFixed(2)}%)',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: Text(
                            DateFormat('d MMM yyyy').format(goal.deadline),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 150, height: 18, color: Colors.grey[700]),
                  const SizedBox(height: 8),
                  Container(width: 120, height: 18, color: Colors.grey[700]),
                  const SizedBox(height: 8),
                  Container(width: 100, height: 16, color: Colors.grey[700]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(width: 100, height: 20, color: Colors.grey[700]),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Card(
                    color: Colors.grey[900],
                    child: ListTile(
                      title: Container(width: 120, height: 16, color: Colors.grey[700]),
                      subtitle: Container(width: 80, height: 14, color: Colors.grey[700]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}