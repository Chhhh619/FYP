import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RecordsDetailPage extends StatefulWidget {
  final String transactionId;

  const RecordsDetailPage({super.key, required this.transactionId});

  @override
  _RecordsDetailPageState createState() => _RecordsDetailPageState();
}

class _RecordsDetailPageState extends State<RecordsDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? transactionData;
  Map<String, dynamic>? categoryData;
  Map<String, dynamic>? cardData;
  bool _isLoading = true;
  String? _errorMessage;

  // Calculator variables
  String _calculatorInput = '0';
  double _calculatorResult = 0;
  bool _isCalculatorOpen = false;

  @override
  void initState() {
    super.initState();
    _loadTransactionDetails();
  }

  Future<void> _loadTransactionDetails() async {
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

      // Get transaction document
      final transactionDoc = await _firestore
          .collection('transactions')
          .doc(widget.transactionId)
          .get();

      if (!transactionDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Transaction not found';
        });
        return;
      }

      final transactionInfo = transactionDoc.data()!;

      // Get category details
      Map<String, dynamic>? categoryInfo;
      if (transactionInfo['category'] != null) {
        DocumentReference? categoryRef;

        if (transactionInfo['category'] is DocumentReference) {
          categoryRef = transactionInfo['category'] as DocumentReference;
        } else if (transactionInfo['category'] is String) {
          categoryRef = _firestore.collection('categories').doc(transactionInfo['category'] as String);
        }

        if (categoryRef != null) {
          final categoryDoc = await categoryRef.get();
          if (categoryDoc.exists) {
            categoryInfo = categoryDoc.data() as Map<String, dynamic>;
          }
        }
      }

      // Get card details if cardId exists
      Map<String, dynamic>? cardInfo;
      if (transactionInfo['cardId'] != null) {
        final cardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(transactionInfo['cardId'])
            .get();

        if (cardDoc.exists) {
          cardInfo = cardDoc.data();
        }
      }

      setState(() {
        transactionData = transactionInfo;
        categoryData = categoryInfo;
        cardData = cardInfo;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading transaction: $e';
      });
    }
  }

  void _toggleEditCalculator() {
    if (_isCalculatorOpen) return;
    _isCalculatorOpen = true;

    // Initialize calculator with current amount (always positive for display)
    final currentAmount = (transactionData?['amount'] ?? 0.0).abs();
    _calculatorInput = currentAmount.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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
              _calculatorInput = _calculatorInput == '0'
                  ? input
                  : _calculatorInput + input;
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
                    'Edit Transaction',
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
                    'delete',
                  ];
                  final icons = [
                    null, null, null, null,
                    null, null, null, null,
                    null, null, null, null,
                    null, null, null, null,
                    Icons.backspace,
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
                      _updateTransaction(result);
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
                  'Update Transaction',
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

  Future<void> _updateTransaction(double newAmount) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || transactionData == null) return;

      final oldAmount = (transactionData!['amount'] as num).toDouble();
      final transactionType = transactionData!['type'] ?? 'expense';

      // First, get the current card data if it exists BEFORE the transaction
      Map<String, dynamic>? currentCardData;
      if (transactionData!['cardId'] != null) {
        final cardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(transactionData!['cardId'])
            .get();

        if (cardDoc.exists) {
          currentCardData = cardDoc.data();
        }
      }

      // Now run the transaction with all reads completed
      await _firestore.runTransaction((transaction) async {
        final transactionRef = _firestore.collection('transactions').doc(widget.transactionId);

        final signedAmount = transactionType == 'income' ? newAmount : -newAmount;
        transaction.update(transactionRef, {'amount': signedAmount});

        if (transactionData!['cardId'] != null && currentCardData != null) {
          final cardRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(transactionData!['cardId']);

          final currentBalance = (currentCardData!['balance'] ?? 0.0).toDouble();

          double adjustedBalance = currentBalance;
          if (transactionType == 'income') {
            adjustedBalance -= oldAmount.abs(); // Remove old income
            adjustedBalance += newAmount; // Add new income
          } else {
            adjustedBalance += oldAmount.abs(); // Add back old expense
            adjustedBalance -= newAmount; // Subtract new expense
          }

          transaction.update(cardRef, {'balance': adjustedBalance});
        }
      });

      Navigator.pop(context); // Close calculator
      await _loadTransactionDetails(); // Reload data

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully'),
          backgroundColor: Colors.teal,
        ),
      );

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTransaction() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null || transactionData == null) return;

      final amount = (transactionData!['amount'] as num).toDouble();
      final transactionType = transactionData!['type'] ?? 'expense';

      // Get current card data before the transaction if it exists
      Map<String, dynamic>? currentCardData;
      if (transactionData!['cardId'] != null) {
        final cardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(transactionData!['cardId'])
            .get();

        if (cardDoc.exists) {
          currentCardData = cardDoc.data();
        }
      }

      await _firestore.runTransaction((transaction) async {
        // Delete the transaction
        final transactionRef = _firestore.collection('transactions').doc(widget.transactionId);
        transaction.delete(transactionRef);

        // Update card balance if cardId exists and we have card data
        if (transactionData!['cardId'] != null && currentCardData != null) {
          final cardRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(transactionData!['cardId']);

          final currentBalance = (currentCardData!['balance'] ?? 0.0).toDouble();

          // Reverse the transaction
          double newBalance = currentBalance;
          if (transactionType == 'income') {
            newBalance -= amount.abs(); // Remove income
          } else {
            newBalance += amount.abs(); // Add back expense
          }

          transaction.update(cardRef, {'balance': newBalance});
        }
      });

      Navigator.pop(context); // Go back to previous screen

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted successfully'),
          backgroundColor: Colors.teal,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      if (op == '+')
        result += num;
      else if (op == '-')
        result -= num;
      else if (op == '*')
        result *= num;
      else if (op == '/')
        result /= num;
    }
    return result;
  }

  Widget _buildCategoryIcon() {
    if (categoryData == null || categoryData!['icon'] == null) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Icon(Icons.category, color: Colors.white, size: 24),
      );
    }

    final iconString = categoryData!['icon'].toString();

    // Try to parse as integer (MaterialIcons codepoint)
    try {
      final iconCode = int.parse(iconString);
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(25),
        ),
        child: Icon(
          IconData(iconCode, fontFamily: 'MaterialIcons'),
          color: Colors.white,
          size: 24,
        ),
      );
    } catch (e) {
      // If it's not a number, it might be an emoji
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(25),
        ),
        alignment: Alignment.center,
        child: Text(
          iconString,
          style: const TextStyle(fontSize: 24),
        ),
      );
    }
  }

  // Helper method to get display name for transfer transactions
  String _getTransactionDisplayName() {
    final transactionType = transactionData?['type'] ?? '';

    switch (transactionType) {
      case 'transfer':
        return transactionData?['name'] ?? 'Card Transfer';
      case 'goal_deposit':
        return 'Goal Deposit';
      case 'goal_withdrawal':
        return 'Goal Withdrawal';
      default:
        return categoryData?['name'] ?? 'Unknown Category';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 0,
        centerTitle: true,
        title: const Text('Details', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  title: const Text(
                    'Delete Transaction',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Are you sure you want to delete this transaction?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteTransaction();
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // First Group - Main transaction info with icon and amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Category icon
                  _buildCategoryIcon(),
                  const SizedBox(height: 16),

                  // Transaction type/category name
                  Text(
                    _getTransactionDisplayName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Amount
                  Text(
                    'RM${(transactionData?['amount'] ?? 0.0).abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: (transactionData?['type'] ?? 'expense') == 'income'
                          ? Colors.green
                          : Colors.red,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Second Group - Horizontal Type and Expense/Income
            Row(
              children: [
                // Left container - Type
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.category,
                                color: Colors.orange,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Type',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getTransactionDisplayName(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Right container - Expense/Income
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: ((transactionData?['type'] ?? 'expense') == 'income'
                                    ? Colors.green
                                    : Colors.red).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                (transactionData?['type'] ?? 'expense') == 'income'
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                color: (transactionData?['type'] ?? 'expense') == 'income'
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              (transactionData?['type'] ?? 'expense') == 'income' ? 'Income' : 'Expenses',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(transactionData?['type'] ?? 'expense') == 'income' ? '+' : '-'}RM${(transactionData?['amount'] ?? 0.0).abs().toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Third Group - Date and Card details
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Date
                  _buildDetailRow(
                    icon: Icons.calendar_today,
                    iconColor: Colors.blue,
                    title: 'Date',
                    value: transactionData != null && transactionData!['timestamp'] != null
                        ? DateFormat('d MMM yyyy \'at\' HH:mm:ss').format(
                      (transactionData!['timestamp'] as Timestamp).toDate(),
                    )
                        : 'Unknown Date',
                    isFirst: true,
                  ),

                  // Card (only show if card data exists)
                  if (cardData != null)
                    _buildDetailRow(
                      icon: Icons.credit_card,
                      iconColor: Colors.green,
                      title: 'Cards',
                      value: cardData?['name'] ?? 'Unknown Card',
                      isLast: true,
                    ),

                  // If no card, make the date row the last one
                  if (cardData == null)
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleEditCalculator,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text(
          'Edit',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: isFirst ? BorderSide.none : BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}