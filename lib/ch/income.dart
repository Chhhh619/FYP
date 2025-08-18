import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'income_details.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Check and generate incomes when the page loads
    _checkAndGenerateIncomes();
  }

  Future<void> _checkAndGenerateIncomes() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    print('Starting income automation check for user: $userId');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // Get all enabled incomes for this user
      final incomes = await _firestore
          .collection('incomes')
          .where('userId', isEqualTo: userId)
          .where('isEnabled', isEqualTo: true) // Only process enabled incomes
          .get();

      print('Found ${incomes.docs.length} enabled incomes to process');

      for (final doc in incomes.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final repeat = data['repeat'] ?? 'Monthly';
        final amount = (data['amount'] ?? 0.0).toDouble();

        print('Processing income: ${data['name']}, Start: $startDateOnly, Repeat: $repeat, Amount: $amount');

        // Skip if start date is in the future
        if (startDateOnly.isAfter(today)) {
          print('Skipping - start date is in future');
          continue;
        }

        final lastGenerated = data['lastGenerated'] != null
            ? (data['lastGenerated'] as Timestamp).toDate()
            : null;

        // Generate all missed transactions from start date or last generated date up to today
        DateTime currentDue;
        if (lastGenerated != null) {
          currentDue = _calculateNextDueDate(lastGenerated, repeat);
          print('Last generated: $lastGenerated, Next due: $currentDue');
        } else {
          // If never generated, start from the start date
          currentDue = startDateOnly;
          print('Never generated before, starting from: $currentDue');
        }

        // Generate all missed transactions up to today
        int transactionsGenerated = 0;
        DateTime lastProcessedDate = lastGenerated ?? startDateOnly;

        while (!currentDue.isAfter(today) && transactionsGenerated < 100) { // Safety limit
          final startOfDay = DateTime(currentDue.year, currentDue.month, currentDue.day);

          // Check if transaction already exists for this date
          final existingTxs = await _firestore
              .collection('transactions')
              .where('userId', isEqualTo: userId)
              .where('incomeId', isEqualTo: doc.id)
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('timestamp', isLessThan: Timestamp.fromDate(startOfDay.add(const Duration(days: 1))))
              .get();

          if (existingTxs.docs.isEmpty) {
            print('Generating transaction for date: $startOfDay');

            // Get the category reference
            final categoryRef = data['category'] as DocumentReference;

            // Create transaction with consistent structure
            final transactionData = {
              'userId': userId,
              'amount': amount,
              'timestamp': Timestamp.fromDate(startOfDay.add(const Duration(hours: 9))),
              'category': categoryRef,
              'incomeId': doc.id,
              'type': 'income', // Add type field for consistency
              'description': 'Automated income: ${data['name']}',
            };

            // Add card info if specified
            if (data['toCardId'] != null) {
              transactionData['toCardId'] = data['toCardId'];
            }

            // Use Firestore transaction to ensure atomicity - READ FIRST, THEN WRITE
            await _firestore.runTransaction((transaction) async {
              DocumentSnapshot? cardDoc;
              String? cardName;

              // PERFORM ALL READS FIRST
              if (data['toCardId'] != null) {
                final cardRef = _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('cards')
                    .doc(data['toCardId']);
                cardDoc = await transaction.get(cardRef);

                if (cardDoc.exists) {
                  final cardData = cardDoc.data() as Map<String, dynamic>;
                  cardName = cardData['name'] as String?; // Get card name
                }
              }

              // Add card name to transaction data if available
              if (cardName != null) {
                transactionData['toCardName'] = cardName;
              }

              // NOW PERFORM ALL WRITES
              final txRef = _firestore.collection('transactions').doc();
              transaction.set(txRef, transactionData);

              // Update card balance if specified and card exists
              if (data['toCardId'] != null && cardDoc != null && cardDoc.exists) {
                final cardRef = _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('cards')
                    .doc(data['toCardId']);

                final currentBalance = (cardDoc.data()! as Map<String, dynamic>)['balance'] ?? 0.0;
                final newBalance = (currentBalance as num).toDouble() + amount;
                transaction.update(cardRef, {'balance': newBalance});
                print('Updated card balance: $currentBalance -> $newBalance');
              }
            });

            transactionsGenerated++;
            lastProcessedDate = startOfDay;
            print('Transaction generated successfully for $startOfDay');
          } else {
            print('Transaction already exists for date: $startOfDay');
            lastProcessedDate = startOfDay;
          }

          currentDue = _calculateNextDueDate(currentDue, repeat);
        }

        // Update lastGenerated to the last processed date
        if (transactionsGenerated > 0 || lastGenerated == null) {
          await _firestore.collection('incomes').doc(doc.id).update({
            'lastGenerated': Timestamp.fromDate(lastProcessedDate),
          });
          print('Updated lastGenerated to: $lastProcessedDate');
        }
      }

      print('Income automation completed');
    } catch (e) {
      print('Error generating incomes: $e');
    }
  }

  DateTime _calculateNextDueDate(DateTime from, String repeat) {
    switch (repeat.toLowerCase()) {
      case 'daily':
        return DateTime(from.year, from.month, from.day + 1);
      case 'weekly':
        return DateTime(from.year, from.month, from.day + 7);
      case 'monthly':
      // Handle month overflow properly
        int newYear = from.year;
        int newMonth = from.month + 1;
        if (newMonth > 12) {
          newYear++;
          newMonth = 1;
        }
        // Handle day overflow (e.g., Jan 31 -> Feb 28)
        final lastDayOfNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        final day = from.day > lastDayOfNewMonth ? lastDayOfNewMonth : from.day;
        return DateTime(newYear, newMonth, day);
      case 'annually':
        return DateTime(from.year + 1, from.month, from.day);
      default:
        return DateTime(from.year, from.month + 1, from.day);
    }
  }

  Future<void> _navigateToIncomeDetails(Map<String, dynamic> category) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IncomeDetailsPage(
          category: category,
          categoryId: category['id'],
        ),
      ),
    );

    if (result == true) {
      // Refresh and check for new income automations
      setState(() {});
      _checkAndGenerateIncomes();
    }
  }

  // Get categories that belong to the user OR are default categories (no userId field)
  Stream<QuerySnapshot> _getCategoriesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('categories')
        .where('type', isEqualTo: 'income')
        .snapshots();
  }

  // Filter categories to show only user's categories + default ones
  List<Map<String, dynamic>> _filterCategories(List<QueryDocumentSnapshot> docs) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final categoryUserId = data['userId'];

      // Include if it's the user's category OR if it's a default category (no userId field)
      // Check for null, empty string, or field doesn't exist
      return categoryUserId == userId ||
          categoryUserId == null ||
          categoryUserId == '' ||
          !data.containsKey('userId');
    }).map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'icon': data['icon'] ?? '💰',
        'description': data['description'] ?? '',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        body: const Center(
          child: Text(
            'Please log in to manage your income',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
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
              const Expanded(
                child: Text(
                  'Income Management',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              // Add a refresh button for testing
              GestureDetector(
                onTap: () {
                  _checkAndGenerateIncomes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking for income updates...'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getCategoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading income categories: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No income categories found',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final categories = _filterCategories(snapshot.data!.docs);

          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No income categories available for your account',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return Column(
            children: [
              // Header section with summary
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Income Sources',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Set up automated income recording for your regular income sources. Tap any category to configure.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Categories list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _buildCategoryCard(category);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final userId = _auth.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToIncomeDetails(category),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[800]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      category['icon'] ?? '💰',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Category details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category['name'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (category['description']?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          category['description'],
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Show if income is set up for this category
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('incomes')
                            .where('userId', isEqualTo: userId)
                            .where('category', isEqualTo: _firestore.collection('categories').doc(category['id']))
                            .limit(1)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                            final incomeData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                            final isEnabled = incomeData['isEnabled'] ?? false;
                            final amount = (incomeData['amount'] ?? 0.0).toDouble();

                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    isEnabled ? Icons.autorenew : Icons.pause_circle_outline,
                                    color: isEnabled ? Colors.green : Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isEnabled
                                        ? 'RM${amount.toStringAsFixed(0)} • ${incomeData['repeat'] ?? 'Monthly'}'
                                        : 'Configured but disabled',
                                    style: TextStyle(
                                      color: isEnabled ? Colors.green : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),

                // Arrow icon
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}