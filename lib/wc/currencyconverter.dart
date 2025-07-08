import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  _CurrencyConverterScreenState createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  String _baseCurrency = 'MYR'; // Default to Malaysian Ringgit
  String _targetCurrency = 'USD'; // Default to USD for Google-like experience
  double _exchangeRate = 1.0; // Default, will be updated by API
  String _amountInput = ''; // For user input
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExchangeRate();
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

  double _convertCurrency(double amount) {
    return amount * _exchangeRate;
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _baseCurrency;
      _baseCurrency = _targetCurrency;
      _targetCurrency = temp;
      _fetchExchangeRate();
    });
  }

  void _updateAmount(String value) {
    setState(() {
      _amountInput = value;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double convertedAmount = _amountInput.isEmpty
        ? 0.0
        : _convertCurrency(double.tryParse(_amountInput) ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: const TextStyle(color: Colors.white),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      onChanged: _updateAmount,
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
                              child: Text(value, style: const TextStyle(color: Colors.white)),
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
                          icon: Icon(Icons.swap_horiz, color: const Color(0xFFB0BEC5)),
                          onPressed: _swapCurrencies,
                        ),
                        DropdownButton<String>(
                          value: _targetCurrency,
                          items: ['MYR', 'SGD', 'THB', 'JPY', 'KRW', 'USD', 'EUR', 'GBP']
                              .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, style: const TextStyle(color: Colors.white)),
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
                      style: TextStyle(color: const Color(0xFFB0BEC5), fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Converted: ${convertedAmount.toStringAsFixed(2)} $_targetCurrency',
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                color: Colors.grey[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: CustomPaint(
                  painter: ExchangeRateChart(_exchangeRate),
                  child: Center(
                    child: Text(
                      'Exchange Rate Trend (Simulated)',
                      style: TextStyle(color: const Color(0xFFB0BEC5), fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for a simple line chart
class ExchangeRateChart extends CustomPainter {
  final double currentRate;

  ExchangeRateChart(this.currentRate);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Simulate 5 data points for a trend (e.g., last 5 days)
    final List<double> rates = [
      currentRate * 0.98, // -2%
      currentRate * 0.99, // -1%
      currentRate,
      currentRate * 1.01, // +1%
      currentRate * 1.02, // +2%
    ];

    final double step = size.width / (rates.length - 1);
    final double maxRate = rates.reduce((a, b) => a > b ? a : b);
    final double minRate = rates.reduce((a, b) => a < b ? a : b);
    final double range = maxRate - minRate;

    final path = Path();
    for (int i = 0; i < rates.length; i++) {
      final x = i * step;
      final y = size.height - ((rates[i] - minRate) / (range > 0 ? range : 1) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw axes
    canvas.drawLine(Offset(0, size.height), Offset(0, 0), paint..color = const Color(0xFF90A4AE));
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint..color = const Color(0xFF90A4AE));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}