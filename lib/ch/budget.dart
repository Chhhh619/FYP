
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:fyp/ch/SelectCategoryBudgetPage.dart';
import 'budget_calculator_bottom_sheet.dart';

class BudgetPage extends StatefulWidget {
  final DateTime? selectedDate;
  final String viewMode;

  const BudgetPage({super.key, this.selectedDate, required this.viewMode});

  @override
  _BudgetPageState createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  double? monthlyBudget;
  double? weeklyBudget;
  double? dailyBudget;
  double weeklySpending = 0.0;
  double dailySpending = 0.0;
  double totalSpending = 0.0;
  String _calculatorInput = '0';
  double _calculatorResult = 0;
  bool _isCalculatorOpen = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isYearView = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  Future<void> _loadBudgetData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
        return;
      }

      final selectedDate = widget.selectedDate ?? DateTime.now();

      final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
      final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);

      final startOfWeek = selectedDate.subtract(
        Duration(days: selectedDate.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final startOfDay = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final monthSnap = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final weekSnap = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
          .get();

      final daySnap = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      final docId = DateFormat('yyyy-MM').format(selectedDate);
      final budgetDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc(docId)
          .get();

      double? tempMonthlyBudget;
      if (budgetDoc.exists) {
        final data = budgetDoc.data()!;
        tempMonthlyBudget = data['amount']?.toDouble() ?? 0.0;
      } else {
        tempMonthlyBudget = 0.0;
      }

      final total = await _calculateTotalSpending(monthSnap.docs);
      final weekly = await _calculateTotalSpending(weekSnap.docs);
      final daily = await _calculateTotalSpending(daySnap.docs);

      setState(() {
        totalSpending = total;
        weeklySpending = weekly;
        dailySpending = daily;
        monthlyBudget = tempMonthlyBudget;
        weeklyBudget = monthlyBudget! / 4;
        dailyBudget = monthlyBudget! / _getDaysInMonth(selectedDate.year, selectedDate.month);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $e';
      });
      print('Error loading budget data: $e');
    }
  }

  Future<double> _calculateTotalSpending(List<QueryDocumentSnapshot> docs) async {
    double total = 0.0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('category') && doc['amount'] != null) {
        final categoryRef = data['category'] as DocumentReference;
        final categorySnap = await categoryRef.get();
        if (categorySnap.exists && categorySnap['type'] == 'expense') {
          final amount = (doc['amount'] as num).toDouble();
          total += amount.abs();
        }
      }
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> _fetchCategoryBudgets() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    final selectedDate = widget.selectedDate ?? DateTime.now();
    final docIdPrefix = DateFormat('yyyy-MM').format(selectedDate);
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('categoryBudgets')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(selectedDate.year, selectedDate.month, 1)))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(selectedDate.year, selectedDate.month + 1, 0)))
        .get();

    List<Map<String, dynamic>> categoryBudgets = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final categoryRef = data['category'] as DocumentReference;
      final categorySnap = await categoryRef.get();
      if (categorySnap.exists) {
        final spent = await _calculateCategorySpending(categoryRef, selectedDate);
        categoryBudgets.add({
          'name': categorySnap['name'] ?? 'Unknown',
          'budget': (data['amount'] as num).toDouble(),
          'spent': spent,
          'icon': categorySnap['icon'] ?? '❓',
          'docId': doc.id, // Store document ID for deletion
        });
      }
    }
    return categoryBudgets;
  }

  Future<double> _calculateCategorySpending(DocumentReference categoryRef, DateTime selectedDate) async {
    final userId = _auth.currentUser?.uid;
    final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
    final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);

    final snapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('category', isEqualTo: categoryRef)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    double total = 0.0;
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['amount'] != null) {
        total += (data['amount'] as num).toDouble().abs();
      }
    }
    return total;
  }

  Future<void> _deleteCategoryBudget(String docId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('categoryBudgets')
        .doc(docId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category budget deleted')),
    );

    setState(() {}); // Refresh the UI
  }

// Added: Check if this is the first budget and update gamification
  Future<void> _updateGamificationForBudget(String userId) async {
// Check if user has any budgets
    final budgetsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .limit(1)
        .get();
    final categoryBudgetsSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('categoryBudgets')
        .limit(1)
        .get();

// Only complete challenge if no budgets exist yet
    if (budgetsSnap.docs.isEmpty && categoryBudgetsSnap.docs.isEmpty) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('completed_challenges')
          .doc('set_budget')
          .set({
        'challengeId': 'set_budget',
        'completed': true,
        'completedAt': Timestamp.now(),
        'points': 25,
      });

      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(25),
        'badges.badge_first_budget': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge completed: Set Your First Budget! +25 points')),
      );
      print('Set Your First Budget challenge completed for user: $userId'); // Added: Debugging
    }
  }

  void _toggleCalculator() {
    if (_isCalculatorOpen) return;
    _isCalculatorOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _buildCalculatorContent(),
        );
      },
    ).whenComplete(() {
      setState(() {
        _isCalculatorOpen = false;
      });
    });
  }

  Widget _buildCalculatorContent() {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        void _calculate(String input) {
          setState(() {
            if (input == '.') {
              final parts = _calculatorInput.split(RegExp(r'[\+\-\*/]'));
              final lastNumber = parts.isNotEmpty ? parts.last.trim() : '';
              if (!lastNumber.contains('.')) _calculatorInput += '.';
            } else if (input == 'delete') {
              _calculatorInput = _calculatorInput.length > 1
                  ? _calculatorInput.substring(0, _calculatorInput.length - 1)
                  : '0';
            } else if (input == '=') {
              try {
                _calculatorResult = _evaluateExpression(_calculatorInput);
                _calculatorInput = _calculatorResult.toString();
              } catch (e) {
                _calculatorInput = 'Error';
                _calculatorResult = double.nan;
              }
            } else if (['+', '-', '*', '/'].contains(input)) {
              _calculatorInput += ' $input ';
            } else {
              _calculatorInput = _calculatorInput == '0' ? input : _calculatorInput + input;
            }
          });
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(33, 35, 34, 1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Monthly Budget',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _calculatorInput,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                padding: const EdgeInsets.all(8),
                children: List.generate(17, (index) {
                  final buttons = [
                    '7', '8', '9', '/',
                    '4', '5', '6', '*',
                    '1', '2', '3', '-',
                    '0', '.', '=', '+',
                    'delete'
                  ];
                  final icons = [
                    null, null, null, null,
                    null, null, null, null,
                    null, null, null, null,
                    null, null, null, null,
                    Icons.backspace
                  ];
                  return _buildCalcButton(
                    buttons[index],
                        (input) => _calculate(input),
                    icon: icons[index],
                  );
                }),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_calculatorInput != '0' && !_calculatorInput.contains('Error')) {
                    final result = _evaluateExpression(_calculatorInput);
                    if (result > 0) {
                      _saveBudget(result, setState);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Budget',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _saveBudget(double newBudget, StateSetter setState) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final selectedDate = widget.selectedDate ?? DateTime.now();
    final docId = DateFormat('yyyy-MM').format(selectedDate);
    final daysInMonth = _getDaysInMonth(selectedDate.year, selectedDate.month);

    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('budgets')
        .doc(docId);

    await docRef.set({'amount': newBudget, 'createdAt': Timestamp.now()});
    await _updateGamificationForBudget(userId); // Added: Trigger gamification for monthly budget

    setState(() {
      monthlyBudget = newBudget;
      weeklyBudget = newBudget / 4;
      dailyBudget = newBudget / daysInMonth;
    });

    Navigator.pop(context);
    setState(() {}); // Refresh the main UI
  }

  Widget _buildCalcButton(String text, Function(String) onPressed, {IconData? icon}) {
    return ElevatedButton(
      onPressed: () => onPressed(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(40, 42, 41, 1),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(12),
      ),
      child: icon != null
          ? Icon(icon, size: 20)
          : Text(text, style: const TextStyle(fontSize: 20)),
    );
  }

  double _evaluateExpression(String expression) {
    expression = expression.replaceAll(',', '');
    final parts = expression.split(' ');
    return _parseExpression(parts);
  }

  double _parseExpression(List<String> parts) {
    double result = double.parse(parts[0]);
    for (int i = 1; i < parts.length; i += 2) {
      final op = parts[i];
      final num = double.parse(parts[i + 1]);
      if (op == '+') result += num;
      else if (op == '-') result -= num;
      else if (op == '*') result *= num;
      else if (op == '/') result /= num;
    }
    return result;
  }

  Future<bool> _showCategoryBudgetCalculator(DocumentReference categoryRef, String categoryName) async {
    String input = '0';

    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateInput(String val) {
              setState(() {
                if (val == 'delete') {
                  input = input.length > 1 ? input.substring(0, input.length - 1) : '0';
                } else if (val == '.') {
                  if (!input.contains('.')) input += '.';
                } else if (val == '=') {
                  try {
                    final result = _evaluateExpression(input);
                    input = result.toStringAsFixed(2);
                  } catch (e) {
                    input = 'Error';
                  }
                } else {
                  if (input == '0' || input == 'Error') {
                    input = val;
                  } else {
                    input += val;
                  }
                }
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: Color.fromRGBO(33, 35, 34, 1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 20,
                right: 20,
              ),
              child: Wrap(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    'Set Budget for $categoryName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      input,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      '7', '8', '9', '/',
                      '4', '5', '6', '*',
                      '1', '2', '3', '-',
                      '0', '.', '=', '+',
                      'delete'
                    ].map((val) {
                      final isDelete = val == 'delete';
                      return ElevatedButton(
                        onPressed: () => updateInput(val),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(40, 42, 41, 1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: isDelete
                            ? const Icon(Icons.backspace_outlined, color: Colors.white)
                            : Text(
                          val,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final userId = _auth.currentUser?.uid;
                      final selectedDate = widget.selectedDate ?? DateTime.now();
                      final docId = '${DateFormat('yyyy-MM').format(selectedDate)}_${categoryRef.id}';
                      final amount = double.tryParse(input);
                      if (userId != null && amount != null && amount > 0) {
                        await _firestore
                            .collection('users')
                            .doc(userId)
                            .collection('categoryBudgets')
                            .doc(docId)
                            .set({
                          'category': categoryRef,
                          'amount': amount,
                          'createdAt': Timestamp.now(),
                        });

                        await _updateGamificationForBudget(userId); // Added: Trigger gamification for category budget

                        if (context.mounted) {
                          Navigator.pop(context, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Category budget saved')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Save Budget',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    ) ?? false;
  }

  void _showCategoryGridPopup() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await _firestore
        .collection('categories')
        .where('type', isEqualTo: 'expense')
        .get();
    final categories = snapshot.docs;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final doc = categories[index];
              final data = doc.data() as Map<String, dynamic>;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      final result = await _showCategoryBudgetCalculator(
                        doc.reference,
                        data['name'],
                      );
                      if (result == true) {
                        setState(() {}); // Refresh the main UI after adding a new category budget
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                      backgroundColor: const Color(0xFF2C2C2C),
                    ),
                    child: Text(
                      data['icon'] ?? '❓',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['name'],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildYearlyBudgetCard() {
    final selectedDate = widget.selectedDate ?? DateTime.now();
    final year = selectedDate.year;

    final yearlyBudget = (monthlyBudget ?? 0) * 12;
    final yearlySpent = totalSpending * 12;
    final remaining = yearlyBudget - yearlySpent;
    final progress = yearlyBudget > 0 ? (yearlySpent / yearlyBudget).clamp(0.0, 1.0) : 0.0;
    final percentage = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Year $year',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget\nRM${yearlyBudget.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    remaining >= 0 ? 'Remaining' : 'Over Budget',
                    style: TextStyle(
                      color: remaining >= 0 ? Colors.white70 : Colors.redAccent,
                    ),
                  ),
                  Text(
                    'RM${remaining.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: remaining >= 0 ? Colors.white70 : Colors.redAccent,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          ),
          const SizedBox(height: 4),
          Text(
            '$percentage% | Exp RM${yearlySpent.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBudgetCard() {
    final selectedDate = widget.selectedDate ?? DateTime.now();
    final difference = (monthlyBudget ?? 0) - totalSpending;
    final progress = (monthlyBudget != null && monthlyBudget! > 0)
        ? (totalSpending / monthlyBudget!).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (monthlyBudget != null && monthlyBudget! > 0)
        ? (progress * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('d MMM').format(DateTime(selectedDate.year, selectedDate.month, 1))} - '
                '${DateFormat('d MMM').format(DateTime(selectedDate.year, selectedDate.month + 1, 0))}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Budget\nRM${(monthlyBudget ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  IconButton(
                    onPressed: _toggleCalculator,
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.white70,
                      size: 20,
                    ),
                    padding: const EdgeInsets.only(left: 4.0),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    difference >= 0 ? 'Remaining' : 'Over Budget',
                    style: TextStyle(
                      color: difference >= 0 ? Colors.white70 : Colors.redAccent,
                    ),
                  ),
                  Text(
                    'RM${difference.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: difference >= 0 ? Colors.white70 : Colors.redAccent,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          ),
          const SizedBox(height: 4),
          Text(
            '$percentage% | Exp RM${totalSpending.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBudgetCard(String label, double budget, double spent) {
    final over = spent - budget;
    final progress = (budget > 0) ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            over > 0 ? 'Over Budget' : 'Remaining',
            style: TextStyle(
              color: over > 0 ? Colors.redAccent : Colors.white70,
            ),
          ),
          Text(
            'RM${over > 0 ? over.toStringAsFixed(2) : (budget - spent).toStringAsFixed(2)}',
            style: TextStyle(
              color: over > 0 ? Colors.redAccent : Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
          Text(
            'Bud RM${budget.toStringAsFixed(0)}\nExp RM${spent.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String name, double budget, double spent, String icon, String docId) {
    final remaining = budget - spent;
    final percent = (budget > 0) ? (spent / budget).clamp(0.0, 1.0) * 100 : 0.0;

    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: Text(
              'Delete Budget for $name',
              style: const TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this category budget?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await _deleteCategoryBudget(docId);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[800],
              child: Text(
                icon,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (budget > 0) ? (spent / budget).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bud RM${budget.toStringAsFixed(0)}  Exp RM${spent.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(100 - percent).toStringAsFixed(2)}%',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Remaining\nRM${remaining.toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 0,
        centerTitle: true,
        title: const Text('Budget', style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ToggleButtons(
              isSelected: [_isYearView == false, _isYearView == true],
              onPressed: (int index) {
                setState(() {
                  _isYearView = index == 1;
                });
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.teal,
              fillColor: Colors.teal.withOpacity(0.2),
              color: Colors.white,
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Monthly'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Year'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _isYearView
                ? _buildYearlyBudgetCard()
                : Column(
              children: [
                _buildMainBudgetCard(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSmallBudgetCard(
                        'Week',
                        weeklyBudget ?? 0,
                        weeklySpending,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSmallBudgetCard(
                        'Today',
                        dailyBudget ?? 0,
                        dailySpending,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Category budget',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.teal),
                  onPressed: _showCategoryGridPopup,
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchCategoryBudgets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }
                if (snapshot.hasError) {
                  return const Text(
                    'Error loading category budgets',
                    style: TextStyle(color: Colors.red),
                  );
                }
                final categoryBudgets = snapshot.data ?? [];
                if (categoryBudgets.isEmpty) {
                  return const Text(
                    'No category budgets set',
                    style: TextStyle(color: Colors.white70),
                  );
                }
                return Column(
                  children: categoryBudgets
                      .map((budget) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildCategoryCard(
                      budget['name'],
                      budget['budget'],
                      budget['spent'],
                      budget['icon'],
                      budget['docId'],
                    ),
                  ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
