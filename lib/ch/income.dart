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
    // Remove the income automation from here since it should run from HomePage
  }

  Future<void> _checkAndGenerateIncomes() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      final incomes = await _firestore
          .collection('incomes')
          .where('userid', isEqualTo: userId)
          .get();

      for (final doc in incomes.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final repeat = data['repeat'] ?? 'monthly';
        final lastGenerated = data['lastGenerated'] != null
            ? (data['lastGenerated'] as Timestamp).toDate()
            : startDate;

        DateTime nextDue = _calculateNextDueDate(lastGenerated, repeat);

        while (!nextDue.isAfter(today)) {
          final startOfDay = DateTime(nextDue.year, nextDue.month, nextDue.day);

          // Check if transaction already exists for this date
          final existingTxs = await _firestore
              .collection('transactions')
              .where('userid', isEqualTo: userId)
              .where('incomeId', isEqualTo: doc.id)
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('timestamp', isLessThan: Timestamp.fromDate(startOfDay.add(Duration(days: 1))))
              .get();

          if (existingTxs.docs.isEmpty) {
            // Get the category reference
            final categoryRef = data['category'] as DocumentReference;

            // Create transaction
            await _firestore.collection('transactions').add({
              'userid': userId,
              'amount': data['amount'] ?? 0.0,
              'timestamp': Timestamp.fromDate(startOfDay),
              'category': categoryRef,
              'incomeId': doc.id, // Add this to track which income generated this transaction
            });

            // Update card balance if specified
            if (data['toCardId'] != null) {
              final cardRef = _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('cards')
                  .doc(data['toCardId']);

              final cardDoc = await cardRef.get();
              if (cardDoc.exists) {
                final currentBalance = (cardDoc.data()!['balance'] ?? 0.0).toDouble();
                final newBalance = currentBalance + (data['amount'] ?? 0.0).toDouble();
                await cardRef.update({'balance': newBalance});
              }
            }

            // Update lastGenerated
            await _firestore.collection('incomes').doc(doc.id).update({
              'lastGenerated': Timestamp.fromDate(startOfDay),
            });
          }

          nextDue = _calculateNextDueDate(nextDue, repeat);
        }
      }
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
        final nextMonth = DateTime(from.year, from.month + 1, 1);
        final day = from.day;
        final lastDayOfMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        return DateTime(nextMonth.year, nextMonth.month, day > lastDayOfMonth ? lastDayOfMonth : day);
      case 'annually':
        return DateTime(from.year + 1, from.month, from.day);
      default:
        return from;
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
      // Refresh the page if needed
      setState(() {});
    }
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
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('categories')
            .where('type', isEqualTo: 'income')
            .snapshots(),
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

          final categories = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown',
              'icon': data['icon'] ?? '💰',
              'description': data['description'] ?? '',
            };
          }).toList();

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
                      Text(
                        category['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
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