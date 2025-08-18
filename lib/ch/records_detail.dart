import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'select_card_popup.dart'; // Make sure this import exists

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

  // Enhanced calculator variables
  String _calculatorInput = '0';
  double _calculatorResult = 0;
  bool _isCalculatorOpen = false;

  // Edit form variables (pre-filled from transaction data)
  String? _selectedCategoryId;
  Map<String, dynamic>? _selectedCard;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _type = 'expense';
  bool _inputInvalid = false;
  bool _saveAttempted = false;

  // Categories list
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadTransactionDetails();
  }

  Future<void> _loadCategories() async {
    try {
      final userId = _auth.currentUser?.uid;

      // Fetch all categories
      final allCategoriesSnapshot = await _firestore
          .collection('categories')
          .get();

      final categories = allCategoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'icon': data['icon'],
          'type': data['type'],
          'userId': data['userId'] ?? null,
        };
      }).toList();

      final filteredCategories = categories.where((cat) {
        final catUserId = cat['userId'];
        return catUserId == null ||
            catUserId == '' ||
            (userId != null && catUserId == userId);
      }).toList();

      setState(() {
        _categories = filteredCategories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
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
          categoryRef = _firestore
              .collection('categories')
              .doc(transactionInfo['category'] as String);
        }

        if (categoryRef != null) {
          final categoryDoc = await categoryRef.get();
          if (categoryDoc.exists) {
            categoryInfo = categoryDoc.data() as Map<String, dynamic>;
            categoryInfo['id'] = categoryDoc.id; // Add the ID to category data
          }
        }
      }

      // Get card details - handle multiple card scenarios
      Map<String, dynamic>? cardInfo;

      // First check if it's a regular manual transaction with cardId
      if (transactionInfo['cardId'] != null) {
        final cardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(transactionInfo['cardId'])
            .get();

        if (cardDoc.exists) {
          cardInfo = cardDoc.data();
          cardInfo!['id'] = cardDoc.id; // Add the ID to card data
        }
      }
      // For automated subscription transactions with fromCardId and fromCardName
      else if (transactionInfo['fromCardId'] != null) {
        // Try to get live card data
        final cardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(transactionInfo['fromCardId'])
            .get();

        if (cardDoc.exists) {
          cardInfo = cardDoc.data();
          cardInfo!['id'] = cardDoc.id;
        } else if (transactionInfo['fromCardName'] != null) {
          // Fallback to stored card name if card document doesn't exist
          cardInfo = {
            'id': transactionInfo['fromCardId'],
            'name': transactionInfo['fromCardName'],
            'balance': 0.0,
            // We can't get the current balance if card is deleted
          };
        }
      }
      // For automated income transactions with toCardId and toCardName
      else if (transactionInfo['toCardId'] != null) {
        // Try to get live card data
        final cardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(transactionInfo['toCardId'])
            .get();

        if (cardDoc.exists) {
          cardInfo = cardDoc.data();
          cardInfo!['id'] = cardDoc.id;
        } else if (transactionInfo['toCardName'] != null) {
          // Fallback to stored card name if card document doesn't exist
          cardInfo = {
            'id': transactionInfo['toCardId'],
            'name': transactionInfo['toCardName'],
            'balance': 0.0,
            // We can't get the current balance if card is deleted
          };
        }
      }

      // Load categories for editing
      await _loadCategories();

      // Pre-fill edit form variables
      final timestamp = transactionInfo['timestamp'] as Timestamp;
      final dateTime = timestamp.toDate();

      setState(() {
        transactionData = transactionInfo;
        categoryData = categoryInfo;
        cardData = cardInfo;

        // Pre-fill form fields
        _selectedCategoryId = categoryInfo?['id'];
        _selectedCard = cardInfo;
        _selectedDate = dateTime;
        _selectedTime = TimeOfDay.fromDateTime(dateTime);
        _type = transactionInfo['type'] ?? 'expense';

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
        // Reset any temporary states
        _inputInvalid = false;
        _saveAttempted = false;
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
                _calculatorInput = _calculatorInput.substring(
                  0,
                  _calculatorInput.length - 1,
                );
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

        // Get screen dimensions and calculate available height
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final statusBarHeight = MediaQuery.of(context).padding.top;
        final bottomSafeArea = MediaQuery.of(context).padding.bottom;

        // Calculate maximum available height for the modal
        final maxHeight =
            screenHeight -
            statusBarHeight -
            keyboardHeight -
            100; // 100px buffer

        // Calculate dynamic spacing and sizes
        final isSmallScreen = screenHeight < 700;
        final titleSize = isSmallScreen ? 18.0 : 20.0;
        final cardHeight = isSmallScreen ? 75.0 : 85.0;
        final buttonHeight = isSmallScreen ? 44.0 : 48.0;
        final gridSpacing = isSmallScreen ? 8.0 : 10.0;
        final verticalPadding = isSmallScreen ? 12.0 : 16.0;
        final sectionSpacing = isSmallScreen ? 8.0 : 12.0;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Color.fromRGBO(33, 35, 34, 1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: sectionSpacing * 0.75),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: verticalPadding * 0.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Edit Transaction',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: sectionSpacing),

                      // Type Toggle (Expense/Income)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[800]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _type = 'expense';
                                    // Update category selection based on type
                                    final expenseCategories = _categories
                                        .where(
                                          (cat) => cat['type'] == 'expense',
                                        )
                                        .toList();
                                    if (expenseCategories.isNotEmpty) {
                                      _selectedCategoryId =
                                          expenseCategories.first['id'];
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _type == 'expense'
                                        ? Colors.teal
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Expense',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _type == 'expense'
                                          ? Colors.white
                                          : Colors.white60,
                                      fontWeight: _type == 'expense'
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _type = 'income';
                                    // Update category selection based on type
                                    final incomeCategories = _categories
                                        .where((cat) => cat['type'] == 'income')
                                        .toList();
                                    if (incomeCategories.isNotEmpty) {
                                      _selectedCategoryId =
                                          incomeCategories.first['id'];
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _type == 'income'
                                        ? Colors.teal
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Income',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _type == 'income'
                                          ? Colors.white
                                          : Colors.white60,
                                      fontWeight: _type == 'income'
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: sectionSpacing),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category and Amount (Left side)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showCategorySelection(setState),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                height: cardHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800]?.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        _buildCategoryIcon(),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _getSelectedCategoryName(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Flexible(
                                      child: Text(
                                        'RM$_calculatorInput',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Card Selection (Right side)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectCard(setState),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                height: cardHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800]?.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedCard != null
                                          ? _selectedCard!['name']
                                          : 'Select Card',
                                      style: TextStyle(
                                        color: _selectedCard != null
                                            ? Colors.white
                                            : Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_selectedCard != null) ...[
                                      Text(
                                        'RM${(_selectedCard!['balance'] ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ] else ...[
                                      const Text(
                                        '(Optional)',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: sectionSpacing),

                      // Date and Time Row
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectDate(context, setState),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                      ).format(_selectedDate),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.teal,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _selectTime(context, setState),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedTime.format(context),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.access_time,
                                      color: Colors.teal,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: sectionSpacing),

                      // Error messages
                      if (_saveAttempted &&
                          (_calculatorInput == '0' ||
                              _calculatorInput == 'Error'))
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: sectionSpacing * 0.5,
                          ),
                          child: const Text(
                            'Please enter an amount before saving.',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),

                      if (_inputInvalid)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: sectionSpacing * 0.5,
                          ),
                          child: const Text(
                            'Please enter a valid amount.',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),

                      // Calculator Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          final buttonSize =
                              (availableWidth - (3 * gridSpacing)) / 4;

                          return GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: gridSpacing,
                            mainAxisSpacing: gridSpacing,
                            childAspectRatio: 1.0,
                            children: [
                              _buildCalcButton(
                                '7',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '8',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '9',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '/',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '4',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '5',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '6',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '*',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '1',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '2',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '3',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '-',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '.',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                '0',
                                (input) => _calculate(input, setState),
                              ),
                              _buildCalcButton(
                                'delete',
                                (input) => _calculate(input, setState),
                                icon: Icons.backspace,
                              ),
                              _buildCalcButton(
                                '+',
                                (input) => _calculate(input, setState),
                              ),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: sectionSpacing),

                      // Update button
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _saveAttempted = false;
                                  _inputInvalid = false;
                                });
                                _updateTransaction(
                                  _calculatorInput,
                                  _calculatorResult,
                                  setState,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                minimumSize: Size(0, buttonHeight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Update Transaction',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: bottomSafeArea > 0
                            ? bottomSafeArea * 0.8
                            : sectionSpacing,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectCard(StateSetter setState) async {
    final selectedCard = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectCardPopup(
        onCardSelected: (card) {
          Navigator.pop(context, card);
        },
      ),
    );

    if (selectedCard != null) {
      setState(() {
        _selectedCard = selectedCard;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, StateSetter setState) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year, 12, 31),
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
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
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

  void _showCategorySelection(StateSetter setState) {
    final filteredCategories = _categories
        .where((category) => category['type'] == _type)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Category',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredCategories.length,
                  itemBuilder: (context, index) {
                    final category = filteredCategories[index];
                    final isSelected = _selectedCategoryId == category['id'];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = category['id'];
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.teal.withOpacity(0.3)
                              : Colors.grey[800]?.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.teal
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCategoryIconFromData(category),
                            const SizedBox(height: 8),
                            Text(
                              category['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
    );
  }

  Widget _buildCategoryIconFromData(Map<String, dynamic> category) {
    final iconString = category['icon'].toString();

    // Try to parse as integer (MaterialIcons codepoint)
    try {
      final iconCode = int.parse(iconString);
      return Icon(
        IconData(iconCode, fontFamily: 'MaterialIcons'),
        color: Colors.white,
        size: 24,
      );
    } catch (e) {
      // If it's not a number, it might be an emoji or text
      if (iconString.length == 1 || iconString.length == 2) {
        // Likely an emoji
        return Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          child: Text(iconString, style: const TextStyle(fontSize: 20)),
        );
      } else {
        // Fallback to default icon
        return const Icon(Icons.category, color: Colors.white, size: 24);
      }
    }
  }

  String _getSelectedCategoryName() {
    if (_selectedCategoryId == null) return 'Select Category';

    final category = _categories.firstWhere(
      (cat) => cat['id'] == _selectedCategoryId,
      orElse: () => {'name': 'Unknown Category'},
    );

    return category['name'];
  }

  Future<void> _updateTransaction(
    String calculatorInput,
    double calculatorResult,
    StateSetter setState,
  ) async {
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

    if (calculatorInput == '0' ||
        calculatorInput == 'Error' ||
        calculatorResult.isNaN ||
        calculatorResult == 0) {
      setState(() {
        _inputInvalid = true;
      });
      return;
    }

    setState(() {
      _inputInvalid = false;
    });

    try {
      final oldAmount = (transactionData!['amount'] as num).toDouble();
      final oldType = transactionData!['type'] ?? 'expense';
      final oldCardId = transactionData!['cardId'];

      // Calculate signed amount based on new type
      final signedAmount = _type == 'income'
          ? calculatorResult
          : -calculatorResult;

      // Get current card data for both old and new cards
      Map<String, dynamic>? oldCardData;
      Map<String, dynamic>? newCardData;

      if (oldCardId != null) {
        final oldCardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(oldCardId)
            .get();
        if (oldCardDoc.exists) {
          oldCardData = oldCardDoc.data();
        }
      }

      if (_selectedCard != null && _selectedCard!['id'] != null) {
        final newCardDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(_selectedCard!['id'])
            .get();
        if (newCardDoc.exists) {
          newCardData = newCardDoc.data();
        }
      }

      await _firestore.runTransaction((transaction) async {
        final transactionRef = _firestore
            .collection('transactions')
            .doc(widget.transactionId);

        // Update transaction data
        final updateData = <String, dynamic>{
          'amount': signedAmount,
          'timestamp': Timestamp.fromDate(_selectedDate),
          'category': _firestore
              .collection('categories')
              .doc(_selectedCategoryId),
          'type': _type,
        };

        // Handle card changes
        if (_selectedCard != null && _selectedCard!['id'] != null) {
          updateData['cardId'] = _selectedCard!['id'];
        } else {
          updateData['cardId'] = FieldValue.delete();
        }

        transaction.update(transactionRef, updateData);

        // Update card balances
        // 1. Reverse the old transaction from old card
        if (oldCardId != null && oldCardData != null) {
          final oldCardRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(oldCardId);

          final currentBalance = (oldCardData['balance'] ?? 0.0).toDouble();
          double adjustedBalance = currentBalance;

          if (oldType == 'income') {
            adjustedBalance -= oldAmount.abs(); // Remove old income
          } else {
            adjustedBalance += oldAmount.abs(); // Add back old expense
          }

          transaction.update(oldCardRef, {'balance': adjustedBalance});
        }

        // 2. Apply new transaction to new card (if different from old card or no old card)
        if (_selectedCard != null &&
            _selectedCard!['id'] != null &&
            newCardData != null &&
            _selectedCard!['id'] != oldCardId) {
          final newCardRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(_selectedCard!['id']);

          final currentBalance = (newCardData['balance'] ?? 0.0).toDouble();
          double newBalance;

          if (_type == 'income') {
            newBalance = currentBalance + calculatorResult;
          } else {
            newBalance = currentBalance - calculatorResult;
          }

          transaction.update(newCardRef, {'balance': newBalance});
        } else if (_selectedCard != null &&
            _selectedCard!['id'] != null &&
            _selectedCard!['id'] == oldCardId &&
            oldCardData != null) {
          // Same card, but amount or type changed
          final cardRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(_selectedCard!['id']);

          // We already reversed the old transaction above, now apply the new one
          final currentBalance = (oldCardData['balance'] ?? 0.0).toDouble();
          double adjustedBalance = currentBalance;

          // Reverse old transaction (already done above, so get the current state)
          if (oldType == 'income') {
            adjustedBalance -= oldAmount.abs();
          } else {
            adjustedBalance += oldAmount.abs();
          }

          // Apply new transaction
          if (_type == 'income') {
            adjustedBalance += calculatorResult;
          } else {
            adjustedBalance -= calculatorResult;
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
        final transactionRef = _firestore
            .collection('transactions')
            .doc(widget.transactionId);
        transaction.delete(transactionRef);

        // Update card balance if cardId exists and we have card data
        if (transactionData!['cardId'] != null && currentCardData != null) {
          final cardRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(transactionData!['cardId']);

          final currentBalance = (currentCardData!['balance'] ?? 0.0)
              .toDouble();

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

  Widget _buildCalcButton(
    String text,
    Function(String) onPressed, {
    IconData? icon,
  }) {
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
    if (_selectedCategoryId == null) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.category, color: Colors.white, size: 16),
      );
    }

    final category = _categories.firstWhere(
      (cat) => cat['id'] == _selectedCategoryId,
      orElse: () => {'icon': null},
    );

    if (category['icon'] == null) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.category, color: Colors.white, size: 16),
      );
    }

    final iconString = category['icon'].toString();

    // Try to parse as integer (MaterialIcons codepoint)
    try {
      final iconCode = int.parse(iconString);
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          IconData(iconCode, fontFamily: 'MaterialIcons'),
          color: Colors.white,
          size: 16,
        ),
      );
    } catch (e) {
      // If it's not a number, it might be an emoji
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.orange[700],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(iconString, style: const TextStyle(fontSize: 16)),
      );
    }
  }

  Widget _buildDisplayCategoryIcon() {
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
        child: Text(iconString, style: const TextStyle(fontSize: 24)),
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
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.teal),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteTransaction();
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
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
                        _buildDisplayCategoryIcon(),
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
                            color:
                                (transactionData?['type'] ?? 'expense') ==
                                    'income'
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
                                      color:
                                          ((transactionData?['type'] ??
                                                          'expense') ==
                                                      'income'
                                                  ? Colors.green
                                                  : Colors.red)
                                              .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      (transactionData?['type'] ?? 'expense') ==
                                              'income'
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      color:
                                          (transactionData?['type'] ??
                                                  'expense') ==
                                              'income'
                                          ? Colors.green
                                          : Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (transactionData?['type'] ?? 'expense') ==
                                            'income'
                                        ? 'Income'
                                        : 'Expenses',
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
                          value:
                              transactionData != null &&
                                  transactionData!['timestamp'] != null
                              ? DateFormat('d MMM yyyy \'at\' HH:mm:ss').format(
                                  (transactionData!['timestamp'] as Timestamp)
                                      .toDate(),
                                )
                              : 'Unknown Date',
                          isFirst: true,
                        ),

                        // Card (show if any card data exists)
                        if (cardData != null)
                          _buildDetailRow(
                            icon: Icons.credit_card,
                            iconColor: Colors.green,
                            title: _getCardDisplayTitle(),
                            value: _getCardDisplayValue(),
                            isLast: true,
                          ),

                        // If no card, make the date row the last one
                        if (cardData == null) const SizedBox.shrink(),
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


  String _getCardDisplayTitle() {
    final transactionType = transactionData?['type'] ?? '';

    // For automated income transactions
    if (transactionData?.containsKey('incomeId') == true ||
        transactionData?.containsKey('toCardId') == true) {
      return 'Deposited to Card';
    }
    // For automated subscription transactions
    else if (transactionData?.containsKey('subscriptionId') == true ||
        transactionData?.containsKey('fromCardId') == true) {
      return 'Charged from Card';
    }
    // For manual transactions
    else {
      return 'Card';
    }
  }

  String _getCardDisplayValue() {
    if (cardData == null) return 'No Card';

    final cardName = cardData?['name'] ?? 'Unknown Card';
    final balance = cardData?['balance'];

    // Show balance only if we have current balance data (not for deleted cards)
    if (balance != null && balance != 0.0) {
      return '$cardName (RM${balance.toStringAsFixed(2)})';
    } else {
      return cardName;
    }
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
          top: isFirst
              ? BorderSide.none
              : BorderSide(color: Colors.grey[800]!, width: 0.5),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
