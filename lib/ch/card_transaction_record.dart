import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/card_model.dart';

class CardTransactionPage extends StatefulWidget {
  final CardModel card;
  final String transactionType; // 'income' or 'expense'
  final Function(double) onTransactionSaved;

  const CardTransactionPage({
    super.key,
    required this.card,
    required this.transactionType,
    required this.onTransactionSaved,
  });

  @override
  _CardTransactionPageState createState() => _CardTransactionPageState();
}

class _CardTransactionPageState extends State<CardTransactionPage> {
  String _calculatorInput = '0';
  double _calculatorResult = 0;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _saveAttempted = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _descriptionController.text = widget.transactionType == 'income'
        ? 'Money added to ${widget.card.name}'
        : 'Expense from ${widget.card.name}';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final userId = _auth.currentUser?.uid;

    try {
      final allCategoriesSnapshot = await _firestore
          .collection('categories')
          .get();

      setState(() {
        _categories = allCategoriesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'icon': data['icon'],
            'type': data['type'],
            'userId': data['userId'] ?? data['userid'] ?? null,
          };
        }).toList();

        // Filter for appropriate categories
        final filteredCategories = _categories.where((cat) {
          final catUserId = cat['userId'];
          final isUserCategory = catUserId == null || catUserId == '' ||
              (userId != null && catUserId == userId);
          final isCorrectType = cat['type'] == widget.transactionType;
          return isUserCategory && isCorrectType;
        }).toList();

        _categories = filteredCategories;

        if (_categories.isNotEmpty) {
          _selectedCategoryId = _categories.first['id'];
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime
          .now()
          .year, 12, 31),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData(
            primaryColor: Colors.teal,
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              surface: Color.fromRGBO(33, 35, 34, 1),
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.teal),
            ),
            dialogBackgroundColor: Color.fromRGBO(33, 35, 34, 1),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.teal,
              onSurface: Colors.white,
              surface: const Color.fromRGBO(33, 35, 34, 1),
            ),
            dialogBackgroundColor: const Color.fromRGBO(33, 35, 34, 1),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _calculate(String input) {
    setState(() {
      if (input == '.') {
        final parts = _calculatorInput.split(RegExp(r'[\+\-\*/]'));
        final lastNumber = parts.isNotEmpty ? parts.last.trim() : '';
        if (!lastNumber.contains('.')) {
          _calculatorInput += '.';
        }
      } else if (input == 'delete') {
        if (_calculatorInput.length > 1) {
          _calculatorInput =
              _calculatorInput.substring(0, _calculatorInput.length - 1);
        } else {
          _calculatorInput = '0';
        }
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
        _calculatorInput =
        _calculatorInput == '0' ? input : _calculatorInput + input;
      }
    });
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
      else if (op == '/') result /= num;
    }
    return result;
  }

  Future<void> _saveTransaction() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _selectedCategoryId == null) {
      setState(() {
        _saveAttempted = true;
      });
      return;
    }

    try {
      _calculatorResult = _evaluateExpression(_calculatorInput);
    } catch (_) {
      _calculatorResult = double.nan;
    }

    if (_calculatorInput == '0' || _calculatorInput == 'Error' ||
        _calculatorResult.isNaN || _calculatorResult == 0) {
      setState(() {
        _saveAttempted = true;
      });
      return;
    }

    final amount = _calculatorResult;
    final isIncome = widget.transactionType == 'income';

    // Check if expense exceeds card balance
    if (!isIncome && amount > widget.card.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Insufficient balance. Available: RM${widget.card.balance
                  .toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _saveAttempted = false;
    });

    try {
      await _firestore.runTransaction((txn) async {
        // Update card balance
        final cardRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(widget.card.id);

        final cardDoc = await txn.get(cardRef);
        if (!cardDoc.exists) {
          throw Exception('Card not found');
        }

        final currentBalance = (cardDoc.data()!['balance'] ?? 0.0).toDouble();
        final newBalance = isIncome ? currentBalance + amount : currentBalance -
            amount;

        txn.update(cardRef, {'balance': newBalance});

        // Create transaction record
        final transactionRef = _firestore.collection('transactions').doc();
        txn.set(transactionRef, {
          'userid': userId,
          'amount': amount,
          'timestamp': Timestamp.fromDate(_selectedDate),
          'cardId': widget.card.id,
          'type': widget.transactionType,
          'description': _descriptionController.text.trim(),
          'category': _firestore.collection('categories').doc(
              _selectedCategoryId),
        });

        // Call the callback with new balance
        widget.onTransactionSaved(newBalance);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${isIncome ? 'Money added' : 'Expense recorded'} successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      print('Transaction error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save transaction: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCalcButton(String text, {IconData? icon}) {
    return ElevatedButton(
      onPressed: () => _calculate(text),
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

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.transactionType == 'income';

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isIncome ? 'Add Money' : 'Record Expense',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    color: Colors.teal,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.card.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Balance: RM${widget.card.balance.toStringAsFixed(
                              2)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Amount Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'RM $_calculatorInput',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_saveAttempted) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Please enter a valid amount',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal),
                ),
                filled: true,
                fillColor: Colors.grey[850],
              ),
            ),

            const SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () => _selectDate(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text(
                            DateFormat('d MMM yyyy').format(_selectedDate)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () => _selectTime(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Calculator
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildCalcButton('7'),
                _buildCalcButton('8'),
                _buildCalcButton('9'),
                _buildCalcButton('/'),
                _buildCalcButton('4'),
                _buildCalcButton('5'),
                _buildCalcButton('6'),
                _buildCalcButton('*'),
                _buildCalcButton('1'),
                _buildCalcButton('2'),
                _buildCalcButton('3'),
                _buildCalcButton('-'),
                _buildCalcButton('0'),
                _buildCalcButton('.'),
                _buildCalcButton('='),
                _buildCalcButton('+'),
                _buildCalcButton('delete', icon: Icons.backspace),
              ],
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isIncome ? 'Add Money' : 'Record Expense',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}