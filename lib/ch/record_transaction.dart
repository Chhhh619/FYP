import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'categories_list.dart';
import 'category_grid.dart';
import 'select_card_popup.dart';
import 'package:fyp/wc/gamification_service.dart';

class RecordTransactionPage extends StatefulWidget {
  const RecordTransactionPage({super.key});

  @override
  _RecordTransactionPageState createState() => _RecordTransactionPageState();
}

class _RecordTransactionPageState extends State<RecordTransactionPage> {
  bool _inputInvalid = false;
  String? _saveErrorMessage;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _calculatorInput = '0';
  double _calculatorResult = 0;
  final _controller = PageController();
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  String _type = 'expense';
  bool _isCalculatorOpen = false;
  int _currentPage = 0;
  Map<String, dynamic>? _selectedCard;
  bool _isSaving = false;


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GamificationService _gamificationService = GamificationService();

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
          'userId': data['userId'] ?? null,
        };
      }).toList();

      final filteredCategories = _categories.where((cat) {
        final catUserId = cat['userId'];
        return catUserId == null ||
            catUserId == '' ||
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

  Future<void> _selectCard() async {
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

  void _saveTransaction(
      String calculatorInput,
      double calculatorResult,
      StateSetter setState,
      ) async {

    // PREVENT MULTIPLE SUBMISSIONS
    if (_isSaving) {
      print('Transaction already in progress, ignoring duplicate request');
      return;
    }

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
        _saveErrorMessage = null;
      });
      return;
    }

    // SET LOADING STATE
    setState(() {
      _inputInvalid = false;
      _saveErrorMessage = null;
      _isSaving = true; // Start loading
    });

    try {
      // Create the base transaction data with proper validation
      final transactionData = <String, dynamic>{
        'userId': userId,
        'amount': calculatorResult,
        'timestamp': Timestamp.fromDate(_selectedDate),
        'category': _firestore.collection('categories').doc(_selectedCategoryId),
        'type': _type,
      };

      // Only add cardId if a card is selected
      if (_selectedCard != null && _selectedCard!['id'] != null) {
        transactionData['cardId'] = _selectedCard!['id'];
      }

      await _firestore.runTransaction((transaction) async {
        // Create the transaction document
        final transactionRef = _firestore.collection('transactions').doc();

        // If a card is selected, update card balance
        if (_selectedCard != null && _selectedCard!['id'] != null) {
          // Get the card reference
          final cardRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(_selectedCard!['id']);

          // Read current card data
          final cardDoc = await transaction.get(cardRef);
          if (!cardDoc.exists) {
            throw Exception('Card not found');
          }

          final cardData = cardDoc.data();
          if (cardData == null) {
            throw Exception('Card data is null');
          }

          final currentBalance = (cardData['balance'] ?? 0.0).toDouble();
          double newBalance;

          // Calculate new balance based on transaction type
          if (_type == 'income') {
            newBalance = currentBalance + calculatorResult;
          } else {
            // expense
            newBalance = currentBalance - calculatorResult;

            // Check for sufficient balance (optional - remove if you want to allow negative balances)
            if (newBalance < 0) {
              throw Exception(
                'Insufficient balance in ${_selectedCard!['name']}',
              );
            }
          }

          // Update card balance
          transaction.update(cardRef, {'balance': newBalance});
        }

        // Set the transaction
        transaction.set(transactionRef, transactionData);
      });

      // Update local card balance if card was selected
      if (_selectedCard != null) {
        setState(() {
          if (_type == 'income') {
            _selectedCard!['balance'] =
                (_selectedCard!['balance'] ?? 0.0) + calculatorResult;
          } else {
            _selectedCard!['balance'] =
                (_selectedCard!['balance'] ?? 0.0) - calculatorResult;
          }
        });
      }

      setState(() {
        _isSaving = false;
      });

      // UPDATE CHALLENGES IN BACKGROUND (non-blocking)
      _updateChallengesInBackground();

      // FIXED NAVIGATION - Instead of popUntil, use proper navigation
      if (!mounted) return;

      // Close the modal first
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction saved successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Then navigate back to homepage with a slight delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Use pushNamedAndRemoveUntil to ensure we go to home properly
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
                (route) => false,
          );
        }
      });

    } catch (error) {
      // RESET LOADING STATE ON ERROR
      setState(() {
        _isSaving = false;
      });

      String errorMessage;
      print('Transaction error: $error'); // Debug logging

      if (error.toString().contains('Insufficient balance')) {
        errorMessage = error.toString();
      } else if (error.toString().contains('Permission denied')) {
        errorMessage = 'Permission denied. Please check your account permissions.';
      } else if (error.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Failed to save transaction. Please try again.';
      }

      // Close modal and show error
      Navigator.of(context).pop();

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  void _updateChallengesInBackground() {
    // Run in background without awaiting or blocking UI
    Future.microtask(() async {
      try {
        print('Starting background challenge update...');
        await _gamificationService.checkAndUpdateChallenges();
        print('Background challenge update completed');
      } catch (e) {
        print('Background challenge update failed: $e');
        // Don't show error to user since this is background operation
      }
    });
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

  void _toggleCalculator() {
    if (_isCalculatorOpen) return;
    _isCalculatorOpen = true;

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
        final maxHeight = screenHeight - statusBarHeight - keyboardHeight - 100; // 100px buffer

        // Calculate dynamic spacing and sizes
        final isSmallScreen = screenHeight < 700;
        final titleSize = isSmallScreen ? 18.0 : 20.0;
        final cardHeight = isSmallScreen ? 75.0 : 85.0;
        final buttonHeight = isSmallScreen ? 44.0 : 48.0;
        final gridSpacing = isSmallScreen ? 8.0 : 10.0;
        final verticalPadding = isSmallScreen ? 12.0 : 16.0;
        final sectionSpacing = isSmallScreen ? 8.0 : 12.0;

        return Container(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
          ),
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category and Amount (Left side)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              height: cardHeight,
                              decoration: BoxDecoration(
                                color: Colors.grey[800]?.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (_selectedCategoryId != null) ...[
                                    Row(
                                      children: [
                                        _buildCategoryIcon(),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _categories.firstWhere((cat) => cat['id'] == _selectedCategoryId)['name'],
                                            style: const TextStyle(color: Colors.white, fontSize: 16),
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
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Card Selection (Right side)
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final card = await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder: (context) => SelectCardPopup(
                                    onCardSelected: (card) {
                                      Navigator.pop(context, card);
                                    },
                                  ),
                                );
                                if (card != null) {
                                  setState(() {
                                    _selectedCard = card;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                height: cardHeight,
                                decoration: BoxDecoration(
                                  color: Colors.grey[800]?.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.teal.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('d MMM yyyy').format(_selectedDate),
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                    const Icon(Icons.calendar_today, color: Colors.teal, size: 16),
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
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.teal.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedTime.format(context),
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                    ),
                                    const Icon(Icons.access_time, color: Colors.teal, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: sectionSpacing),

                      // Error messages
                      if (_saveAttempted && (_calculatorInput == '0' || _calculatorInput == 'Error'))
                        Padding(
                          padding: EdgeInsets.only(bottom: sectionSpacing * 0.5),
                          child: const Text(
                            'Please enter an amount before saving.',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),

                      if (_inputInvalid)
                        Padding(
                          padding: EdgeInsets.only(bottom: sectionSpacing * 0.5),
                          child: const Text(
                            'Please enter a valid amount.',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),

                      // Calculator Grid - with constrained height
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          final buttonSize = (availableWidth - (3 * gridSpacing)) / 4;

                          return GridView.count(
                            crossAxisCount: 4,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: gridSpacing,
                            mainAxisSpacing: gridSpacing,
                            childAspectRatio: 1.0,
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
                              _buildCalcButton('.', (input) => _calculate(input, setState)),
                              _buildCalcButton('0', (input) => _calculate(input, setState)),
                              _buildCalcButton(
                                'delete',
                                    (input) => _calculate(input, setState),
                                icon: Icons.backspace,
                              ),
                              _buildCalcButton('+', (input) => _calculate(input, setState)),
                            ],
                          );
                        },
                      ),
// Replace your current Add button with this centered version:

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () {
                                setState(() {
                                  _saveAttempted = false;
                                  _inputInvalid = false;
                                });
                                _saveTransaction(
                                  _calculatorInput,
                                  _calculatorResult,
                                  setState,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSaving ? Colors.grey : Colors.teal,
                                foregroundColor: Colors.white,
                                minimumSize: Size(0, buttonHeight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isSaving
                                  ? Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              )
                                  : Text(
                                'Add',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),                      SizedBox(height: bottomSafeArea > 0 ? bottomSafeArea * 0.8 : sectionSpacing),
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

  Widget _buildCategoryIcon() {
    if (_selectedCategoryId == null) {
      return const Icon(Icons.category, color: Colors.white, size: 24);
    }

    final category = _categories.firstWhere((cat) => cat['id'] == _selectedCategoryId);
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
          child: Text(
            iconString,
            style: const TextStyle(fontSize: 20),
          ),
        );
      } else {
        // Fallback to default icon
        return const Icon(Icons.category, color: Colors.white, size: 24);
      }
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
        print(
          'Selected category for $_type: ${filteredCategories.first['name']}',
        );
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
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Container(
          color: const Color.fromRGBO(28, 28, 28, 1),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 38.0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
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
                          color: Colors.white,
                          fontSize: 18,
                        ),
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
                  categories: _categories
                      .where((cat) => cat['type'] == 'expense')
                      .toList(),
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
                  categories: _categories
                      .where((cat) => cat['type'] == 'income')
                      .toList(),
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