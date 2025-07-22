import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'categories_list.dart';
import 'category_grid.dart';
import 'budget_calculator_bottom_sheet.dart'; //

class RecordTransactionPage extends StatefulWidget {
  const RecordTransactionPage({super.key});

  @override
  _RecordTransactionPageState createState() => _RecordTransactionPageState();
}

class _RecordTransactionPageState extends State<RecordTransactionPage> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _calculatorInput = '0';
  double _calculatorResult = 0;
  final _controller = PageController();
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String _type = 'expense';
  bool _isCalculatorOpen = false;
  int _currentPage = 0;

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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final userId = _auth.currentUser?.uid;

    // Fetch all categories
    final allCategoriesSnapshot = await _firestore
        .collection('categories')
        .get();
    print('Total categories fetched: ${allCategoriesSnapshot.docs.length}');

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

      // Filter for prebuilt (userId is null or '') and custom (userId matches current user)
      final filteredCategories = _categories.where((cat) {
        final catUserId = cat['userId'];
        return catUserId == null || catUserId == '' ||
            (userId != null && catUserId == userId);
      }).toList();
      _categories = filteredCategories;
      print('Filtered categories count: ${_categories.length}');

      if (_categories.isNotEmpty) {
        final defaultCategory = _categories.firstWhere(
              (cat) => cat['type'] == _type,
          orElse: () => _categories.first,
        );
        _selectedCategoryId = defaultCategory['id'];
        print('Default category selected: ${defaultCategory['name']}');
      } else {
        print('No categories found after filtering.');
      }
    });
  }

  bool _saveAttempted = false;

  void _saveTransaction(String calculatorInput, double calculatorResult,
      StateSetter setState) {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _selectedCategoryId == null) {
      setState(() {
        _saveAttempted = true;
      });
      return;
    }

    try {
      calculatorResult = _evaluateExpression(calculatorInput);
    } catch (_) {
      calculatorResult = double.nan;
    }

    if (calculatorInput == '0' || calculatorInput == 'Error' ||
        calculatorResult.isNaN || calculatorResult == 0) {
      setState(() {
        _saveAttempted = true;
      });
      return;
    }

    setState(() {
      _saveAttempted = false;
    });

    _firestore
        .collection('transactions')
        .add({
      'userid': userId,
      'amount': calculatorResult,
      'timestamp': Timestamp.fromDate(_selectedDate),
      'category': _firestore.collection('categories').doc(_selectedCategoryId),
    })
        .then((value) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    })
        .catchError((error) {
      setState(() {
        _saveAttempted = true;
      });
    });
  }

  Future<void> _selectDate(BuildContext context, StateSetter setState) async {
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

  Future<void> _selectTime(BuildContext context, StateSetter setState) async {
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

  void _toggleCalculator() {
    if (_isCalculatorOpen) return;
    _isCalculatorOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery
              .of(context)
              .viewInsets
              .bottom),
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
        void _calculate(String input, StateSetter setState) {
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
                    'Transaction Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedCategoryId != null)
                    Text(
                      'Category: ${_categories.firstWhere((cat) =>
                      cat['id'] == _selectedCategoryId)['name']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _calculatorInput,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date', style: TextStyle(
                                  color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 4),
                              ElevatedButton(
                                onPressed: () => _selectDate(context, setState),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(80, 36),
                                ),
                                child: Text(
                                    DateFormat('d MMM').format(_selectedDate)),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Time', style: TextStyle(
                                  color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 4),
                              ElevatedButton(
                                onPressed: () => _selectTime(context, setState),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(80, 36),
                                ),
                                child: Text(_selectedTime.format(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_saveAttempted)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please enter an amount before saving.',
                        style: TextStyle(color: Colors.red, fontSize: 14),
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
                children: [
                  _buildCalcButton('7', (input) => _calculate(input, setState)),
                  _buildCalcButton('8', (input) => _calculate(input, setState)),
                  _buildCalcButton('9', (input) => _calculate(input, setState)),
                  _buildCalcButton('/', (input) => _calculate(input, setState)),
                  _buildCalcButton('4', (input) => _calculate(input, setState)),
                  _buildCalcButton('5', (input) => _calculate(input, setState)),
                  _buildCalcButton('6', (input) => _calculate(input, setState)),
                  _buildCalcButton('*', (input) => _calculate(input, setState)),
                  _buildCalcButton('1', (input) => _calculate(input, setState)),
                  _buildCalcButton('2', (input) => _calculate(input, setState)),
                  _buildCalcButton('3', (input) => _calculate(input, setState)),
                  _buildCalcButton('-', (input) => _calculate(input, setState)),
                  _buildCalcButton('0', (input) => _calculate(input, setState)),
                  _buildCalcButton('.', (input) => _calculate(input, setState)),
                  _buildCalcButton('=', (input) => _calculate(input, setState)),
                  _buildCalcButton('+', (input) => _calculate(input, setState)),
                  _buildCalcButton(
                      'delete', (input) => _calculate(input, setState),
                      icon: Icons.backspace),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _saveAttempted = false;
                  });
                  _saveTransaction(
                      _calculatorInput, _calculatorResult, setState);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Transaction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalcButton(String text, Function(String) onPressed,
      {IconData? icon}) {
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
          : Text(
        text,
        style: const TextStyle(fontSize: 20),
      ),
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
      else if (op == '/') result /= num;
    }
    return result;
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _type = index == 0 ? 'expense' : 'income';
      final filteredCategories = _categories
          .where((cat) => cat['type'] == _type)
          .toList();
      print('Filtered categories for $_type: ${filteredCategories.length}');
      if (filteredCategories.isNotEmpty) {
        _selectedCategoryId = filteredCategories.first['id'];
        print('Selected category for $_type: ${filteredCategories
            .first['name']}');
      } else {
        _selectedCategoryId = null;
        print('No categories found for $_type.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories
        .where((category) => category['type'] == _type)
        .toList();

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 0),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          color: const Color.fromRGBO(28, 28, 28, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 38.0,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _currentPage == 0 ? 'Expenses' : 'Income',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SmoothPageIndicator(
                      controller: _controller,
                      count: 2,
                      effect: const WormEffect(
                        dotColor: Colors.grey,
                        activeDotColor: Colors.teal,
                        dotHeight: 6,
                        dotWidth: 6,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 38.0,
                child: IconButton(
                  icon: const Icon(Icons.category, color: Colors.white),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoriesListPage(),
                      ),
                    );

                    // Reload categories after returning from category list
                    setState(() {
                      _loadCategories();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: filteredCategories.isEmpty
                ? Center(
              child: Text(
                'No categories available.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
                : PageView(
              onPageChanged: _onPageChanged,
              controller: _controller,
              children: [
                CategoryGrid(
                  categories: _categories.where((cat) => cat['type'] == 'expense').toList(),
                  selectedCategoryId: _selectedCategoryId,
                  onCategorySelected: (id) {
                    setState(() {
                      _selectedCategoryId = id;
                      _type = 'expense';
                      _currentPage = 0;
                    });
                  },
                ),
                CategoryGrid(
                  categories: _categories.where((cat) => cat['type'] == 'income').toList(),
                  selectedCategoryId: _selectedCategoryId,
                  onCategorySelected: (id) {
                    setState(() {
                      _selectedCategoryId = id;
                      _type = 'income';
                      _currentPage = 1;
                    });
                  },
                ),
              ],
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