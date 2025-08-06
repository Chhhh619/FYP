import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
            title: const Text("Incomes Only", style: TextStyle(color: Colors.white)),
            onTap: () => setState(() {
              _selectedType = 'income';
              Navigator.pop(context);
            }),
          ),
          ListTile(
            title: const Text("Expenses Only", style: TextStyle(color: Colors.white)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting PDF: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        .where((t) =>
    t.containsKey('timestamp') &&
        t['timestamp'] is Timestamp &&
        t.containsKey('amount') &&
        t['amount'] is num)
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

    // 🔹 Build PDF
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              "Transactions Report - $username\n${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}",
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Table.fromTextArray(
            headers: ["Date", "Type", "Category", "Amount", "Description"],
            data: transactions.map((t) {
              String? categoryId;
              if (t['category'] is DocumentReference) {
                categoryId = (t['category'] as DocumentReference).id;
              } else if (t['category'] is String) {
                categoryId = t['category'];
              }

              final categoryName = categoryId != null ? (categoryNames[categoryId] ?? '') : '';

              return [
                dateFormat.format((t['timestamp'] as Timestamp).toDate()),
                t['type']?.toString() ?? '',
                categoryName,
                "RM ${(t['amount'] as num).toStringAsFixed(2)}",
                t['description']?.toString() ?? '',
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
              SizedBox(width: 40),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Date range", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Start Date
            GestureDetector(
              onTap: _pickStartDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _startDate != null ? _dateFormat.format(_startDate!) : "Start Date",
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _endDate != null ? _dateFormat.format(_endDate!) : "End Date",
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.white70),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            const Text("Filters", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Income & Expenses Selector
            GestureDetector(
              onTap: _showTypeSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Income and expenses", style: TextStyle(color: Colors.white)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text("Confirm Export", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
