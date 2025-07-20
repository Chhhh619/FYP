import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Data model for a financial tip
class FinancialTip {
  final String id;
  final String title;
  final String description;
  final String category; // e.g., dining, shopping
  bool isHelpful;
  bool isIrrelevant;

  FinancialTip({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.isHelpful = false,
    this.isIrrelevant = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'isHelpful': isHelpful,
      'isIrrelevant': isIrrelevant,
    };
  }
}

// Data model for spending data
class SpendingData {
  final String category;
  final double amount;
  final double threshold;

  SpendingData({
    required this.category,
    required this.amount,
    required this.threshold,
  });
}

class FinancialTipsScreen extends StatefulWidget {
  const FinancialTipsScreen({Key? key}) : super(key: key);

  @override
  _FinancialTipsScreenState createState() => _FinancialTipsScreenState();
}

class _FinancialTipsScreenState extends State<FinancialTipsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Predefined list of financial tips
  final List<FinancialTip> _defaultTips = [
    FinancialTip(
      id: '1',
      title: 'Cook at Home',
      description: 'Your dining expenses are high this month. Try cooking at home to save RM200.',
      category: 'dining',
    ),
    FinancialTip(
      id: '2',
      title: 'Shop Smart',
      description: 'Consider buying in bulk or during sales to reduce shopping costs.',
      category: 'shopping',
    ),
    FinancialTip(
      id: '3',
      title: 'Budget for Entertainment',
      description: 'Set a monthly limit for entertainment to avoid overspending.',
      category: 'entertainment',
    ),
  ];

  List<FinancialTip> _tips = [];
  List<SpendingData> _spendingData = [];

  @override
  void initState() {
    super.initState();
    _loadTipsAndSpending();
  }

  Future<void> _loadTipsAndSpending() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Fetch user-specific tip feedback from Firestore
    final tipSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tips_feedback')
        .get();

    // Create a map of feedback for easier lookup
    final feedbackMap = {
      for (var doc in tipSnapshot.docs) doc.id: doc.data(),
    };

    setState(() {
      _tips = _defaultTips.map((defaultTip) {
        final feedback = feedbackMap[defaultTip.id];
        return FinancialTip(
          id: defaultTip.id,
          title: defaultTip.title,
          description: defaultTip.description,
          category: defaultTip.category,
          isHelpful: feedback != null ? feedback['isHelpful'] ?? false : false,
          isIrrelevant: feedback != null ? feedback['isIrrelevant'] ?? false : false,
        );
      }).toList();
    });

    // Fetch transactions for the current month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final transactionSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    // Calculate spending per category
    final Map<String, double> categorySpending = {};
    for (var doc in transactionSnapshot.docs) {
      final data = doc.data();
      final categoryRef = data['category'] as DocumentReference;
      final categorySnapshot = await categoryRef.get();
      final categoryName = categorySnapshot.get('name') as String? ?? 'unknown';
      final amount = (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] as double? ?? 0.0);
      final categoryType = categorySnapshot.get('type') as String? ?? 'unknown';

      if (categoryType == 'expense') {
        categorySpending[categoryName] =
            (categorySpending[categoryName] ?? 0.0) + amount.abs();
      }
    }

    // Define thresholds for each category (example values)
    const categoryThresholds = {
      'dining': 300.0,
      'shopping': 250.0,
      'entertainment': 100.0,
    };

    setState(() {
      _spendingData = categorySpending.entries
          .map((entry) => SpendingData(
        category: entry.key,
        amount: entry.value,
        threshold: categoryThresholds[entry.key] ?? 200.0,
      ))
          .toList();
    });
  }

  // Filter tips based on spending data
  List<FinancialTip> _getRelevantTips() {
    return _tips.where((tip) {
      final spending = _spendingData.firstWhere(
            (data) => data.category == tip.category,
        orElse: () => SpendingData(category: tip.category, amount: 0, threshold: 0),
      );
      return spending.amount > spending.threshold && !tip.isIrrelevant;
    }).toList();
  }

  // Update tip feedback and save to Firestore
  Future<void> _markTipFeedback(String tipId, bool isHelpful) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      final tip = _tips.firstWhere((tip) => tip.id == tipId);
      tip.isHelpful = isHelpful;
      tip.isIrrelevant = !isHelpful;
    });

    // Save feedback to Firestore
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('tips_feedback')
        .doc(tipId)
        .set({
      'isHelpful': isHelpful,
      'isIrrelevant': !isHelpful,
      'timestamp': Timestamp.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final relevantTips = _getRelevantTips();

    return Theme(
      data: ThemeData(
        scaffoldBackgroundColor: Colors.black, // Black background
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white, // White text/icons for AppBar
        ),
        cardColor: const Color(0xFF212121), // Dark grey for cards
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.white, // White for title
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(
            color: Color(0xFFB0B0B0), // Light grey for description
            fontSize: 14,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.all(const Color(0xFFB0B0B0)), // Grey for buttons
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Financial Education Tips'),
        ),
        body: relevantTips.isEmpty
            ? const Center(
          child: Text(
            'No relevant tips available.',
            style: TextStyle(color: Colors.white),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: relevantTips.length,
          itemBuilder: (context, index) {
            final tip = relevantTips[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tip.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _markTipFeedback(tip.id, true),
                          child: Text(
                            tip.isHelpful ? 'Helpful ✓' : 'Mark as Helpful',
                            style: TextStyle(
                              color: tip.isHelpful
                                  ? Colors.green
                                  : const Color(0xFFB0B0B0),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _markTipFeedback(tip.id, false),
                          child: Text(
                            tip.isIrrelevant
                                ? 'Irrelevant ✓'
                                : 'Mark as Irrelevant',
                            style: TextStyle(
                              color: tip.isIrrelevant
                                  ? Colors.red
                                  : const Color(0xFFB0B0B0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}