import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/ch/record_transaction.dart';
import 'package:fyp/ch/settings.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/wc/financial_plan.dart';
import 'package:fyp/wc/financial_tips.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:fyp/wc/trending.dart';
import 'package:intl/intl.dart';
import 'package:fyp/wc/gamification_page.dart';
import 'package:fyp/ch/billing_date_helper.dart';
import 'package:fyp/ch/records_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  String currentPeriod = '';
  String displayText = DateFormat('MMM').format(DateTime.now());
  bool? showExpenses;
  double availableScreenWidth = 0;
  double availableScreenHeight = 0;
  int selectedIndex = 0;
  String viewMode = 'month';
  DateTime selectedDate = DateTime.now();
  String popupMode = 'month';


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ScrollController _scrollController = ScrollController();

  // Cache for category data to avoid repeated Firestore queries
  final Map<String, Map<String, dynamic>> _categoryCache = {};

  @override
  void initState() {
    super.initState();
    _updateCurrentPeriod();
    _checkAndGenerateSubscriptions();
    _checkAndGenerateIncomes();
    print('HomePage initialized, User ID: ${_auth.currentUser?.uid}');

  }

  Future<List<Map<String, dynamic>>> _processTransactionsWithCategories(
      List<Map<String, dynamic>> transactions) async {

    List<Map<String, dynamic>> processedTransactions = [];

    for (var tx in transactions) {
      Map<String, dynamic> processedTx = {...tx};

      // Handle transactions with category reference (both expense and income categories)
      if (tx.containsKey('category') && tx['category'] != null) {
        final categoryRef = tx['category'] as DocumentReference;
        final categoryId = categoryRef.id;
        Map<String, dynamic> categoryData = _categoryCache[categoryId] ?? {};

        if (categoryData.isEmpty) {
          final categorySnapshot = await categoryRef.get();
          categoryData = categorySnapshot.exists
              ? (categorySnapshot.data() as Map<String, dynamic>? ??
              {'icon': '❓', 'name': 'Unknown Category', 'type': 'unknown'})
              : {'icon': '❓', 'name': 'Unknown Category', 'type': 'unknown'};
          _categoryCache[categoryId] = categoryData;
        }

        processedTx.addAll({
          'categoryIcon': categoryData['icon'] as String? ?? '❓',
          'categoryName': categoryData['name'] as String? ?? 'Unknown Category',
          'categoryType': categoryData['type'] as String? ?? 'unknown',
        });

        // Debug logging for income transactions
        if (tx.containsKey('incomeId') && tx['incomeId'] != null) {
          print('Processing automated income: ${categoryData['name']} - Type: ${categoryData['type']} - Icon: ${categoryData['icon']}');
        }
      }
      // Handle manual card transactions (no category reference)
      else if (tx.containsKey('cardId') && tx['cardId'] != null) {
        final String type = tx['type'] ?? 'transaction';
        processedTx.addAll({
          'categoryIcon': _getIconForTransactionType(type),
          'categoryName': _getNameForTransactionType(type),
          'categoryType': type == 'income' ? 'income' : 'expense',
        });
      }
      // Handle card transfers
      else if (tx.containsKey('fromCardId') || tx.containsKey('toCardId')) {
        final String type = tx['type'] ?? 'transfer';
        processedTx.addAll({
          'categoryIcon': _getIconForTransactionType(type),
          'categoryName': _getNameForTransactionType(type),
          'categoryType': 'expense',
        });
      }
      // Handle subscription transactions
      else if (tx.containsKey('subscriptionId') && tx['subscriptionId'] != null) {
        processedTx.addAll({
          'categoryIcon': '💳',
          'categoryName': tx['name'] ?? 'Subscription',
          'categoryType': 'expense',
        });
      }
      // Fallback for transactions without clear category
      else {
        processedTx.addAll({
          'categoryIcon': '❓',
          'categoryName': 'Unknown Transaction',
          'categoryType': 'unknown',
        });
      }

      // Note: We no longer process card names for display since they'll be shown in details page
      processedTransactions.add(processedTx);
    }

    return processedTransactions;
  }

  String _getIconForTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return '🔄';
      case 'goal_deposit':
        return '💰';
      case 'goal_withdrawal':
        return '🏦';
      case 'subscription':
        return '💳';
      case 'income':
        return '💵';
      case 'expense':
        return '💸';
      case 'card_creation':
        return '🆕';
      default:
        return '💳';
    }
  }

  String _getNameForTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return 'Card Transfer';
      case 'goal_deposit':
        return 'Goal Deposit';
      case 'goal_withdrawal':
        return 'Goal Withdrawal';
      case 'subscription':
        return 'Subscription';
      case 'income':
        return 'Income';
      case 'expense':
        return 'Expense';
      case 'card_creation':
        return 'Card Setup';
      default:
        return 'Transaction';
    }
  }

  Future<void> _checkAndGenerateSubscriptions() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in, skipping subscription check');
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    print('Checking subscriptions for user $userId on $today');

    try {
      final subscriptions = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .get();

      print('Found ${subscriptions.docs.length} subscriptions');

      for (final doc in subscriptions.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final repeat = data['repeat'] ?? 'monthly';
        final lastGenerated = data['lastGenerated'] != null
            ? (data['lastGenerated'] as Timestamp).toDate()
            : startDate;
        print('Processing subscription ${doc.id}: name=${data['name']}, repeat=$repeat, lastGenerated=$lastGenerated');

        DateTime nextDue = _calculateNextDueDate(lastGenerated, repeat);
        print('Calculated nextDue: $nextDue');

        while (!nextDue.isAfter(today)) {
          final startOfDay = DateTime(nextDue.year, nextDue.month, nextDue.day);
          print('Generating transaction for ${data['name']} on $nextDue');

          final existingTxs = await _firestore
              .collection('transactions')
              .where('userId', isEqualTo: userId)
              .where('subscriptionId', isEqualTo: doc.id)
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('timestamp', isLessThan: Timestamp.fromDate(startOfDay.add(Duration(days: 1))))
              .get();

          if (existingTxs.docs.isEmpty) {
            print('No existing transaction found for ${data['name']} on $startOfDay, creating new one');

            final fromCardId = data['fromCardId'];

            if (fromCardId != null && fromCardId.isNotEmpty) {
              // Deduct from card + create transaction in a single Firestore transaction
              await _firestore.runTransaction((transaction) async {
                final cardRef = _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('cards')
                    .doc(fromCardId);

                final cardSnap = await transaction.get(cardRef);
                String? cardName;

                if (cardSnap.exists) {
                  final cardData = cardSnap.data() as Map<String, dynamic>;
                  final currentBalance = (cardData['balance'] ?? 0.0).toDouble();
                  final newBalance = currentBalance - (data['amount'] ?? 0.0);
                  cardName = cardData['name'] as String?; // Get card name
                  transaction.update(cardRef, {'balance': newBalance});
                }

                final txRef = _firestore.collection('transactions').doc();
                transaction.set(txRef, {
                  'userId': userId,
                  'amount': data['amount'] ?? 0.0,
                  'timestamp': Timestamp.fromDate(startOfDay),
                  'category': _firestore.doc('/categories/qOIeFiz2HjETIU1dyerW'),
                  'icon': data['icon'] ?? '💰',
                  'name': data['name'] ?? 'Subscription',
                  'subscriptionId': doc.id,
                  'categoryType': 'expense',
                  'type': 'subscription',
                  'fromCardId': fromCardId,
                  'fromCardName': cardName, // Store card name for display
                });
              });
            } else {
              // No linked card → just create transaction
              await _firestore.collection('transactions').add({
                'userId': userId,
                'amount': data['amount'] ?? 0.0,
                'timestamp': Timestamp.fromDate(startOfDay),
                'category': _firestore.doc('/categories/qOIeFiz2HjETIU1dyerW'),
                'icon': data['icon'] ?? '💰',
                'name': data['name'] ?? 'Subscription',
                'subscriptionId': doc.id,
                'categoryType': 'expense',
                'type': 'subscription',
              });
            }

            // Update lastGenerated after transaction creation
            await _firestore.collection('subscriptions').doc(doc.id).update({
              'lastGenerated': Timestamp.fromDate(startOfDay),
            });

            print('Transaction created and lastGenerated updated for ${data['name']} on $startOfDay');
          } else {
            print('Transaction already exists for ${data['name']} on $startOfDay, skipping');
          }

          nextDue = _calculateNextDueDate(nextDue, repeat);
        }
      }
    } catch (e) {
      print('Error generating subscriptions: $e');
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
        print('Unknown repeat type: $repeat, defaulting to no change');
        return from;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _showCustomDatePicker() {
    availableScreenWidth = MediaQuery.of(context).size.width;
    availableScreenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 60.0),
              child: Container(
                width: availableScreenWidth * 0.9,
                constraints: BoxConstraints(
                  maxHeight: availableScreenHeight * 0.75,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromRGBO(40, 42, 41, 1),
                      Color.fromRGBO(28, 30, 29, 1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.teal.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with close button
                    Container(
                      padding: EdgeInsets.fromLTRB(24, 20, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Period',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Choose your time period',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(Icons.close, color: Colors.white70, size: 24),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mode Toggle (Month/Year)
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 24),
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  popupMode = 'month';
                                });
                              },
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: popupMode == 'month'
                                      ? Colors.teal
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: popupMode == 'month' ? [
                                    BoxShadow(
                                      color: Colors.teal.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ] : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_view_month,
                                      color: popupMode == 'month' ? Colors.white : Colors.white60,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Month',
                                      style: TextStyle(
                                        color: popupMode == 'month' ? Colors.white : Colors.white60,
                                        fontSize: 16,
                                        fontWeight: popupMode == 'month'
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  popupMode = 'year';
                                });
                              },
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: popupMode == 'year'
                                      ? Colors.teal
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: popupMode == 'year' ? [
                                    BoxShadow(
                                      color: Colors.teal.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ] : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.date_range,
                                      color: popupMode == 'year' ? Colors.white : Colors.white60,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Year',
                                      style: TextStyle(
                                        color: popupMode == 'year' ? Colors.white : Colors.white60,
                                        fontSize: 16,
                                        fontWeight: popupMode == 'year'
                                            ? FontWeight.w600
                                            : FontWeight.normal,
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

                    SizedBox(height: 24),

                    // Current Selection Display
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: 24),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.teal.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.schedule,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Period',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                popupMode == 'month'
                                    ? DateFormat('MMMM yyyy').format(selectedDate)
                                    : selectedDate.year.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Selection Grid
                    Flexible(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 24),
                        child: popupMode == 'month'
                            ? _buildMonthGrid(setState)
                            : _buildYearGrid(setState),
                      ),
                    ),

                    SizedBox(height: 24),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

// Add these helper methods to build the month and year grids

  Widget _buildMonthGrid(StateSetter setState) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: List.generate(12, (index) {
        final month = DateTime(selectedDate.year, index + 1);
        final isSelected = selectedDate.month == index + 1;
        final isCurrentMonth = DateTime.now().month == index + 1 &&
            DateTime.now().year == selectedDate.year;

        return GestureDetector(
          onTap: () {
            _updateCurrentPeriod(DateTime(selectedDate.year, index + 1));
            Navigator.pop(context); // Close immediately after selection
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.teal, Colors.teal.shade700],
              ) : null,
              color: isSelected
                  ? null
                  : isCurrentMonth
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.teal.shade300
                    : isCurrentMonth
                    ? Colors.orange.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('MMM').format(month),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isCurrentMonth
                        ? Colors.orange.shade300
                        : Colors.white70,
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isCurrentMonth && !isSelected) ...[
                  SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildYearGrid(StateSetter setState) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2,
      children: List.generate(5, (index) {
        final year = selectedDate.year + (index - 2); // Show 2 years before and 2 after
        final isSelected = selectedDate.year == year;
        final isCurrentYear = DateTime.now().year == year;

        return GestureDetector(
          onTap: () {
            _updateCurrentPeriod(DateTime(year, selectedDate.month));
            Navigator.pop(context); // Close immediately after selection
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.teal, Colors.teal.shade700],
              ) : null,
              color: isSelected
                  ? null
                  : isCurrentYear
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.teal.shade300
                    : isCurrentYear
                    ? Colors.orange.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  year.toString(),
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : isCurrentYear
                        ? Colors.orange.shade300
                        : Colors.white70,
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isCurrentYear && !isSelected) ...[
                  SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  void _toggleViewMode() {
    setState(() {
      viewMode = viewMode == 'month' ? 'year' : 'month';
    });
    _updateCurrentPeriod(selectedDate);
  }

  void _setTransactionType(bool? type) {
    setState(() {
      showExpenses = type;
    });
  }

  Future<void> _deleteTransaction(String transactionId) async {
    try {
      final transactionDoc = await _firestore.collection('transactions').doc(transactionId).get();
      if (!transactionDoc.exists) return;

      final transactionData = transactionDoc.data()!;
      final amount = (transactionData['amount'] as num).toDouble();
      final incomeId = transactionData['incomeId'] as String?;

      if (incomeId != null) {
        final incomeDoc = await _firestore.collection('incomes').doc(incomeId).get();
        if (incomeDoc.exists) {
          final incomeData = incomeDoc.data()!;
          final toCardId = incomeData['toCardId'] as String?;

          if (toCardId != null) {
            final cardRef = _firestore.collection('users').doc(_auth.currentUser!.uid).collection('cards').doc(toCardId);

            await _firestore.runTransaction((transaction) async {
              final cardDoc = await transaction.get(cardRef);
              if (cardDoc.exists) {
                final currentBalance = (cardDoc.data()!['balance'] ?? 0.0).toDouble();
                final newBalance = currentBalance - amount;
                transaction.update(cardRef, {'balance': newBalance});
              }
            });
          }
        }
      }

      await _firestore.collection('transactions').doc(transactionId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted and card balance updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete transaction: $e')),
      );
    }
  }

  void _updateCurrentPeriod([DateTime? startDate]) {
    setState(() {
      selectedDate = startDate ?? DateTime.now();

      if (viewMode == 'month') {
        displayText = DateFormat('MMM').format(selectedDate);
        BillingDateHelper.getBillingPeriodForDate(selectedDate).then((billingPeriod) {
          final start = billingPeriod['startDate']!;
          final end = billingPeriod['endDate']!;
          final formatter = DateFormat('d MMM');
          setState(() {
            currentPeriod = '${formatter.format(start)} - ${formatter.format(end)}';
          });
        });
      } else {
        displayText = selectedDate.year.toString();
        BillingDateHelper.getBillingStartDate().then((billStartDate) {
          DateTime yearStart, yearEnd;
          if (selectedDate.day >= billStartDate) {
            yearStart = DateTime(selectedDate.year, selectedDate.month, billStartDate);
          } else {
            yearStart = DateTime(selectedDate.year - 1, selectedDate.month, billStartDate);
          }
          yearEnd = DateTime(yearStart.year + 1, yearStart.month, billStartDate - 1, 23, 59, 59);
          final formatter = DateFormat('d MMM');
          setState(() {
            currentPeriod = '${formatter.format(yearStart)} ${yearStart.year} - ${formatter.format(yearEnd)} ${yearEnd.year}';
          });
        });
      }
    });
  }

  Future<Map<String, DateTime>> _getYearPeriodForDate(DateTime date) async {
    final billStartDate = await BillingDateHelper.getBillingStartDate();
    DateTime yearStart, yearEnd;

    if (date.day >= billStartDate) {
      yearStart = DateTime(date.year, date.month, billStartDate);
    } else {
      yearStart = DateTime(date.year - 1, date.month, billStartDate);
    }

    yearEnd = DateTime(yearStart.year + 1, yearStart.month, billStartDate - 1, 23, 59, 59);

    return {
      'startDate': yearStart,
      'endDate': yearEnd,
    };
  }

  Future<void> _checkAndGenerateIncomes() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      final incomes = await _firestore
          .collection('incomes')
          .where('userId', isEqualTo: userId)
          .where('isEnabled', isEqualTo: true)
          .get();

      for (final doc in incomes.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final repeat = data['repeat'] ?? 'monthly';
        final lastGenerated = data['lastGenerated'] != null
            ? (data['lastGenerated'] as Timestamp).toDate()
            : startDate;

        DateTime nextDue = _calculateNextIncomeDueDate(lastGenerated, repeat);

        while (!nextDue.isAfter(today)) {
          final startOfDay = DateTime(nextDue.year, nextDue.month, nextDue.day);

          final existingTxs = await _firestore
              .collection('transactions')
              .where('userId', isEqualTo: userId)
              .where('incomeId', isEqualTo: doc.id)
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('timestamp', isLessThan: Timestamp.fromDate(startOfDay.add(Duration(days: 1))))
              .get();

          if (existingTxs.docs.isEmpty) {
            final categoryRef = data['category'] as DocumentReference;
            final toCardId = data['toCardId'] as String?;

            // Use Firestore transaction for atomicity
            await _firestore.runTransaction((transaction) async {
              DocumentSnapshot? cardDoc;
              String? cardName;

              // READ FIRST: Get card document if needed
              if (toCardId != null) {
                final cardRef = _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('cards')
                    .doc(toCardId);
                cardDoc = await transaction.get(cardRef);

                if (cardDoc.exists) {
                  final cardData = cardDoc.data() as Map<String, dynamic>;
                  cardName = cardData['name'] as String?; // Get card name
                }
              }

              // WRITE: Create the transaction with all necessary fields including card name
              final txRef = _firestore.collection('transactions').doc();
              transaction.set(txRef, {
                'userId': userId,
                'amount': data['amount'] ?? 0.0,
                'timestamp': Timestamp.fromDate(startOfDay),
                'category': categoryRef,
                'incomeId': doc.id,
                'type': 'income', // Ensure it's marked as income
                'description': 'Automated income: ${data['name'] ?? 'Income'}',
                if (toCardId != null) 'toCardId': toCardId,
                if (cardName != null) 'toCardName': cardName, // Store card name for display
              });

              // WRITE: Update card balance if specified and card exists
              if (toCardId != null && cardDoc != null && cardDoc.exists) {
                final cardRef = _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('cards')
                    .doc(toCardId);

                final currentBalance = (cardDoc.data()! as Map<String, dynamic>)['balance'] ?? 0.0;
                final newBalance = (currentBalance as num).toDouble() + (data['amount'] ?? 0.0).toDouble();
                transaction.update(cardRef, {'balance': newBalance});
              }
            });

            // Update lastGenerated after transaction creation
            await _firestore.collection('incomes').doc(doc.id).update({
              'lastGenerated': Timestamp.fromDate(startOfDay),
            });

            print('Automated income transaction created for ${data['name']} on $startOfDay');
          }

          nextDue = _calculateNextIncomeDueDate(nextDue, repeat);
        }
      }
    } catch (e) {
      print('Error generating incomes: $e');
    }
  }

  DateTime _calculateNextIncomeDueDate(DateTime from, String repeat) {
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



  @override
  Widget build(BuildContext context) {
    super.build(context);
    availableScreenWidth = MediaQuery.of(context).size.width - 50;

    String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in');
      return Scaffold(body: Center(child: Text('Please log in to view transactions')));
    }

    return StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('type', whereNotIn: ['card_creation', 'transfer', 'goal_deposit', 'goal_withdrawal'])
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError) {
          print('StreamBuilder Error: ${snapshot.error}');
          return Scaffold(body: Center(child: Text('Error loading data: ${snapshot.error}')));
        }

        final transactions = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data, // Include all fields from the document
            'amount': (data['amount'] is int)
                ? (data['amount'] as int).toDouble()
                : (data['amount'] as double? ?? 0.0),
            'timestamp': data['timestamp'] as Timestamp?,
          };
        }).where((tx) => tx['timestamp'] != null).toList();

        if (viewMode == 'year') {
          return FutureBuilder<Map<String, DateTime>>(
            future: _getYearPeriodForDate(selectedDate),
            builder: (context, yearSnapshot) {
              if (!yearSnapshot.hasData) {
                return _buildLoadingSkeleton();
              }

              final yearPeriod = yearSnapshot.data!;
              final startDate = yearPeriod['startDate']!;
              final endDate = yearPeriod['endDate']!;

              final filteredTransactions = transactions.where((tx) {
                final txDate = tx['timestamp']?.toDate();
                if (txDate == null) return false;
                return txDate.isAfter(startDate.subtract(Duration(seconds: 1))) &&
                    txDate.isBefore(endDate.add(Duration(seconds: 1)));
              }).toList();

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _processTransactionsWithCategories(filteredTransactions),
                builder: (context, categorySnapshot) {
                  if (!categorySnapshot.hasData) {
                    return _buildLoadingSkeleton();
                  }

                  final allTransactionsWithCategories = categorySnapshot.data!;
                  final expenseTransactions = allTransactionsWithCategories
                      .where((tx) => tx['categoryType'] == 'expense').toList();
                  final incomeTransactions = allTransactionsWithCategories
                      .where((tx) => tx['categoryType'] == 'income').toList();

                  final displayedTransactions = allTransactionsWithCategories.where((tx) {
                    if (showExpenses == null) return true;
                    if (showExpenses == true) return tx['categoryType'] == 'expense';
                    if (showExpenses == false) return tx['categoryType'] == 'income';
                    return true;
                  }).toList();

                  double totalExpenses = 0.0;
                  double totalIncome = 0.0;
                  for (var tx in allTransactionsWithCategories) {
                    final amount = tx['amount'] as double;
                    if (tx['categoryType'] == 'expense') {
                      totalExpenses += amount.abs();
                    } else if (tx['categoryType'] == 'income') {
                      totalIncome += amount;
                    }
                  }

                  Widget emptyStateWidget;
                  bool showAddButton = false;

                  if (allTransactionsWithCategories.isEmpty) {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text(
                            'Welcome! No transactions yet.',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center
                        ),
                        SizedBox(height: 12),
                        Text(
                            'Start tracking your expenses and income',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                            textAlign: TextAlign.center
                        ),
                      ],
                    );
                    showAddButton = true;
                  } else if (showExpenses == true && expenseTransactions.isEmpty) {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.money_off, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text(
                            'No expense transactions recorded yet!',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center
                        ),
                        SizedBox(height: 12),
                        Text(
                            'Add your first expense to start tracking',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                            textAlign: TextAlign.center
                        ),
                      ],
                    );
                    showAddButton = true;
                  } else if (showExpenses == false && incomeTransactions.isEmpty) {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.trending_up, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text(
                            'No income transactions recorded yet!',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center
                        ),
                        SizedBox(height: 12),
                        Text(
                            'Add your first income to start tracking',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                            textAlign: TextAlign.center
                        ),
                      ],
                    );
                    showAddButton = true;
                  } else {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text(
                            'No transactions found for this period',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center
                        ),
                        SizedBox(height: 12),
                        Text(
                            'Try selecting a different time period',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                            textAlign: TextAlign.center
                        ),
                      ],
                    );
                  }

                  if (displayedTransactions.isEmpty) {
                    return Scaffold(
                      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                      appBar: AppBar(
                        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                        elevation: 0,
                        automaticallyImplyLeading: false,
                        title: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(displayText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(currentPeriod, style: TextStyle(fontSize: 16, color: Colors.white)),
                          ],
                        ),
                        centerTitle: true,
                        actions: [
                          IconButton(icon: Icon(Icons.calendar_today, color: Colors.white), onPressed: _showCustomDatePicker),
                          IconButton(icon: Icon(viewMode == 'month' ? Icons.view_agenda : Icons.view_week, color: Colors.white), onPressed: _toggleViewMode),
                        ],
                      ),
                      body: Column(
                        children: [
                          if (allTransactionsWithCategories.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _setTransactionType(showExpenses == true ? null : true),
                                      child: Card(
                                        color: showExpenses == true ? Colors.blue[700] : Color.fromRGBO(33, 35, 34, 1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.attach_money, color: Colors.yellow),
                                                  const SizedBox(width: 8),
                                                  Text('Expenses', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text('RM${totalExpenses.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _setTransactionType(showExpenses == false ? null : false),
                                      child: Card(
                                        color: showExpenses == false ? Colors.green[700] : Color.fromRGBO(33, 35, 34, 1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.monetization_on, color: Colors.yellow),
                                                  const SizedBox(width: 8),
                                                  Text('Income', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text('RM${totalIncome.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Spacer(flex: 2),
                                  emptyStateWidget,
                                  if (showAddButton) ...[
                                    SizedBox(height: 32),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => RecordTransactionPage()));
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        allTransactionsWithCategories.isEmpty ? 'Add Your First Transaction' : showExpenses == true ? 'Add Expense' : 'Add Income',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                  Spacer(flex: 3),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      floatingActionButton: PersistentAddButton(
                        scrollController: _scrollController,
                      ),
                      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
                      bottomNavigationBar: BottomNavBar(currentIndex: selectedIndex, onTap: _handleNavBarTap),
                    );
                  }

                  return Scaffold(
                    backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                    appBar: AppBar(
                      automaticallyImplyLeading: false,
                      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                      title: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(currentPeriod, style: TextStyle(fontSize: 16, color: Colors.white)),
                        ],
                      ),
                      centerTitle: true,
                      actions: [
                        IconButton(icon: Icon(Icons.calendar_today, color: Colors.white), onPressed: _showCustomDatePicker),
                        IconButton(icon: Icon(viewMode == 'month' ? Icons.view_agenda : Icons.view_week, color: Colors.white), onPressed: _toggleViewMode),
                      ],
                    ),
                    body: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _setTransactionType(showExpenses == true ? null : true),
                                  child: Card(
                                    color: showExpenses == true ? Colors.blue[700] : Color.fromRGBO(33, 35, 34, 1),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.attach_money, color: Colors.yellow),
                                              const SizedBox(width: 8),
                                              Text('Expenses', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('RM${totalExpenses.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _setTransactionType(showExpenses == false ? null : false),
                                  child: Card(
                                    color: showExpenses == false ? Colors.green[700] : Color.fromRGBO(33, 35, 34, 1),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.monetization_on, color: Colors.yellow),
                                              const SizedBox(width: 8),
                                              Text('Income', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('RM${totalIncome.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _groupTransactions(displayedTransactions).length,
                              itemBuilder: (context, index) {
                                final group = _groupTransactions(displayedTransactions)[index];
                                final groupDate = group['date'] as DateTime;
                                final groupTxs = group['transactions'] as List<Map<String, dynamic>>;

                                double groupExpenses = 0.0;
                                double groupIncome = 0.0;

                                for (var tx in groupTxs) {
                                  final amount = tx['amount'] as double;
                                  if (tx['categoryType'] == 'expense') {
                                    groupExpenses += amount.abs();
                                  } else if (tx['categoryType'] == 'income') {
                                    groupIncome += amount;
                                  }
                                }

                                final groupLabel = DateFormat(viewMode == 'month' ? 'd MMM EEE' : 'MMMM yyyy').format(groupDate);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0, bottom: 4, right: 3),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(groupLabel, style: TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('E RM${groupExpenses.toStringAsFixed(1)}', style: TextStyle(color: Colors.red[100])),
                                              SizedBox(width: 8),
                                              Text('I RM${groupIncome.toStringAsFixed(1)}', style: TextStyle(color: Colors.green[200])),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...groupTxs.map((tx) => Column(
                                      children: [
                                        _buildTransactionItem(tx, tx['categoryIcon'] as String? ?? '❓', tx['categoryName'] as String? ?? 'Unknown Category', tx['categoryType'] as String? ?? 'unknown'),
                                        const SizedBox(height: 10),
                                      ],
                                    )),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    floatingActionButton: PersistentAddButton(
                      scrollController: _scrollController,
                    ),
                    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
                    bottomNavigationBar: BottomNavBar(currentIndex: selectedIndex, onTap: _handleNavBarTap),
                  );
                },
              );
            },
          );
        } else {
          return FutureBuilder<Map<String, DateTime>>(
            future: BillingDateHelper.getBillingPeriodForDate(selectedDate),
            builder: (context, billingSnapshot) {
              if (!billingSnapshot.hasData) {
                return _buildLoadingSkeleton();
              }

              final billingPeriod = billingSnapshot.data!;
              final startDate = billingPeriod['startDate']!;
              final endDate = billingPeriod['endDate']!;

              final filteredTransactions = transactions.where((tx) {
                final txDate = tx['timestamp']?.toDate();
                if (txDate == null) return false;
                return txDate.isAfter(startDate.subtract(Duration(seconds: 1))) &&
                    txDate.isBefore(endDate.add(Duration(seconds: 1)));
              }).toList();

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _processTransactionsWithCategories(filteredTransactions),
                builder: (context, categorySnapshot) {
                  if (!categorySnapshot.hasData) {
                    return _buildLoadingSkeleton();
                  }

                  final allTransactionsWithCategories = categorySnapshot.data!;
                  final expenseTransactions = allTransactionsWithCategories
                      .where((tx) => tx['categoryType'] == 'expense').toList();
                  final incomeTransactions = allTransactionsWithCategories
                      .where((tx) => tx['categoryType'] == 'income').toList();

                  final displayedTransactions = allTransactionsWithCategories.where((tx) {
                    if (showExpenses == null) return true;
                    if (showExpenses == true) return tx['categoryType'] == 'expense';
                    if (showExpenses == false) return tx['categoryType'] == 'income';
                    return true;
                  }).toList();

                  double totalExpenses = 0.0;
                  double totalIncome = 0.0;
                  for (var tx in allTransactionsWithCategories) {
                    final amount = tx['amount'] as double;
                    if (tx['categoryType'] == 'expense') {
                      totalExpenses += amount.abs();
                    } else if (tx['categoryType'] == 'income') {
                      totalIncome += amount;
                    }
                  }

                  Widget emptyStateWidget;
                  bool showAddButton = false;

                  if (allTransactionsWithCategories.isEmpty) {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text('Welcome! No transactions yet.', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        SizedBox(height: 12),
                        Text('Start tracking your expenses and income', style: TextStyle(color: Colors.grey[400], fontSize: 16), textAlign: TextAlign.center),
                      ],
                    );
                    showAddButton = true;
                  } else if (showExpenses == true && expenseTransactions.isEmpty) {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.money_off, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text('No expense transactions recorded yet!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        SizedBox(height: 12),
                        Text('Add your first expense to start tracking', style: TextStyle(color: Colors.grey[400], fontSize: 16), textAlign: TextAlign.center),
                      ],
                    );
                    showAddButton = true;
                  } else if (showExpenses == false && incomeTransactions.isEmpty) {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.trending_up, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text('No income transactions recorded yet!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        SizedBox(height: 12),
                        Text('Add your first income to start tracking', style: TextStyle(color: Colors.grey[400], fontSize: 16), textAlign: TextAlign.center),
                      ],
                    );
                    showAddButton = true;
                  } else {
                    emptyStateWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey[600]),
                        SizedBox(height: 24),
                        Text('No transactions found for this period', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        SizedBox(height: 12),
                        Text('Try selecting a different time period', style: TextStyle(color: Colors.grey[400], fontSize: 16), textAlign: TextAlign.center),
                      ],
                    );
                  }

                  if (displayedTransactions.isEmpty) {
                    return Scaffold(
                      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                      appBar: AppBar(
                        automaticallyImplyLeading: false,
                        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                        title: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(displayText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(currentPeriod, style: TextStyle(fontSize: 16, color: Colors.white)),
                          ],
                        ),
                        centerTitle: true,
                        actions: [
                          IconButton(icon: Icon(Icons.calendar_today, color: Colors.white), onPressed: _showCustomDatePicker),
                          IconButton(icon: Icon(viewMode == 'month' ? Icons.view_agenda : Icons.view_week, color: Colors.white), onPressed: _toggleViewMode),
                        ],
                      ),
                      body: Column(
                        children: [
                          if (allTransactionsWithCategories.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _setTransactionType(showExpenses == true ? null : true),
                                      child: Card(
                                        color: showExpenses == true ? Colors.blue[700] : Color.fromRGBO(33, 35, 34, 1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.attach_money, color: Colors.yellow),
                                                  const SizedBox(width: 8),
                                                  Text('Expenses', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text('RM${totalExpenses.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _setTransactionType(showExpenses == false ? null : false),
                                      child: Card(
                                        color: showExpenses == false ? Colors.green[700] : Color.fromRGBO(33, 35, 34, 1),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.monetization_on, color: Colors.yellow),
                                                  const SizedBox(width: 8),
                                                  Text('Income', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text('RM${totalIncome.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    emptyStateWidget,
                                    if (showAddButton) ...[
                                      SizedBox(height: 32),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => RecordTransactionPage()));
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          allTransactionsWithCategories.isEmpty ? 'Add Your First Transaction' : showExpenses == true ? 'Add Expense' : 'Add Income',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      floatingActionButton: PersistentAddButton(
                        scrollController: _scrollController,
                      ),
                      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
                      bottomNavigationBar: BottomNavBar(currentIndex: selectedIndex, onTap: _handleNavBarTap),
                    );
                  }

                  return Scaffold(
                    backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                    appBar: AppBar(
                      automaticallyImplyLeading: false,
                      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
                      title: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(displayText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(currentPeriod, style: TextStyle(fontSize: 16, color: Colors.white)),
                        ],
                      ),
                      centerTitle: true,
                      actions: [
                        IconButton(icon: Icon(Icons.calendar_today, color: Colors.white), onPressed: _showCustomDatePicker),
                        IconButton(icon: Icon(viewMode == 'month' ? Icons.view_agenda : Icons.view_week, color: Colors.white), onPressed: _toggleViewMode),
                      ],
                    ),
                    body: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _setTransactionType(showExpenses == true ? null : true),
                                  child: Card(
                                    color: showExpenses == true ? Colors.blue[700] : Color.fromRGBO(33, 35, 34, 1),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.attach_money, color: Colors.yellow),
                                              const SizedBox(width: 8),
                                              Text('Expenses', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('RM${totalExpenses.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _setTransactionType(showExpenses == false ? null : false),
                                  child: Card(
                                    color: showExpenses == false ? Colors.green[700] : Color.fromRGBO(33, 35, 34, 1),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.monetization_on, color: Colors.yellow),
                                              const SizedBox(width: 8),
                                              Text('Income', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('RM${totalIncome.toStringAsFixed(1)}', style: TextStyle(color: Colors.white, fontSize: 18)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _groupTransactions(displayedTransactions).length,
                              itemBuilder: (context, index) {
                                final group = _groupTransactions(displayedTransactions)[index];
                                final groupDate = group['date'] as DateTime;
                                final groupTxs = group['transactions'] as List<Map<String, dynamic>>;

                                double groupExpenses = 0.0;
                                double groupIncome = 0.0;

                                for (var tx in groupTxs) {
                                  final amount = tx['amount'] as double;
                                  if (tx['categoryType'] == 'expense') {
                                    groupExpenses += amount.abs();
                                  } else if (tx['categoryType'] == 'income') {
                                    groupIncome += amount;
                                  }
                                }

                                final groupLabel = DateFormat(viewMode == 'month' ? 'd MMM EEE' : 'MMMM yyyy').format(groupDate);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0, bottom: 4, right: 3),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(groupLabel, style: TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('E RM${groupExpenses.toStringAsFixed(1)}', style: TextStyle(color: Colors.red[100])),
                                              SizedBox(width: 8),
                                              Text('I RM${groupIncome.toStringAsFixed(1)}', style: TextStyle(color: Colors.green[200])),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...groupTxs.map((tx) => Column(
                                      children: [
                                        _buildTransactionItem(tx, tx['categoryIcon'] as String? ?? '❓', tx['categoryName'] as String? ?? 'Unknown Category', tx['categoryType'] as String? ?? 'unknown'),
                                        const SizedBox(height: 10),
                                      ],
                                    )),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    floatingActionButton: PersistentAddButton(
                      scrollController: _scrollController,
                    ),
                    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
                    bottomNavigationBar: BottomNavBar(currentIndex: selectedIndex, onTap: _handleNavBarTap),
                  );
                },
              );
            },
          );
        }
      },
    );
  }

  List<Map<String, dynamic>> _groupTransactions(List<Map<String, dynamic>> transactions) {
    Map<DateTime, List<Map<String, dynamic>>> groupedTransactions = {};
    for (var tx in transactions) {
      final txDate = tx['timestamp']!.toDate();
      final groupKey = viewMode == 'month' ? DateTime(txDate.year, txDate.month, txDate.day) : DateTime(txDate.year, txDate.month);
      groupedTransactions.putIfAbsent(groupKey, () => []).add(tx);
    }
    final sortedKeys = groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedKeys.map((key) => {'date': key, 'transactions': groupedTransactions[key]!}).toList();
  }

  void _handleNavBarTap(int index) {
    setState(() {
      selectedIndex = index;
      if (index == 0) {
        // Stay on HomePage
      } else if (index == 1) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TrendingPage()));
      } else if (index == 2) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialPlanPage()));
      } else if (index == 3) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
      }
    });
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, String categoryIcon, String categoryName, String categoryType) {
    final txDate = tx['timestamp']?.toDate();
    final amount = (tx['amount'] as double).abs(); // Always show positive amount for display

    return GestureDetector(
      onTap: () {
        // Navigate to RecordsDetailPage when transaction is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecordsDetailPage(
              transactionId: tx['id'] as String,
            ),
          ),
        );
      },
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color.fromRGBO(33, 35, 34, 1),
            title: Text('Delete Transaction', style: TextStyle(color: Colors.white)),
            content: Text('Are you sure you want to delete this transaction?', style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.teal))),
              TextButton(
                onPressed: () {
                  _deleteTransaction(tx['id']);
                  Navigator.pop(context);
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Card(
        color: Color.fromRGBO(33, 35, 34, 1),
        child: ListTile(
          leading: Text(categoryIcon, style: TextStyle(fontSize: 24)),
          title: Text(categoryName, style: TextStyle(color: Colors.white)),
          subtitle: Text(
              txDate != null ? DateFormat('HH:mm').format(txDate) : 'N/A',
              style: TextStyle(color: Colors.white70)
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RM${amount.toStringAsFixed(1)}', // Use absolute amount for display
                style: TextStyle(
                    fontSize: 16,
                    color: categoryType == 'expense' ? Colors.red : Colors.green
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(displayText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(currentPeriod, style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.calendar_today, color: Colors.white), onPressed: null),
          IconButton(icon: Icon(viewMode == 'month' ? Icons.view_agenda : Icons.view_week, color: Colors.white), onPressed: null),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Card(
                    color: Color.fromRGBO(33, 35, 34, 1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 60, height: 20, color: Colors.grey[700]),
                          SizedBox(height: 8),
                          Container(width: 40, height: 16, color: Colors.grey[700]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    color: Color.fromRGBO(33, 35, 34, 1),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 60, height: 20, color: Colors.grey[700]),
                          SizedBox(height: 8),
                          Container(width: 40, height: 16, color: Colors.grey[700]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 100, height: 16, color: Colors.grey[700]),
                        Container(width: 80, height: 16, color: Colors.grey[700]),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PersistentAddButton(
        scrollController: _scrollController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavBar(currentIndex: selectedIndex, onTap: _handleNavBarTap),
    );
  }
}