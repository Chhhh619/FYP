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
  String _lastUpdated = '22 Jul, 14:41 UTC';
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
          'http://api.currencylayer.com/live?access_key=d08bc68ef03869b9dffcfc11ffc0986e&source=$_baseCurrency&currencies=$_targetCurrency'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          setState(() {
            _exchangeRate = data['quotes']['$_baseCurrency$_targetCurrency'] ?? 0.24;
            _lastUpdated = _formatDate(DateTime.now());
          });
        }
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
    final formattedEnd = "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
    final formattedStart = "${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";

    try {
      final response = await http.get(Uri.parse(
          'http://api.currencylayer.com/timeframe?access_key=d08bc68ef03869b9dffcfc11ffc0986e&start_date=$formattedStart&end_date=$formattedEnd&source=$_baseCurrency&currencies=$_targetCurrency'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final rates = data['quotes'] as Map<String, dynamic>;
          setState(() {
            _historicalRates = rates.entries.map((entry) {
              final date = DateTime.parse(entry.key.substring(0, 10));
              final rate = entry.value['$_baseCurrency$_targetCurrency'];
              return {'date': date, 'rate': rate};
            }).toList()
              ..sort((a, b) => a['date'].compareTo(b['date']));
          });
          print('Historical Rates: $_historicalRates');
        }
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
      case 'Max': return DateTime(1999, 1, 1);
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

  void _showZoomedChart() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                '$_baseCurrency/$_targetCurrency Chart',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: CustomPaint(
                  size: Size(double.infinity, double.infinity),
                  painter: ExchangeRateChart(
                    historicalRates: _historicalRates,
                    color: const Color(0xFFB0BEC5),
                    baseCurrency: _baseCurrency,
                    targetCurrency: _targetCurrency,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Color(0xFFB0BEC5))),
              ),
            ],
          ),
        ),
      ),
    );
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
            Text(
              '1 ${_getCurrencyName(_baseCurrency)} equals',
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${_exchangeRate.toStringAsFixed(4)} ${_getCurrencyName(_targetCurrency)}',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _lastUpdated.isEmpty ? 'Updating...' : _lastUpdated,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
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
                    IconButton(
                      icon: const Icon(Icons.swap_vert, color: Color(0xFFB0BEC5), size: 28),
                      onPressed: _swapCurrencies,
                    ),
                    const SizedBox(height: 16),
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
                              convertedAmount.toStringAsFixed(4),
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
            Expanded(
              child: Card(
                color: Colors.grey[900],
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IconButton(
                        icon: const Icon(
                          Icons.zoom_in,
                          color: Color(0xFFB0BEC5),
                          size: 24,
                        ),
                        onPressed: _showZoomedChart,
                        splashRadius: 20,
                        tooltip: 'Zoom Chart',
                      ),
                    ),
                  ],
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

    final chartPadding = 40.0;
    final chartWidth = size.width - chartPadding * 2;
    final chartHeight = size.height - chartPadding * 2;

    final validRates = historicalRates.where((e) => e['rate'] != null).toList();
    if (validRates.isEmpty) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    final rates = validRates.map((e) => e['rate'] as double).toList();
    final maxRate = rates.reduce((a, b) => a > b ? a : b) * 1.1;
    final minRate = rates.reduce((a, b) => a < b ? a : b) * 0.9;
    final range = maxRate - minRate;

    if (range == 0) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    final gridPaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 5; i++) {
      final y = chartPadding + (i / 5) * chartHeight;
      canvas.drawLine(
        Offset(chartPadding, y),
        Offset(chartPadding + chartWidth, y),
        gridPaint,
      );
    }

    for (int i = 0; i <= 5; i++) {
      final x = chartPadding + (i / 5) * chartWidth;
      canvas.drawLine(
        Offset(x, chartPadding),
        Offset(x, chartPadding + chartHeight),
        gridPaint,
      );
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < validRates.length; i++) {
      final x = chartPadding + (i / (validRates.length - 1)) * chartWidth;
      final y = chartPadding + chartHeight - ((validRates[i]['rate'] - minRate) / range * chartHeight);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);

      if (i % 5 == 0 || i == validRates.length - 1) {
        canvas.drawCircle(Offset(x, y), 2.0, Paint()..color = color.withOpacity(0.8));
      }
    }
    canvas.drawPath(path, linePaint);

    final currentRate = validRates.last['rate'] as double;
    final currentX = chartPadding + ((validRates.length - 1) / (validRates.length - 1)) * chartWidth;
    final currentY = chartPadding + chartHeight - ((currentRate - minRate) / range * chartHeight);
    canvas.drawCircle(Offset(currentX, currentY), 4.0, Paint()..color = color);

    final axisPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(chartPadding, chartPadding), Offset(chartPadding, chartPadding + chartHeight), axisPaint);
    canvas.drawLine(Offset(chartPadding, chartPadding + chartHeight), Offset(chartPadding + chartWidth, chartPadding + chartHeight), axisPaint);

    for (int i = 0; i <= 5; i++) {
      final yValue = minRate + (range * i / 5);
      final yPos = chartPadding + chartHeight - (i / 5) * chartHeight;
      _drawText(canvas, yValue.toStringAsFixed(4), Offset(chartPadding - 20, yPos - 5), const TextStyle(color: Colors.grey, fontSize: 10));
    }

    final xLabelCount = validRates.length > 5 ? 5 : validRates.length;
    final xStep = chartWidth / xLabelCount;
    for (int i = 0; i <= xLabelCount; i++) {
      final xPos = chartPadding + (i / xLabelCount) * chartWidth;
      final index = (i * (validRates.length - 1) / xLabelCount).floor();
      if (index < validRates.length) {
        final date = validRates[index]['date'] as DateTime;
        final dateStr = '${date.day}/${date.month}';
        _drawText(canvas, dateStr, Offset(xPos - 15, chartPadding + chartHeight + 10), const TextStyle(color: Colors.grey, fontSize: 10));
      }
    }

    _drawText(canvas, '$baseCurrency/$targetCurrency', Offset(chartPadding, chartPadding - 20), const TextStyle(color: Colors.grey, fontSize: 12));
  }

  void _drawNoDataMessage(Canvas canvas, Size size) {
    _drawText(canvas, 'No historical data available', Offset(size.width / 2, size.height / 2), const TextStyle(color: Colors.grey, fontSize: 14));
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(position.dx - textPainter.width / 2, position.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant ExchangeRateChart oldDelegate) {
    return oldDelegate.historicalRates != historicalRates || oldDelegate.color != color;
  }
}