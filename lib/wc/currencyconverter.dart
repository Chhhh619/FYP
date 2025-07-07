import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  _CurrencyConverterScreenState createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  final _expensesCollection = FirebaseFirestore.instance.collection('expenses');
  final _userId = 'currentUserId'; // Placeholder for authenticated user ID
  List<Map<String, dynamic>> expenses = [];
  String _baseCurrency = 'MYR'; // Default to Malaysian Ringgit
  String _targetCurrency = 'MYR'; // Default to Malaysian Ringgit
  double _exchangeRate = 1.0; // Default, will be updated by API
  String _amountInput = ''; // For numpad input
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExchangeRate();
    _loadExpenses();
  }

  Future<void> _fetchExchangeRate() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.frankfurter.app/latest?from=$_baseCurrency&to=$_targetCurrency'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _exchangeRate = data['rates'][_targetCurrency] ?? 1.0;
        });
      } else {
        if (kDebugMode) print('Failed to fetch exchange rate: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching exchange rate: $e');
    }
  }

  Future<void> _loadExpenses() async {
    final snapshot = await _expensesCollection
        .where('userId', isEqualTo: _userId)
        .get();
    setState(() {
      expenses = snapshot.docs.map((doc) => {
        ...doc.data() as Map<String, dynamic>,
        'id': doc.id,
      }).toList();
    });
  }

  double _convertCurrency(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == _baseCurrency && toCurrency == _targetCurrency) {
      return amount * _exchangeRate;
    }
    return amount; // Default to original if unsupported
  }

  double _getCurrencyTrend(String currency) {
    switch (currency) {
      case 'MYR':
        return 0.01;
      case 'SGD':
        return -0.005;
      case 'THB':
        return 0.002;
      default:
        return 0.0;
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _baseCurrency;
      _baseCurrency = _targetCurrency;
      _targetCurrency = temp;
      _fetchExchangeRate();
    });
  }

  void _addDigit(String digit) {
    setState(() {
      _amountInput += digit;
    });
  }

  void _deleteDigit() {
    setState(() {
      if (_amountInput.isNotEmpty) {
        _amountInput = _amountInput.substring(0, _amountInput.length - 1);
      }
    });
  }

  Future<void> _addExpense() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountInput) ?? 0.0;
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid title and amount')),
      );
      return;
    }

    final convertedAmount = _convertCurrency(amount, _baseCurrency, _targetCurrency);
    await _expensesCollection.add({
      'userId': _userId,
      'title': title,
      'amount': amount,
      'originalCurrency': _baseCurrency,
      'convertedAmount': convertedAmount,
      'targetCurrency': _targetCurrency,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _titleController.clear();
    _amountInput = '';
    _loadExpenses();
  }

  void _showNumpad() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true, // Allows modal to adjust height
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(8.0), // Reduced padding
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4, // Limit to 40% of screen height
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _amountInput.isEmpty ? '0.00' : _amountInput,
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    childAspectRatio: 1.2, // Adjusts button size
                    crossAxisSpacing: 4.0, // Reduced spacing
                    mainAxisSpacing: 4.0, // Reduced spacing
                    children: [
                      for (var digit in ['7', '8', '9', '4', '5', '6', '1', '2', '3', '0', '.', '⌫'])
                        Padding(
                          padding: const EdgeInsets.all(2.0), // Reduced padding around buttons
                          child: ElevatedButton(
                            onPressed: digit == '⌫'
                                ? _deleteDigit
                                : () => _addDigit(digit),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6), // Slightly smaller radius
                              ),
                              padding: const EdgeInsets.all(8.0), // Reduced padding
                            ),
                            child: Text(
                              digit,
                              style: const TextStyle(color: Colors.black, fontSize: 16), // Smaller text
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.black, fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter', style: TextStyle(color: Colors.orange)),
        backgroundColor: Colors.black,
      ),
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Conversion Section
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Expense Title',
                        labelStyle: const TextStyle(color: Colors.orange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _showNumpad,
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          _amountInput.isEmpty ? 'Tap to enter amount' : _amountInput,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<String>(
                          value: _baseCurrency,
                          items: ['MYR', 'SGD', 'THB', 'JPY', 'KRW', 'USD', 'EUR', 'GBP']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: const TextStyle(color: Colors.orange)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _baseCurrency = newValue!;
                              _fetchExchangeRate();
                            });
                          },
                          dropdownColor: Colors.grey[900],
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                          onPressed: _swapCurrencies,
                        ),
                        DropdownButton<String>(
                          value: _targetCurrency,
                          items: ['MYR', 'SGD', 'THB', 'JPY', 'KRW', 'USD', 'EUR', 'GBP']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: const TextStyle(color: Colors.orange)),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _targetCurrency = newValue!;
                              _fetchExchangeRate();
                            });
                          },
                          dropdownColor: Colors.grey[900],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '1 $_baseCurrency = ${_exchangeRate.toStringAsFixed(4)} $_targetCurrency',
                      style: const TextStyle(color: Colors.orange, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Convert & Save', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Convert History
            Expanded(
              child: Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    final trend = _getCurrencyTrend(expense['originalCurrency']);
                    return ListTile(
                      title: Text(expense['title'], style: const TextStyle(color: Colors.white)),
                      subtitle: Text(
                        'Original: ${expense['amount']} ${expense['originalCurrency']}\n'
                            'Converted: ${expense['convertedAmount'].toStringAsFixed(2)} ${expense['targetCurrency']}\n'
                            'Trend (7 days): ${trend > 0 ? '+' : ''}${trend * 100}%',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}