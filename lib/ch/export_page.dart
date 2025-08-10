import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:math' as math;
import 'package:fyp/ch/category_data_pdf.dart';

class ExportReportPage extends StatefulWidget {
  const ExportReportPage({super.key});

  @override
  State<ExportReportPage> createState() => _ExportReportPageState();
}

class _ExportReportPageState extends State<ExportReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedType = 'both'; // 'income', 'expense', 'both'

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  bool _isLoading = false;

  // Predefined colors for pie chart
  static const List<PdfColor> pieColors = [
    PdfColors.blue,
    PdfColors.red,
    PdfColors.green,
    PdfColors.orange,
    PdfColors.purple,
    PdfColors.teal,
    PdfColors.pink,
    PdfColors.amber,
    PdfColors.cyan,
    PdfColors.indigo,
    PdfColors.lime,
    PdfColors.deepOrange,
    PdfColors.lightBlue,
    PdfColors.lightGreen,
    PdfColors.deepPurple,
  ];

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xFF2E2E2E),
              background: Color(0xFF1C1C1C),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1C1C1C),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xFF2E2E2E),
              background: Color(0xFF1C1C1C),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1C1C1C),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _showTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text("Both", style: TextStyle(color: Colors.white)),
            onTap: () => setState(() {
              _selectedType = 'both';
              Navigator.pop(context);
            }),
          ),
          ListTile(
            title: const Text(
              "Incomes Only",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => setState(() {
              _selectedType = 'income';
              Navigator.pop(context);
            }),
          ),
          ListTile(
            title: const Text(
              "Expenses Only",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => setState(() {
              _selectedType = 'expense';
              Navigator.pop(context);
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPDF() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a start and end date.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdf = await _generatePDF();
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e, stack) {
      debugPrint("❌ Error exporting PDF: $e");
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error exporting PDF: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Generate pie chart widget using basic shapes
  pw.Widget _buildPieChart(
    List<CategoryData> categoryData,
    double totalAmount,
  ) {
    const double chartSize = 200;
    const double radius = 80;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Pie Chart using Container with decorations
        pw.Container(
          width: chartSize,
          height: chartSize,
          child: pw.Stack(
            children: [
              // Background circle
              pw.Positioned.fill(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                ),
              ),
              // Simple representation - we'll use a table instead
              pw.Center(
                child: pw.Text(
                  'Chart',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 30),

        // Legend
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Category Breakdown',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...categoryData
                  .map(
                    (data) => pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Row(
                        children: [
                          // Color indicator
                          pw.Container(
                            width: 12,
                            height: 12,
                            decoration: pw.BoxDecoration(
                              color: data.color,
                              border: pw.Border.all(
                                color: PdfColors.black,
                                width: 0.5,
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text(
                              '${data.name} (${data.percentage.toStringAsFixed(1)}%)',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Text(
                            'RM ${data.amount.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total:',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'RM ${totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build a simple bar chart as an alternative
  pw.Widget _buildBarChart(
    List<CategoryData> categoryData,
    double totalAmount,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Category Breakdown',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 15),

        // Bar chart representation
        ...categoryData.take(10).map((data) {
          final barWidth =
              (data.percentage / 100) * 300; // Max width of 300 points

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        data.name,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.Text(
                      '${data.percentage.toStringAsFixed(1)}% (RM ${data.amount.toStringAsFixed(2)})',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  height: 15,
                  width: math.max(barWidth, 10), // Minimum width for visibility
                  decoration: pw.BoxDecoration(
                    color: data.color,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),

        pw.SizedBox(height: 15),
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total Amount:',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'RM ${totalAmount.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Future<pw.Document> _generatePDF() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");
    final userId = user.uid;

    // 🔹 Fetch username
    String username = '';
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      username = userDoc['username'] ?? '';
    }

    // 🔹 Get transactions in range
    Query query = FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: _startDate)
        .where('timestamp', isLessThanOrEqualTo: _endDate);

    if (_selectedType != 'both') {
      query = query.where('type', isEqualTo: _selectedType);
    } else {
      query = query.where('type', whereIn: ['income', 'expense']);
    }

    final snapshot = await query.orderBy('timestamp').get();

    final transactions = snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .where(
          (t) =>
              t.containsKey('timestamp') &&
              t['timestamp'] is Timestamp &&
              t.containsKey('amount') &&
              t['amount'] is num,
        )
        .toList();

    // 🔹 Collect category IDs
    final Set<String> categoryIds = {};
    for (var t in transactions) {
      if (t['category'] is DocumentReference) {
        categoryIds.add((t['category'] as DocumentReference).id);
      } else if (t['category'] is String && t['category'].isNotEmpty) {
        categoryIds.add(t['category']);
      }
    }

    // 🔹 Fetch category names
    final Map<String, String> categoryNames = {};
    if (categoryIds.isNotEmpty) {
      for (var categoryId in categoryIds) {
        final doc = await FirebaseFirestore.instance
            .collection('categories')
            .doc(categoryId)
            .get();
        if (doc.exists) {
          categoryNames[doc.id] = doc['name'] ?? '';
        }
      }
    }

    // 🔹 Calculate category totals for charts
    final Map<String, double> categoryTotals = {};
    final Map<String, String> categoryTypes = {};

    for (var t in transactions) {
      String? categoryId;
      if (t['category'] is DocumentReference) {
        categoryId = (t['category'] as DocumentReference).id;
      } else if (t['category'] is String) {
        categoryId = t['category'];
      }

      final categoryName = categoryId != null
          ? (categoryNames[categoryId] ?? 'Unknown')
          : 'Unknown';
      final amount = (t['amount'] as num)
          .abs()
          .toDouble(); // Use absolute value for totals
      final type = t['type']?.toString() ?? 'expense';

      // For charts, we want to show the breakdown by category
      // If showing both types, we can separate income/expense in category names
      String displayName = categoryName;
      if (_selectedType == 'both') {
        displayName = '$categoryName (${type.capitalize()})';
      }

      categoryTotals[displayName] = (categoryTotals[displayName] ?? 0) + amount;
      categoryTypes[displayName] = type;
    }

    // 🔹 Create chart data
    final totalAmount = categoryTotals.values.fold(
      0.0,
      (sum, amount) => sum + amount,
    );
    final List<CategoryData> chartData = [];

    int colorIndex = 0;
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by amount descending

    for (var entry in sortedEntries) {
      if (entry.value > 0) {
        final percentage = totalAmount > 0
            ? (entry.value / totalAmount) * 100
            : 0;
        chartData.add(
          CategoryData(
            name: entry.key,
            amount: entry.value,
            percentage: percentage.toDouble(),
            color: pieColors[colorIndex % pieColors.length],
            type: categoryTypes[entry.key] ?? 'expense',
          ),
        );
        colorIndex++;
      }
    }

    // 🔹 Calculate income and expense totals
    final incomeTotal = transactions
        .where((t) => t['type'] == 'income')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).abs());

    final expenseTotal = transactions
        .where((t) => t['type'] == 'expense')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num).abs());

    // 🔹 Build PDF
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              children: [
                pw.Text(
                  "Transactions Report - $username",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}",
                  style: const pw.TextStyle(fontSize: 14),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  _selectedType == 'both'
                      ? 'Income & Expenses'
                      : _selectedType == 'income'
                      ? 'Income Only'
                      : 'Expenses Only',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Summary Statistics
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      'Total Transactions',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${transactions.length}',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'Total Amount',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'RM ${totalAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                if (_selectedType == 'both') ...[
                  pw.Column(
                    children: [
                      pw.Text(
                        'Income',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'RM ${incomeTotal.toStringAsFixed(2)}',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Expenses',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'RM ${expenseTotal.toStringAsFixed(2)}',
                        style: const pw.TextStyle(
                          fontSize: 16,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Bar Chart (only show if we have data)
          if (chartData.isNotEmpty) ...[
            pw.Text(
              'Category Analysis',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 15),
            _buildBarChart(chartData, totalAmount),
            pw.SizedBox(height: 30),
          ],

          // Transactions Table
          pw.Text(
            'Transaction Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 15),

          pw.Table.fromTextArray(
            headers: ["Date", "Type", "Category", "Amount"],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellAlignment: pw.Alignment.centerLeft,
            data: transactions.map((t) {
              String? categoryId;
              if (t['category'] is DocumentReference) {
                categoryId = (t['category'] as DocumentReference).id;
              } else if (t['category'] is String) {
                categoryId = t['category'];
              }

              final categoryName = categoryId != null
                  ? (categoryNames[categoryId] ?? 'Unknown')
                  : 'Unknown';
              final type = t['type']?.toString() ?? 'expense';

              return [
                dateFormat.format((t['timestamp'] as Timestamp).toDate()),
                type.capitalize(),
                categoryName,
                "${type == 'income' ? '+' : '-'}RM ${(t['amount'] as num).abs().toStringAsFixed(2)}",
              ];
            }).toList(),
          ),
        ],
      ),
    );

    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1C),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // Back arrow button with grey background
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              // Title
              const Expanded(
                child: Text(
                  'Bill export',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 16),
              // Filler space for symmetry (same width as back button)
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Date range",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Start Date
            GestureDetector(
              onTap: _pickStartDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _startDate != null
                          ? _dateFormat.format(_startDate!)
                          : "Start Date",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.white70),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // End Date
            GestureDetector(
              onTap: _pickEndDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _endDate != null
                          ? _dateFormat.format(_endDate!)
                          : "End Date",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.white70),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              "Filters",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Income & Expenses Selector
            GestureDetector(
              onTap: _showTypeSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Income and expenses",
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      _selectedType == 'both'
                          ? "All"
                          : _selectedType == 'income'
                          ? "Incomes"
                          : "Expenses",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: _isLoading ? null : _exportPDF,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4D4D),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      "Confirm Export",
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
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
