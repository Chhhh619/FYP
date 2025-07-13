import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:draggable_widget/draggable_widget.dart';
import 'package:draggable_widget/model/anchor_docker.dart'; // For AnchoringPosition

class RecordTransactionPage extends StatefulWidget {
  const RecordTransactionPage({super.key});

  @override
  _RecordTransactionPageState createState() => _RecordTransactionPageState();
}

class _RecordTransactionPageState extends State<RecordTransactionPage> {
  final _amountController = TextEditingController();
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String _type = 'expense'; // Default to expense
  String _calculatorInput = '0';
  double _calculatorResult = 0;
  bool _isCalculatorOpen = false;
  final DragController _dragController = DragController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    setState(() {
      _categories = snapshot.docs.map((doc) => {
        'id': doc.id, // Use Firestore document ID as the category ID
        'name': doc['name'],
        'icon': doc['icon'],
        'type': doc['type'], // Type is exclusive to categories
      }).toList();
      if (_categories.isNotEmpty) {
        // Set initial selected category to the first matching the default type
        final defaultCategory = _categories.firstWhere((cat) => cat['type'] == _type, orElse: () => _categories.first);
        _selectedCategoryId = defaultCategory['id'];
      }
    });
  }

  void _saveTransaction() {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated or no category selected.')),
      );
      return;
    }
    _firestore
        .collection('transactions')
        .add({
      'userid': userId,
      'amount': double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0,
      'timestamp': Timestamp.fromDate(_selectedDate),
      'category': _firestore.collection('categories').doc(_selectedCategoryId), // Reference determines type
    })
        .then((value) {
      Navigator.pop(context);
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $error')),
      );
    });
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(33, 35, 34, 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Date',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 210,
                      child: GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: List.generate(12, (index) {
                          final month = DateTime(_selectedDate.year, index + 1);
                          return ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedDate = DateTime(_selectedDate.year, index + 1, _selectedDate.day);
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(60, 60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: _selectedDate.month == index + 1 ? Colors.teal : const Color.fromRGBO(33, 35, 34, 1),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(DateFormat('MMM').format(month)),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime(_selectedDate.year - 1, _selectedDate.month, _selectedDate.day);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Previous Year'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedDate = DateTime(_selectedDate.year + 1, _selectedDate.month, _selectedDate.day);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Next Year'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, _selectedDate);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _calculate(String input) {
    setState(() {
      if (input == 'C') {
        _calculatorInput = '0';
        _calculatorResult = 0;
      } else if (input == '=') {
        try {
          _calculatorResult = _evaluateExpression(_calculatorInput);
          _calculatorInput = _calculatorResult.toString();
          _amountController.text = _calculatorResult.toString();
        } catch (e) {
          _calculatorInput = 'Error';
        }
      } else if (['+', '-', '*', '/'].contains(input)) {
        _calculatorInput += ' $input ';
      } else {
        _calculatorInput = _calculatorInput == '0' ? input : _calculatorInput + input;
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
      if (op == '+') result += num;
      else if (op == '-') result -= num;
      else if (op == '*') result *= num;
      else if (op == '/') result /= num;
    }
    return result;
  }

  void _toggleCalculator() {
    setState(() {
      _isCalculatorOpen = !_isCalculatorOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.where((category) => category['type'] == _type).toList();

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
        title: const Text('Record Transaction', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount (RM)',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: const Color.fromRGBO(33, 35, 34, 1),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Category',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: filteredCategories.map((category) {
                      return ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategoryId = category['id'];
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                          backgroundColor: _selectedCategoryId == category['id'] ? Colors.teal : const Color.fromRGBO(33, 35, 34, 1),
                          foregroundColor: Colors.white,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              category['icon'],
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category['name'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: _type,
                      items: ['expense', 'income'].map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type[0].toUpperCase() + type.substring(1), style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _type = newValue ?? 'expense';
                          // Reset selected category to the first of the new type, if any
                          final newDefault = filteredCategories.isNotEmpty ? filteredCategories.first['id'] : null;
                          _selectedCategoryId = newDefault;
                        });
                      },
                      dropdownColor: const Color.fromRGBO(33, 35, 34, 1),
                      style: const TextStyle(color: Colors.white),
                    ),
                    ElevatedButton(
                      onPressed: () => _selectDate(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(DateFormat('d MMM').format(_selectedDate)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saveTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Save Transaction', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          if (_isCalculatorOpen)
            Positioned(
              left: 50,
              top: 300,
              child: DraggableWidget(
                dragController: _dragController,
                initialPosition: AnchoringPosition.topLeft, // Default position, adjusted by Positioned
                child: Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(33, 35, 34, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.teal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Calculator', style: TextStyle(color: Colors.white, fontSize: 18)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: _toggleCalculator,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                _calculatorInput,
                                style: const TextStyle(color: Colors.white, fontSize: 24),
                                textAlign: TextAlign.right,
                              ),
                              Expanded(
                                child: GridView.count(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                  children: [
                                    for (var button in ['7', '8', '9', '/'])
                                      ElevatedButton(
                                        onPressed: () => _calculate(button),
                                        child: Text(button, style: const TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(50, 50, 50, 1)),
                                      ),
                                    for (var button in ['4', '5', '6', '*'])
                                      ElevatedButton(
                                        onPressed: () => _calculate(button),
                                        child: Text(button, style: const TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(50, 50, 50, 1)),
                                      ),
                                    for (var button in ['1', '2', '3', '-'])
                                      ElevatedButton(
                                        onPressed: () => _calculate(button),
                                        child: Text(button, style: const TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(50, 50, 50, 1)),
                                      ),
                                    for (var button in ['0', '.', '=', '+'])
                                      ElevatedButton(
                                        onPressed: () => _calculate(button),
                                        child: Text(button, style: const TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(50, 50, 50, 1)),
                                      ),
                                    ElevatedButton(
                                      onPressed: () => _calculate('C'),
                                      child: const Text('C', style: TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromRGBO(50, 50, 50, 1)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleCalculator,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.calculate, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}