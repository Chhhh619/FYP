import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  _CurrencyConverterScreenState createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen>
    with TickerProviderStateMixin {
  String _baseCurrency = 'MYR';
  String _targetCurrency = 'USD';
  double _exchangeRate = 0.24;
  String _amountInput = '1';
  final _amountController = TextEditingController();
  String _lastUpdated = '22 Jul, 14:41 UTC';
  String _selectedTimePeriod = '1D';
  List<Map<String, dynamic>> _historicalRates = [];
  bool _isLoadingHistory = false;
  bool _isLoadingRate = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Currency flag emojis
  final Map<String, String> _currencyFlags = {
    'MYR': '🇲🇾',
    'SGD': '🇸🇬',
    'THB': '🇹🇭',
    'JPY': '🇯🇵',
    'KRW': '🇰🇷',
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
  };

  @override
  void initState() {
    super.initState();
    _amountController.text = _amountInput;

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _fetchExchangeRate();
    _fetchHistoricalData();

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _fetchExchangeRate() async {
    setState(() => _isLoadingRate = true);
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
    } finally {
      setState(() => _isLoadingRate = false);
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
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    colors: [Color(0xFF2D2D2D), Color(0xFF1E1E1E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB0BEC5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: const Color(0xFFB0BEC5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_baseCurrency → $_targetCurrency',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Exchange Rate Chart',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFFB0BEC5)),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: EnhancedExchangeRateChart(
                      historicalRates: _historicalRates,
                      color: const Color(0xFFB0BEC5),
                      baseCurrency: _baseCurrency,
                      targetCurrency: _targetCurrency,
                      isZoomed: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown(String currency, bool isBase) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: DropdownButton<String>(
        value: currency,
        items: ['MYR', 'SGD', 'THB', 'JPY', 'KRW', 'USD', 'EUR', 'GBP']
            .map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currencyFlags[value] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (newValue) {
          setState(() {
            if (isBase) {
              _baseCurrency = newValue!;
            } else {
              _targetCurrency = newValue!;
            }
            _fetchExchangeRate();
            _fetchHistoricalData();
          });
        },
        dropdownColor: Colors.grey[800],
        underline: Container(),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFB0BEC5)),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double convertedAmount = _convertCurrency(double.tryParse(_amountInput) ?? 0.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  // Custom App Bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFB0BEC5).withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Currency Converter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isLoadingRate)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB0BEC5)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Exchange Rate Display
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey[900]!,
                                  Colors.grey[850]!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(_currencyFlags[_baseCurrency] ?? '', style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '1 ${_getCurrencyName(_baseCurrency)}',
                                      style: const TextStyle(
                                        color: Color(0xFFB0BEC5),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(_currencyFlags[_targetCurrency] ?? '', style: const TextStyle(fontSize: 24)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_exchangeRate.toStringAsFixed(4)} ${_getCurrencyName(_targetCurrency)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: Colors.grey[500],
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _lastUpdated.isEmpty ? 'Updating...' : _lastUpdated,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Converter Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // From Currency
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey[700]!),
                                        ),
                                        child: TextField(
                                          controller: _amountController,
                                          decoration: const InputDecoration(
                                            labelText: 'Amount',
                                            labelStyle: TextStyle(color: Color(0xFFB0BEC5)),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.all(16),
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: _updateAmount,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildCurrencyDropdown(_baseCurrency, true),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Swap Button
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB0BEC5).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.swap_vert_rounded,
                                      color: Color(0xFFB0BEC5),
                                      size: 28,
                                    ),
                                    onPressed: _swapCurrencies,
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // To Currency
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey[700]!),
                                        ),
                                        child: Text(
                                          convertedAmount.toStringAsFixed(4),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildCurrencyDropdown(_targetCurrency, false),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Chart Section
                          Container(
                            height: 320,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.analytics_outlined,
                                            color: Color(0xFFB0BEC5),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Historical Data',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB0BEC5).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _selectedTimePeriod,
                                              style: const TextStyle(
                                                color: Color(0xFFB0BEC5),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Time Period Selector
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: ['1D', '5D', '1M', '1Y', '5Y', 'Max'].map((period) {
                                            final isSelected = _selectedTimePeriod == period;
                                            return Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedTimePeriod = period;
                                                    _fetchHistoricalData();
                                                  });
                                                },
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(0xFFB0BEC5)
                                                        : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? const Color(0xFFB0BEC5)
                                                          : Colors.grey[600]!,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    period,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? Colors.black
                                                          : const Color(0xFFB0BEC5),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Chart
                                      Expanded(
                                        child: _isLoadingHistory
                                            ? const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFB0BEC5),
                                          ),
                                        )
                                            : CustomPaint(
                                          size: const Size(double.infinity, double.infinity),
                                          painter: EnhancedExchangeRateChart(
                                            historicalRates: _historicalRates,
                                            color: const Color(0xFFB0BEC5),
                                            baseCurrency: _baseCurrency,
                                            targetCurrency: _targetCurrency,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Zoom Button
                                Positioned(
                                  right: 16,
                                  bottom: 16,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFB0BEC5).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.zoom_out_map,
                                        color: Color(0xFFB0BEC5),
                                        size: 20,
                                      ),
                                      onPressed: _showZoomedChart,
                                      tooltip: 'Expand Chart',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class EnhancedExchangeRateChart extends CustomPainter {
  final List<Map<String, dynamic>> historicalRates;
  final Color color;
  final String baseCurrency;
  final String targetCurrency;
  final bool isZoomed;

  EnhancedExchangeRateChart({
    required this.historicalRates,
    required this.color,
    required this.baseCurrency,
    required this.targetCurrency,
    this.isZoomed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (historicalRates.isEmpty || historicalRates.length < 2) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    final chartPadding = isZoomed ? 60.0 : 40.0;
    final chartWidth = size.width - chartPadding * 2;
    final chartHeight = size.height - chartPadding * 2;

    final validRates = historicalRates.where((e) => e['rate'] != null).toList();
    if (validRates.isEmpty) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    final rates = validRates.map((e) => e['rate'] as double).toList();
    final maxRate = rates.reduce((a, b) => a > b ? a : b);
    final minRate = rates.reduce((a, b) => a < b ? a : b);
    final range = maxRate - minRate;
    final paddedMax = maxRate + (range * 0.1);
    final paddedMin = minRate - (range * 0.1);
    final paddedRange = paddedMax - paddedMin;

    if (paddedRange == 0) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    // Draw background gradient
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.1),
          color.withOpacity(0.05),
        ],
      ).createShader(
          Rect.fromLTWH(chartPadding, chartPadding, chartWidth, chartHeight));

    canvas.drawRect(
      Rect.fromLTWH(chartPadding, chartPadding, chartWidth, chartHeight),
      backgroundPaint,
    );

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey[700]!.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (int i = 0; i <= 5; i++) {
      final y = chartPadding + (i / 5) * chartHeight;
      canvas.drawLine(
        Offset(chartPadding, y),
        Offset(chartPadding + chartWidth, y),
        gridPaint,
      );
    }

    // Vertical grid lines
    final verticalLines = isZoomed ? 10 : 5;
    for (int i = 0; i <= verticalLines; i++) {
      final x = chartPadding + (i / verticalLines) * chartWidth;
      canvas.drawLine(
        Offset(x, chartPadding),
        Offset(x, chartPadding + chartHeight),
        gridPaint,
      );
    }

    // Create gradient fill under the line
    final gradientPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < validRates.length; i++) {
      final x = chartPadding + (i / (validRates.length - 1)) * chartWidth;
      final y = chartPadding + chartHeight -
          ((validRates[i]['rate'] - paddedMin) / paddedRange * chartHeight);
      points.add(Offset(x, y));

      if (i == 0) {
        gradientPath.moveTo(x, y);
      } else {
        gradientPath.lineTo(x, y);
      }
    }

    // Complete the gradient fill path
    if (points.isNotEmpty) {
      gradientPath.lineTo(points.last.dx, chartPadding + chartHeight);
      gradientPath.lineTo(points.first.dx, chartPadding + chartHeight);
      gradientPath.close();

      final gradientFillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.3),
            color.withOpacity(0.05),
          ],
        ).createShader(
            Rect.fromLTWH(chartPadding, chartPadding, chartWidth, chartHeight));

      canvas.drawPath(gradientPath, gradientFillPaint);
    }

    // Draw the main line with smooth curves
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = isZoomed ? 3.0 : 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (points.length > 1) {
      final smoothPath = Path();
      smoothPath.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        final previous = points[i - 1];
        final current = points[i];

        if (i == 1) {
          // First curve
          final controlPoint1 = Offset(
            previous.dx + (current.dx - previous.dx) * 0.3,
            previous.dy,
          );
          final controlPoint2 = Offset(
            current.dx - (current.dx - previous.dx) * 0.3,
            current.dy,
          );
          smoothPath.cubicTo(
            controlPoint1.dx, controlPoint1.dy,
            controlPoint2.dx, controlPoint2.dy,
            current.dx, current.dy,
          );
        } else {
          // Smooth curves for subsequent points
          final next = i < points.length - 1 ? points[i + 1] : current;
          final controlPoint1 = Offset(
            previous.dx + (current.dx - previous.dx) * 0.5,
            previous.dy + (current.dy - previous.dy) * 0.3,
          );
          final controlPoint2 = Offset(
            current.dx - (next.dx - current.dx) * 0.3,
            current.dy,
          );
          smoothPath.cubicTo(
            controlPoint1.dx, controlPoint1.dy,
            controlPoint2.dx, controlPoint2.dy,
            current.dx, current.dy,
          );
        }
      }
      canvas.drawPath(smoothPath, linePaint);
    }

    // Draw data points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length; i++) {
      if (isZoomed || i % (points.length ~/ 6).clamp(1, points.length) == 0 ||
          i == points.length - 1) {
        // Draw point border
        canvas.drawCircle(points[i], isZoomed ? 5.0 : 4.0, pointBorderPaint);
        // Draw point
        canvas.drawCircle(points[i], isZoomed ? 3.5 : 2.5, pointPaint);
      }
    }

    // Highlight current rate point
    if (points.isNotEmpty) {
      final currentPoint = points.last;
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      canvas.drawCircle(currentPoint, 12.0, glowPaint);
      canvas.drawCircle(currentPoint, 6.0, pointBorderPaint);
      canvas.drawCircle(currentPoint, 4.0, pointPaint);
    }

    // Draw axes
    final axisPaint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 1.5;

    // Y-axis
    canvas.drawLine(
      Offset(chartPadding, chartPadding),
      Offset(chartPadding, chartPadding + chartHeight),
      axisPaint,
    );

    // X-axis
    canvas.drawLine(
      Offset(chartPadding, chartPadding + chartHeight),
      Offset(chartPadding + chartWidth, chartPadding + chartHeight),
      axisPaint,
    );

    // Draw Y-axis labels (rates)
    final labelCount = isZoomed ? 7 : 5;
    for (int i = 0; i <= labelCount; i++) {
      final yValue = paddedMin + (paddedRange * i / labelCount);
      final yPos = chartPadding + chartHeight - (i / labelCount) * chartHeight;

      _drawText(
        canvas,
        yValue.toStringAsFixed(4),
        Offset(chartPadding - 10, yPos),
        TextStyle(
          color: Colors.grey[400],
          fontSize: isZoomed ? 12 : 10,
          fontWeight: FontWeight.w500,
        ),
        TextAlign.right,
      );
    }

    // Draw X-axis labels (dates)
    final xLabelCount = isZoomed ? 7 : 4;
    for (int i = 0; i <= xLabelCount; i++) {
      final xPos = chartPadding + (i / xLabelCount) * chartWidth;
      final index = ((i * (validRates.length - 1)) / xLabelCount).round().clamp(
          0, validRates.length - 1);

      if (index < validRates.length) {
        final date = validRates[index]['date'] as DateTime;
        final dateStr = isZoomed
            ? '${date.day}/${date.month}/${date.year.toString().substring(2)}'
            : '${date.day}/${date.month}';

        _drawText(
          canvas,
          dateStr,
          Offset(xPos, chartPadding + chartHeight + 15),
          TextStyle(
            color: Colors.grey[400],
            fontSize: isZoomed ? 11 : 9,
            fontWeight: FontWeight.w500,
          ),
          TextAlign.center,
        );
      }
    }

    // Draw chart title
    _drawText(
      canvas,
      '$baseCurrency → $targetCurrency',
      Offset(chartPadding, chartPadding - 25),
      TextStyle(
        color: Colors.grey[300],
        fontSize: isZoomed ? 16 : 14,
        fontWeight: FontWeight.bold,
      ),
      TextAlign.left,
    );

    // Draw current rate info
    if (validRates.isNotEmpty) {
      final currentRate = validRates.last['rate'] as double;
      final previousRate = validRates.length > 1 ? validRates[validRates
          .length - 2]['rate'] as double : currentRate;
      final change = currentRate - previousRate;
      final changePercent = previousRate != 0
          ? (change / previousRate) * 100
          : 0;

      final isPositive = change >= 0;
      final changeColor = isPositive ? Colors.green[400]! : Colors.red[400]!;
      final changeIcon = isPositive ? '↗' : '↘';

      final infoText = '$changeIcon ${changePercent.abs().toStringAsFixed(2)}%';

      _drawText(
        canvas,
        infoText,
        Offset(chartPadding + chartWidth, chartPadding - 25),
        TextStyle(
          color: changeColor,
          fontSize: isZoomed ? 14 : 12,
          fontWeight: FontWeight.bold,
        ),
        TextAlign.right,
      );
    }
  }

  void _drawNoDataMessage(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..style = PaintingStyle.fill;

    // Draw empty state icon
    final iconSize = size.width * 0.1;
    final iconRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 20),
      width: iconSize,
      height: iconSize,
    );

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2 - 20),
      iconSize / 2,
      paint..color = Colors.grey[700]!.withOpacity(0.3),
    );

    _drawText(
      canvas,
      'No historical data available',
      Offset(size.width / 2, size.height / 2 + 10),
      TextStyle(
        color: Colors.grey[500],
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      TextAlign.center,
    );

    _drawText(
      canvas,
      'Please try a different time period',
      Offset(size.width / 2, size.height / 2 + 35),
      TextStyle(
        color: Colors.grey[600],
        fontSize: 12,
      ),
      TextAlign.center,
    );
  }

  void _drawText(Canvas canvas, String text, Offset position, TextStyle style,
      TextAlign align) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )
      ..layout();

    Offset drawPosition;
    switch (align) {
      case TextAlign.center:
        drawPosition = Offset(
          position.dx - textPainter.width / 2,
          position.dy - textPainter.height / 2,
        );
        break;
      case TextAlign.right:
        drawPosition = Offset(
          position.dx - textPainter.width,
          position.dy - textPainter.height / 2,
        );
        break;
      default:
        drawPosition = Offset(
          position.dx,
          position.dy - textPainter.height / 2,
        );
    }

    textPainter.paint(canvas, drawPosition);
  }

  @override
  bool shouldRepaint(covariant EnhancedExchangeRateChart oldDelegate) {
    return oldDelegate.historicalRates != historicalRates ||
        oldDelegate.color != color ||
        oldDelegate.isZoomed != isZoomed;
  }
}