import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/ch/record_transaction.dart';
import 'package:fyp/ch/settings.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/wc/financial_tips.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:intl/intl.dart';
import 'package:fyp/wc/gamification_page.dart';
import 'package:fyp/ch/billing_date_helper.dart';

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
  bool _hasShownPopup = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasShownPopup) {
        _showTipPopup();
      }
    });
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
          .where('userid', isEqualTo: userId)
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
              .where('userid', isEqualTo: userId)
              .where('subscriptionId', isEqualTo: doc.id)
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('timestamp', isLessThan: Timestamp.fromDate(startOfDay.add(Duration(days: 1))))
              .get();

          if (existingTxs.docs.isEmpty) {
            print('No existing transaction found for ${data['name']} on $startOfDay, creating new one');
            await _firestore.collection('transactions').add({
              'userid': userId,
              'amount': data['amount'] ?? 0.0,
              'timestamp': Timestamp.fromDate(startOfDay),
              'category': _firestore.doc('/categories/qOIeFiz2HjETIU1dyerW'),
              'icon': data['icon'] ?? '💰',
              'name': data['name'] ?? 'Subscription',
              'subscriptionId': doc.id,
              'categoryType': 'expense',
            });

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
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: availableScreenWidth * 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(33, 35, 34, 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select Period',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    popupMode = 'month';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: popupMode == 'month' ? Colors.teal : Color.fromRGBO(33, 35, 34, 1),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Month'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    popupMode = 'year';
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: popupMode == 'year' ? Colors.teal : Color.fromRGBO(33, 35, 34, 1),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Year'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        height: 210,
                        child: GridView.count(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: [
                            if (popupMode == 'month')
                              ...List.generate(12, (index) {
                                final month = DateTime(selectedDate.year, index + 1);
                                return ElevatedButton(
                                  onPressed: () {
                                    _updateCurrentPeriod(DateTime(selectedDate.year, index + 1));
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(60, 60),
                                    backgroundColor: selectedDate.month == index + 1 ? Colors.teal : Color.fromRGBO(33, 35, 34, 1),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(DateFormat('MMM').format(month)),
                                );
                              }),
                            if (popupMode == 'year')
                              ...List.generate(3, (index) {
                                final year = selectedDate.year + (index - 1);
                                return ElevatedButton(
                                  onPressed: () {
                                    _updateCurrentPeriod(DateTime(year, selectedDate.month));
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedDate.year == year ? Colors.teal : Color.fromRGBO(33, 35, 34, 1),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(year.toString()),
                                );
                              }),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Confirm'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
          .where('userid', isEqualTo: userId)
          .where('isEnabled', isEqualTo: true)
          .get();

      for (final doc in incomes.docs) {
        final data = doc.data();
        final startDate = (data['startDate'] as Timestamp).toDate();
        final repeat = data['repeat'] ?? 'monthly';
        final lastGenerated = data['lastGenerated'] != null ? (data['lastGenerated'] as Timestamp).toDate() : startDate;

        DateTime nextDue = _calculateNextIncomeDueDate(lastGenerated, repeat);

        while (!nextDue.isAfter(today)) {
          final startOfDay = DateTime(nextDue.year, nextDue.month, nextDue.day);

          final existingTxs = await _firestore
              .collection('transactions')
              .where('userid', isEqualTo: userId)
              .where('incomeId', isEqualTo: doc.id)
              .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('timestamp', isLessThan: Timestamp.fromDate(startOfDay.add(Duration(days: 1))))
              .get();

          if (existingTxs.docs.isEmpty) {
            final categoryRef = data['category'] as DocumentReference;

            await _firestore.collection('transactions').add({
              'userid': userId,
              'amount': data['amount'] ?? 0.0,
              'timestamp': Timestamp.fromDate(startOfDay),
              'category': categoryRef,
              'incomeId': doc.id,
            });

            if (data['toCardId'] != null) {
              final cardRef = _firestore.collection('users').doc(userId).collection('cards').doc(data['toCardId']);

              final cardDoc = await cardRef.get();
              if (cardDoc.exists) {
                final currentBalance = (cardDoc.data()!['balance'] ?? 0.0).toDouble();
                final newBalance = currentBalance + (data['amount'] ?? 0.0).toDouble();
                await cardRef.update({'balance': newBalance});
              }
            }

            await _firestore.collection('incomes').doc(doc.id).update({
              'lastGenerated': Timestamp.fromDate(startOfDay),
            });
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

  Future<void> _showTipPopup() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || _hasShownPopup) {
      print('No user logged in or popup already shown');
      return;
    }

    try {
      final feedbackSnapshot = await _firestore.collection('users').doc(userId).collection('tips_feedback').doc('1').get();
      final feedbackData = feedbackSnapshot.data();
      final isIrrelevant = feedbackData != null && feedbackData['isIrrelevant'] is bool ? feedbackData['isIrrelevant'] as bool : false;

      if (isIrrelevant) {
        print('Tip suppressed, skipping popup');
        return;
      }

      final billingPeriod = await BillingDateHelper.getBillingPeriodForDate(DateTime.now());
      final startOfMonth = billingPeriod['startDate']!;
      final endOfMonth = billingPeriod['endDate']!;

      final transactionSnapshot = await _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      double diningSpending = 0.0;
      for (var doc in transactionSnapshot.docs) {
        final data = doc.data();
        final categoryRef = data['category'] as DocumentReference;

        final categoryId = categoryRef.id;
        Map<String, dynamic>? categoryData = _categoryCache[categoryId];

        if (categoryData == null) {
          final categorySnapshot = await categoryRef.get();
          if (!categorySnapshot.exists) {
            print('Category document does not exist for transaction ${doc.id}');
            continue;
          }
          categoryData = categorySnapshot.data() as Map<String, dynamic>?;
          _categoryCache[categoryId] = categoryData ?? {'icon': '❓', 'name': 'Unknown Category', 'type': 'unknown'};
        }

        final categoryName = categoryData != null && categoryData.containsKey('name') ? categoryData['name'] as String? ?? 'unknown' : 'unknown';
        final categoryType = categoryData != null && categoryData.containsKey('type') ? categoryData['type'] as String? ?? 'unknown' : 'unknown';
        final amount = (data['amount'] is int) ? (data['amount'] as int).toDouble() : (data['amount'] as double? ?? 0.0);

        if (categoryName == 'Dining' && categoryType == 'expense') {
          diningSpending += amount.abs();
        }
      }

      if (diningSpending > 300.0) {
        _hasShownPopup = true;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
            title: const Text('Cook at Home', style: TextStyle(color: Colors.white)),
            content: const Text('Your dining expenses are high this month. Try cooking at home to save RM200.', style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.teal)),
              ),
              TextButton(
                onPressed: () {
                  _firestore.collection('users').doc(userId).collection('tips_feedback').doc('1').set({
                    'isHelpful': false,
                    'isIrrelevant': true,
                    'timestamp': Timestamp.now(),
                  });
                  Navigator.pop(context);
                },
                child: const Text('Dismiss', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Error in _showTipPopup: $e');
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
      stream: _firestore.collection('transactions').where('userid', isEqualTo: userId).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingSkeleton();
        }

        if (snapshot.hasError) {
          print('StreamBuilder Error: ${snapshot.error}');
          return Scaffold(body: Center(child: Text('Error loading data: ${snapshot.error}')));
        }

        final transactions = snapshot.data!.docs.map((doc) {
          return {
            'id': doc.id,
            'category': doc['category'] as DocumentReference,
            'amount': (doc['amount'] is int) ? (doc['amount'] as int).toDouble() : (doc['amount'] as double? ?? 0.0),
            'timestamp': doc['timestamp'] as Timestamp?,
          };
        }).whereType<Map<String, dynamic>>().toList();

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
                return txDate.isAfter(startDate.subtract(Duration(seconds: 1))) && txDate.isBefore(endDate.add(Duration(seconds: 1)));
              }).toList();

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: Future.wait(
                  filteredTransactions.map((tx) async {
                    final categoryRef = tx['category'] as DocumentReference;
                    final categoryId = categoryRef.id;
                    Map<String, dynamic> categoryData = _categoryCache[categoryId] ?? {};

                    if (categoryData.isEmpty) {
                      final categorySnapshot = await categoryRef.get();
                      categoryData = categorySnapshot.exists
                          ? (categorySnapshot.data() as Map<String, dynamic>? ?? {'icon': '❓', 'name': 'Unknown Category', 'type': 'unknown'})
                          : {'icon': '❓', 'name': 'Unknown Category', 'type': 'unknown'};
                      _categoryCache[categoryId] = categoryData;
                    }

                    return {
                      ...tx,
                      'categoryIcon': categoryData['icon'] as String? ?? '❓',
                      'categoryName': categoryData['name'] as String? ?? 'Unknown Category',
                      'categoryType': categoryData['type'] as String? ?? 'unknown',
                    };
                  }),
                ),
                builder: (context, categorySnapshot) {
                  if (!categorySnapshot.hasData) {
                    return _buildLoadingSkeleton();
                  }

                  final allTransactionsWithCategories = categorySnapshot.data!;
                  final expenseTransactions = allTransactionsWithCategories.where((tx) => tx['categoryType'] == 'expense').toList();
                  final incomeTransactions = allTransactionsWithCategories.where((tx) => tx['categoryType'] == 'income').toList();

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
                      mainAxisSize: MainAxisSize.min, // Add this line
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
                      mainAxisSize: MainAxisSize.min, // Add this line
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
                      mainAxisSize: MainAxisSize.min, // Add this line
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
                      mainAxisSize: MainAxisSize.min, // Add this line
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
                return txDate.isAfter(startDate.subtract(Duration(seconds: 1))) && txDate.isBefore(endDate.add(Duration(seconds: 1)));
              }).toList();

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: Future.wait(
                  filteredTransactions.map((tx) async {
                    final categoryRef = tx['category'] as DocumentReference;
                    final categoryId = categoryRef.id;
                    Map<String, dynamic> categoryData = _categoryCache[categoryId] ?? {};

                    if (categoryData.isEmpty) {
                      final categorySnapshot = await categoryRef.get();
                      categoryData = categorySnapshot.exists
                          ? (categorySnapshot.data() as Map<String, dynamic>? ?? {'icon': '❓', 'name': 'Unknown Category', 'type': 'unknown'})
                          : {'icon': '❓', 'name': 'Unknown Category', 'type': 'unknown'};
                      _categoryCache[categoryId] = categoryData;
                    }

                    return {
                      ...tx,
                      'categoryIcon': categoryData['icon'] as String? ?? '❓',
                      'categoryName': categoryData['name'] as String? ?? 'Unknown Category',
                      'categoryType': categoryData['type'] as String? ?? 'unknown',
                    };
                  }),
                ),
                builder: (context, categorySnapshot) {
                  if (!categorySnapshot.hasData) {
                    return _buildLoadingSkeleton();
                  }

                  final allTransactionsWithCategories = categorySnapshot.data!;
                  final expenseTransactions = allTransactionsWithCategories.where((tx) => tx['categoryType'] == 'expense').toList();
                  final incomeTransactions = allTransactionsWithCategories.where((tx) => tx['categoryType'] == 'income').toList();

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
                              physics: const BouncingScrollPhysics(), // Add this line\
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
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialTipsScreen()));
      } else if (index == 2) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const GamificationPage()));
      } else if (index == 3) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
      }
    });
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx, String categoryIcon, String categoryName, String categoryType) {
    final txDate = tx['timestamp']?.toDate();
    return GestureDetector(
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
          subtitle: Text(txDate != null ? DateFormat('HH:mm').format(txDate) : 'N/A', style: TextStyle(color: Colors.white)),
          trailing: Text(
            'RM${(tx['amount'] as double).toStringAsFixed(1)}',
            style: TextStyle(fontSize: 16, color: categoryType == 'expense' ? Colors.red : Colors.green),
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