import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:fyp/ch/record_transaction.dart';
import 'package:fyp/ch/settings.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  String currentPeriod = '';
  String displayText = DateFormat('MMM').format(DateTime.now());
  bool? showExpenses = null;
  double availableScreenWidth = 0;
  double availableScreenHeight = 0;
  int selectedIndex = 0; // Default to "Details" (HomePage)
  String viewMode = 'month';
  DateTime selectedDate = DateTime.now();
  String popupMode = 'month';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ScrollController _scrollController = ScrollController();
  bool _isScrollingDown = false;

  @override
  void initState() {
    super.initState();
    _updateCurrentPeriod();
    print('HomePage initialized, User ID: ${_auth.currentUser?.uid}'); // Debug
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true; // Preserve state across navigation

  void _scrollListener() {
    print(
      'Scroll position: ${_scrollController.position.pixels}, Direction: ${_scrollController.position.userScrollDirection}',
    );
    if (_scrollController.position.userScrollDirection ==
        ScrollDirection.reverse) {
      if (!_isScrollingDown) {
        print('Scrolling down detected');
        setState(() {
          _isScrollingDown = true;
        });
      }
    } else if (_scrollController.position.userScrollDirection ==
        ScrollDirection.forward) {
      if (_isScrollingDown) {
        print('Scrolling up detected');
        setState(() {
          _isScrollingDown = false;
        });
      }
    }
  }

  void _updateCurrentPeriod([DateTime? startDate]) {
    selectedDate = startDate ?? DateTime.now();
    final formatter = DateFormat('d MMM');
    if (viewMode == 'month') {
      displayText = DateFormat('MMM').format(selectedDate); // Show selected month
      final start = DateTime(selectedDate.year, selectedDate.month, 1); // Start of month
      final end = DateTime(selectedDate.year, selectedDate.month + 1, 0); // End of month
      currentPeriod = '${formatter.format(start)} - ${formatter.format(end)}';
    } else {
      // year mode
      displayText = selectedDate.year.toString(); // Show year
      final start = DateTime(selectedDate.year, 1, 1); // Start of year
      final end = DateTime(selectedDate.year, 12, 31); // End of year
      currentPeriod = '${formatter.format(start)} - ${formatter.format(end)}';
    }
    setState(() {}); // Update UI
  }

  void _showCustomDatePicker() {
    availableScreenWidth = MediaQuery.of(context).size.width;
    availableScreenHeight = MediaQuery.of(context).size.height;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 16.0), // Add some padding
              child: SizedBox(
                width: availableScreenWidth * 0.85, // 90% of screen width
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
                                  backgroundColor: popupMode == 'month'
                                      ? Colors.teal
                                      : Color.fromRGBO(33, 35, 34, 1),
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
                                  backgroundColor: popupMode == 'year'
                                      ? Colors.teal
                                      : Color.fromRGBO(33, 35, 34, 1),
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
                                final month = DateTime(
                                  selectedDate.year,
                                  index + 1,
                                );
                                return ElevatedButton(
                                  onPressed: () {
                                    _updateCurrentPeriod(
                                      DateTime(selectedDate.year, index + 1),
                                    );
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size(60, 60),
                                    backgroundColor:
                                    selectedDate.month == index + 1
                                        ? Colors.teal
                                        : Color.fromRGBO(33, 35, 34, 1),
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
                                    _updateCurrentPeriod(
                                      DateTime(year, selectedDate.month),
                                    );
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedDate.year == year
                                        ? Colors.teal
                                        : Color.fromRGBO(33, 35, 34, 1),
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
      _updateCurrentPeriod(selectedDate);
    });
  }

  void _setTransactionType(bool? type) {
    setState(() {
      showExpenses =
          type; // Directly set to null (all), true (expenses), or false (income)
    });
  }

  Future<void> _deleteTransaction(String transactionId) async {
    try {
      await _firestore.collection('transactions').doc(transactionId).delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete transaction: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    availableScreenWidth = MediaQuery.of(context).size.width - 50;

    String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in'); // Debug
      return Scaffold(
        body: Center(child: Text('Please log in to view transactions')),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('transactions')
          .where('userid', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingSkeleton(); // Show skeleton during initial load
        }

        if (snapshot.hasError) {
          print('StreamBuilder Error: ${snapshot.error}'); // Debug
          return Scaffold(
            body: Center(child: Text('Error loading data: ${snapshot.error}')),
          );
        }

        final transactions = snapshot.data!.docs
            .map((doc) {
          print('Document data: ${doc.data()}'); // Debug
          return {
            'id': doc.id,
            'category': doc['category'] as DocumentReference,
            'amount': (doc['amount'] is int)
                ? (doc['amount'] as int).toDouble()
                : (doc['amount'] as double?),
            'timestamp': doc['timestamp'] as Timestamp?,
          };
        })
            .whereType<Map<String, dynamic>>()
            .toList();

        final filteredTransactions = transactions.where((tx) {
          final txDate = tx['timestamp']?.toDate();
          if (txDate == null) return false;
          if (viewMode == 'month') {
            return txDate.year == selectedDate.year &&
                txDate.month == selectedDate.month;
          } else {
            return txDate.year == selectedDate.year;
          }
        }).toList();

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(
            filteredTransactions.map((tx) async {
              final categorySnapshot = await tx['category'].get();
              final categoryType =
                  categorySnapshot.get('type') as String? ?? 'unknown';
              return {...tx, 'categoryType': categoryType};
            }),
          ),
          builder: (context, categorySnapshot) {
            if (!categorySnapshot.hasData) {
              return _buildLoadingSkeleton(); // Show skeleton during data fetch
            }

            final displayedTransactions = categorySnapshot.data!.where((tx) {
              if (showExpenses == null) return true; // Show all by default
              if (showExpenses == true) return tx['categoryType'] == 'expense';
              if (showExpenses == false) return tx['categoryType'] == 'income';
              return true; // Fallback to all
            }).toList();

            // Calculate totals
            double totalExpenses = 0.0;
            double totalIncome = 0.0;
            for (var tx in displayedTransactions) {
              final amount = tx['amount'] as double? ?? 0.0;
              if (tx['categoryType'] == 'expense') {
                totalExpenses += amount.abs();
              } else if (tx['categoryType'] == 'income') {
                totalIncome += amount;
              }
            }

            // Show welcome message if no transactions
            if (filteredTransactions.isEmpty) {
              return Scaffold(
                backgroundColor: Color.fromRGBO(28, 28, 28, 0),
                appBar: AppBar(
                  backgroundColor: Color.fromRGBO(28, 28, 28, 0),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        currentPeriod,
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: Icon(Icons.calendar_today, color: Colors.white),
                      onPressed: _showCustomDatePicker,
                    ),
                    IconButton(
                      icon: Icon(
                        viewMode == 'month' ? Icons.view_agenda : Icons.view_week,
                        color: Colors.white,
                      ),
                      onPressed: _toggleViewMode,
                    ),
                  ],
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Welcome! No transactions yet.',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecordTransactionPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Add Your First Transaction'),
                      ),
                    ],
                  ),
                ),
                floatingActionButton: PersistentAddButton(),
                floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
                bottomNavigationBar: BottomNavBar(
                  currentIndex: selectedIndex,
                  onTap: (index) {
                    setState(() {
                      if (index == 0) {
                        // "Details" selected - reset to HomePage state (do nothing or reset if needed)
                        selectedIndex = 0;
                      } else if (index == 3) {
                        // "Mine" selected - navigate to SettingsPage
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingsPage()),
                        );
                      } else {
                        selectedIndex = index; // Update for other tabs
                      }
                    });
                  },
                ),
              );
            }

            return Scaffold(
              backgroundColor: Color.fromRGBO(28, 28, 28, 0),
              appBar: AppBar(
                backgroundColor: Color.fromRGBO(28, 28, 28, 0),
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      currentPeriod,
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: Icon(Icons.calendar_today, color: Colors.white),
                    onPressed: _showCustomDatePicker,
                  ),
                  IconButton(
                    icon: Icon(
                      viewMode == 'month' ? Icons.view_agenda : Icons.view_week,
                      color: Colors.white,
                    ),
                    onPressed: _toggleViewMode,
                  ),
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
                            onTap: () => _setTransactionType(
                              showExpenses == true ? null : true,
                            ),
                            child: Card(
                              color: showExpenses == true
                                  ? Colors.blue[700]
                                  : Color.fromRGBO(33, 35, 34, 1),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.attach_money,
                                          color: Colors.yellow,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Expenses',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'RM${totalExpenses.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _setTransactionType(
                              showExpenses == false ? null : false,
                            ),
                            child: Card(
                              color: showExpenses == false
                                  ? Colors.green[700]
                                  : Color.fromRGBO(33, 35, 34, 1),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.monetization_on,
                                          color: Colors.yellow,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Income',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'RM${totalIncome.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
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
                      child: Builder(
                        builder: (context) {
                          Map<DateTime, List<Map<String, dynamic>>>
                          groupedTransactions = {};
                          for (var tx in displayedTransactions) {
                            final txDate = tx['timestamp']!.toDate();
                            final groupKey = viewMode == 'month'
                                ? DateTime(
                              txDate.year,
                              txDate.month,
                              txDate.day,
                            )
                                : DateTime(txDate.year, txDate.month);
                            groupedTransactions
                                .putIfAbsent(groupKey, () => [])
                                .add(tx);
                          }
                          final sortedKeys = groupedTransactions.keys.toList()
                            ..sort((a, b) => b.compareTo(a));

                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: sortedKeys.length,
                            itemBuilder: (context, index) {
                              final groupDate = sortedKeys[index];
                              final groupTxs = groupedTransactions[groupDate]!;

                              double groupExpenses = 0.0;
                              double groupIncome = 0.0;

                              for (var tx in groupTxs) {
                                final amount = tx['amount'] as double? ?? 0.0;
                                if (tx['categoryType'] == 'expense') {
                                  groupExpenses += amount.abs();
                                } else if (tx['categoryType'] == 'income') {
                                  groupIncome += amount;
                                }
                              }

                              final groupLabel = DateFormat(
                                viewMode == 'month' ? 'd MMM EEE' : 'MMMM yyyy',
                              ).format(groupDate);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8.0,
                                      bottom: 4,
                                      right: 3,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          groupLabel,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'E RM${groupExpenses.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                color: Colors.red[100],
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'I RM${groupIncome.toStringAsFixed(1)}',
                                              style: TextStyle(
                                                color: Colors.green[200],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...groupTxs.map(
                                        (tx) => FutureBuilder<DocumentSnapshot>(
                                      future: tx['category'].get(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData)
                                          return SizedBox.shrink();
                                        final icon =
                                            snapshot.data!.get('icon') ?? 'ðŸ’°';
                                        final name =
                                            snapshot.data!.get('name') ??
                                                'Unknown';
                                        final type =
                                            snapshot.data!.get('type') ??
                                                'unknown';
                                        return Column(
                                          children: [
                                            _buildTransactionItem(
                                              tx,
                                              icon,
                                              name,
                                              type,
                                            ),
                                            SizedBox(height: 10),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: PersistentAddButton(),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              bottomNavigationBar: BottomNavBar(
                currentIndex: selectedIndex,
                onTap: (index) {
                  setState(() {
                    if (index == 0) {
                      // "Details" selected - reset to HomePage state (do nothing or reset if needed)
                      selectedIndex = 0;
                    } else if (index == 3) {
                      // "Mine" selected - navigate to SettingsPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsPage()),
                      );
                    } else {
                      selectedIndex = index; // Update for other tabs
                    }
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionItem(
      Map<String, dynamic> tx,
      String categoryIcon,
      String categoryName,
      String categoryType,
      ) {
    final txDate = tx['timestamp']?.toDate();
    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Color.fromRGBO(33, 35, 34, 1),
            title: Text(
              'Delete Transaction',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete this transaction?',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.teal)),
              ),
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
            style: TextStyle(color: Colors.white),
          ),
          trailing: Text(
            'RM${(tx['amount'] as double).toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 16,
              color: categoryType == 'expense' ? Colors.red : Colors.green,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 0),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(28, 28, 28, 0),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayText,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              currentPeriod,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.white),
            onPressed: null, // Disable during loading
          ),
          IconButton(
            icon: Icon(
              viewMode == 'month' ? Icons.view_agenda : Icons.view_week,
              color: Colors.white,
            ),
            onPressed: null, // Disable during loading
          ),
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
                          Container(
                            width: 60,
                            height: 20,
                            color: Colors.grey[700],
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 16,
                            color: Colors.grey[700],
                          ),
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
                          Container(
                            width: 60,
                            height: 20,
                            color: Colors.grey[700],
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 40,
                            height: 16,
                            color: Colors.grey[700],
                          ),
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
                itemCount: 5, // Placeholder for loading items
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 100,
                          height: 16,
                          color: Colors.grey[700],
                        ),
                        Container(
                          width: 80,
                          height: 16,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: PersistentAddButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            if (index == 0) {
              // "Details" selected - reset to HomePage state (do nothing or reset if needed)
              selectedIndex = 0;
            } else if (index == 3) {
              // "Mine" selected - navigate to SettingsPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            } else {
              selectedIndex = index; // Update for other tabs
            }
          });
        },
      ),
    );
  }
}