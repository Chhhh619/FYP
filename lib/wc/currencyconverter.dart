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
  String _baseCurrency = 'MYR';
  String _targetCurrency = 'USD';
  double _exchangeRate = 0.24;
  String _amountInput = '1';
  final _amountController = TextEditingController();
  String _lastUpdated = '';
  String _selectedTimePeriod = '1D';
  List<Map<String, dynamic>> _historicalRates = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = _amountInput;
    _fetchExchangeRate();
    _fetchHistoricalData();
  }

  Future<void> _fetchExchangeRate() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.frankfurter.app/latest?from=$_baseCurrency&to=$_targetCurrency'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _exchangeRate = data['rates'][_targetCurrency] ?? 0.24;
          _lastUpdated = _formatDate(DateTime.now());
        });
      } else {
        if (kDebugMode) print('Failed to fetch exchange rate: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching exchange rate: $e');
    }
  }

  Future<void> _fetchHistoricalData() async {
    setState(() => _isLoadingHistory = true);

    final endDate = DateTime.now();
    final startDate = _getStartDateBasedOnPeriod(_selectedTimePeriod);
    final formattedStart = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
    final formattedEnd = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

    try {
      final response = await http.get(Uri.parse(
          'https://api.frankfurter.app/$formattedStart..$formattedEnd?from=$_baseCurrency&to=$_targetCurrency'
      ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;

        setState(() {
          _historicalRates = rates.entries.map((entry) {
            return {
              'date': DateTime.parse(entry.key),
              'rate': (entry.value as Map<String, dynamic>)[_targetCurrency],
            };
          }).toList()
            ..sort((a, b) => a['date'].compareTo(b['date']));
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching historical data: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  DateTime _getStartDateBasedOnPeriod(String period) {
    final now = DateTime.now();
    switch (period) {
      case '5D': return now.subtract(const Duration(days: 5));
      case '1M': return DateTime(now.year, now.month - 1, now.day);
      case '1Y': return DateTime(now.year - 1, now.month, now.day);
      case '5Y': return DateTime(now.year - 5, now.month, now.day);
      case 'Max': return DateTime(2000, 1, 1);
      default: return now.subtract(const Duration(days: 1));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)}, ${date.hour}:${date.minute.toString().padLeft(2, '0')} UTC';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
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
      _fetchHistoricalData();
    });
  }

  void _updateAmount(String value) {
    setState(() {
      _amountInput = value.isEmpty ? '0' : value;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double convertedAmount = _convertCurrency(double.tryParse(_amountInput) ?? 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Converter', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exchange rate display
            Text(
              '1 ${_getCurrencyName(_baseCurrency)} equals',
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${_exchangeRate.toStringAsFixed(2)} ${_getCurrencyName(_targetCurrency)}',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _lastUpdated.isEmpty ? 'Updating...' : _lastUpdated,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Conversion card
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Base currency row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              labelStyle: const TextStyle(color: Color(0xFFB0BEC5)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[700]!),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                            keyboardType: TextInputType.number,
                            onChanged: _updateAmount,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              _fetchHistoricalData();
                            });
                          },
                          dropdownColor: Colors.grey[900],
                          underline: Container(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Swap button
                    IconButton(
                      icon: const Icon(Icons.swap_vert, color: Color(0xFFB0BEC5), size: 28),
                      onPressed: _swapCurrencies,
                    ),
                    const SizedBox(height: 16),
                    // Target currency row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[700]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              convertedAmount.toStringAsFixed(2),
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              _fetchHistoricalData();
                            });
                          },
                          dropdownColor: Colors.grey[900],
                          underline: Container(),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Chart
            Expanded(
              child: Card(
                color: Colors.grey[900],
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time period tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['1D', '5D', '1M', '1Y', '5Y', 'Max'].map((period) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                  period,
                                  style: TextStyle(
                                    color: _selectedTimePeriod == period
                                        ? Colors.black
                                        : const Color(0xFFB0BEC5),
                                  ),
                                ),
                                selected: _selectedTimePeriod == period,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTimePeriod = period;
                                    _fetchHistoricalData();
                                  });
                                },
                                selectedColor: const Color(0xFFB0BEC5),
                                backgroundColor: Colors.grey[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Chart
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              width: constraints.maxWidth,
                              child: _isLoadingHistory
                                  ? Center(
                                child: CircularProgressIndicator(
                                  color: const Color(0xFFB0BEC5),
                                ),
                              )
                                  : CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: ExchangeRateChart(
                                  historicalRates: _historicalRates,
                                  color: const Color(0xFFB0BEC5),
                                  baseCurrency: _baseCurrency,
                                  targetCurrency: _targetCurrency,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrencyName(String code) {
    const names = {
      'MYR': 'Malaysian Ringgit',
      'SGD': 'Singapore Dollar',
      'THB': 'Thai Baht',
      'JPY': 'Japanese Yen',
      'KRW': 'South Korean Won',
      'USD': 'United States Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
    };
    return names[code] ?? code;
  }
}

class ExchangeRateChart extends CustomPainter {
  final List<Map<String, dynamic>> historicalRates;
  final Color color;
  final String baseCurrency;
  final String targetCurrency;

  ExchangeRateChart({
    required this.historicalRates,
    required this.color,
    required this.baseCurrency,
    required this.targetCurrency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (historicalRates.isEmpty || historicalRates.length < 2) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    // Calculate chart area with minimal padding
    final chartPadding = 20.0; // Increased padding for better label spacing
    final chartWidth = size.width - chartPadding * 2;
    final chartHeight = size.height - chartPadding * 2;

    // Get valid rates
    final validRates = historicalRates.where((e) => e['rate'] != null).toList();
    if (validRates.isEmpty) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    // Calculate min/max with some padding
    final rates = validRates.map((e) => e['rate'] as double).toList();
    final maxRate = rates.reduce((a, b) => a > b ? a : b);
    final minRate = rates.reduce((a, b) => a < b ? a : b);
    final range = (maxRate - minRate) * 1.2; // 20% padding
    final effectiveMin = minRate - (range * 0.1); // 10% padding at bottom

    // Draw chart line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < validRates.length; i++) {
      final x = chartPadding + (i / (validRates.length - 1)) * chartWidth;
      final y = chartPadding + chartHeight - ((validRates[i]['rate'] - effectiveMin) / range * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw data points
      if (i % 3 == 0 || i == validRates.length - 1) {
        canvas.drawCircle(
          Offset(x, y),
          3.0,
          Paint()..color = color.withOpacity(0.8),
        );
      }
    }

    // Draw the main line
    canvas.drawPath(path, linePaint);

    // Draw current rate indicator
    final currentRate = validRates.last['rate'] as double;
    final currentX = size.width - chartPadding;
    final currentY = chartPadding + chartHeight - ((currentRate - effectiveMin) / range * chartHeight);

    canvas.drawCircle(
      Offset(currentX, currentY),
      6.0,
      Paint()..color = color,
    );

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.0;

    // X-axis
    canvas.drawLine(
      Offset(chartPadding, chartPadding + chartHeight),
      Offset(size.width - chartPadding, chartPadding + chartHeight),
      axisPaint,
    );

    // Y-axis
    canvas.drawLine(
      Offset(chartPadding, chartPadding),
      Offset(chartPadding, chartPadding + chartHeight),
      axisPaint,
    );

    // Draw Y-axis labels with more spacing
    final yStep = chartHeight / 6; // Increased to 6 segments for better spacing
    for (int i = 0; i <= 6; i++) {
      final yValue = effectiveMin + (range * i / 6);
      final yPos = chartPadding + chartHeight - (i * yStep);
      _drawText(
        canvas,
        yValue.toStringAsFixed(2),
        Offset(chartPadding - 30, yPos - 5), // Increased horizontal offset for spacing
        const TextStyle(color: Colors.grey, fontSize: 12), // Slightly larger font
      );
    }

    // Draw X-axis labels with fewer and better-spaced labels
    final xLabelCount = 3; // Reduced to 3 labels for better spacing
    final xStep = chartWidth / xLabelCount;
    for (int i = 0; i <= xLabelCount; i++) {
      final xPos = chartPadding + (i * xStep);
      final index = (i * (validRates.length - 1) / xLabelCount).floor();
      if (index < validRates.length) {
        final date = validRates[index]['date'] as DateTime;
        final dateStr = '${date.day}/${date.month}'; // Simplified to day/month for brevity
        _drawText(
          canvas,
          dateStr,
          Offset(xPos - 20, chartPadding + chartHeight + 15), // Increased vertical offset
          const TextStyle(color: Colors.grey, fontSize: 12), // Slightly larger font
        );
      }
    }

    // Draw currency pair label
    _drawText(
      canvas,
      '$baseCurrency/$targetCurrency',
      Offset(chartPadding, 10),
      const TextStyle(color: Colors.grey, fontSize: 14),
    );
  }

  void _drawNoDataMessage(Canvas canvas, Size size) {
    _drawText(
      canvas,
      'No historical data available',
      Offset(size.width / 2, size.height / 2),
      const TextStyle(color: Colors.grey, fontSize: 14),
    );
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant ExchangeRateChart oldDelegate) {
    return oldDelegate.historicalRates != historicalRates ||
        oldDelegate.color != color;
  }
}