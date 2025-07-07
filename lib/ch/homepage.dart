import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For user authentication

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String currentPeriod = '23 Jun - 22 Jul';
  bool showExpenses = true;
  double availableScreenWidth = 0;
  int selectedIndex = 0;

  // Reference to Firestore and Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _updateCurrentPeriod();
  }

  void _updateCurrentPeriod() {
    final now = DateTime.now();
    currentPeriod = '${now.day} ${now.month} - ${now.day} ${now.month}';
  }

  @override
  Widget build(BuildContext context) {
    availableScreenWidth = MediaQuery.of(context).size.width - 50;

    // Get the current user's ID
    String? userId = _auth.currentUser?.uid;
    if (userId == null) {
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
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final transactions = snapshot.data!.docs.map((doc) {
          return {
            'id': doc.id,
            'type': doc['type'], // Directly use 'type' from Firestore
            'category': doc['category'],
            'amount': doc['amount'] as double,
            'timestamp': doc['timestamp'] as Timestamp,
          };
        }).toList();

        final double totalExpenses = transactions
            .where((tx) => tx['type'] == 'expense')
            .map((tx) => tx['amount'] as double)
            .reduce((a, b) => a + b)
            .abs();
        final double totalIncome = transactions
            .where((tx) => tx['type'] == 'income')
            .map((tx) => tx['amount'] as double)
            .reduce((a, b) => a + b);

        final filteredTransactions = transactions.where((tx) {
          if (showExpenses) return tx['type'] == 'expense';
          return tx['type'] == 'income';
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('Jun'),
            actions: [
              IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () {
                  setState(() {
                    _updateCurrentPeriod();
                  });
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentPeriod,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => showExpenses = true),
                        child: Card(
                          color: showExpenses ? Colors.blue[700] : Colors.grey[800],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.attach_money, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Expenses',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
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
                    SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => showExpenses = false),
                        child: Card(
                          color: !showExpenses ? Colors.green[700] : Colors.grey[800],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.monetization_on, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 5),
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
                SizedBox(height: 18),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredTransactions.length +
                        (filteredTransactions.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && filteredTransactions.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateTime.fromMillisecondsSinceEpoch(
                                filteredTransactions[0]['timestamp'].millisecondsSinceEpoch)
                                .toString()
                                .split(' ')[0],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      final i = index - (filteredTransactions.isNotEmpty ? 1 : 0);
                      if (i >= 0 && i < filteredTransactions.length) {
                        final tx = filteredTransactions[i];
                        if (index > 0 &&
                            i > 0 &&
                            DateTime.fromMillisecondsSinceEpoch(
                                tx['timestamp'].millisecondsSinceEpoch)
                                .toString()
                                .split(' ')[0] !=
                                DateTime.fromMillisecondsSinceEpoch(
                                    filteredTransactions[i - 1]['timestamp']
                                        .millisecondsSinceEpoch)
                                    .toString()
                                    .split(' ')[0]) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateTime.fromMillisecondsSinceEpoch(
                                    tx['timestamp'].millisecondsSinceEpoch)
                                    .toString()
                                    .split(' ')[0],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              _buildTransactionItem(tx),
                              SizedBox(height: 10),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildTransactionItem(tx),
                            SizedBox(height: 10),
                          ],
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: SizedBox(
            width: 180,
            height: 60,
            child: FloatingActionButton.extended(
              onPressed: () {
                // Add navigation or transaction addition logic here
              },
              backgroundColor: Colors.teal,
              icon: Icon(Icons.add, color: Colors.white, size: 24),
              label: Text('Add', style: TextStyle(color: Colors.white, fontSize: 16)),
              elevation: 4.0,
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: Container(
            height: 100,
            child: BottomNavigationBar(
              onTap: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              currentIndex: selectedIndex,
              items: [
                BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Details'),
                BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Trending'),
                BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Mine'),
              ],
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white,
              backgroundColor: Colors.grey[850],
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              iconSize: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    return Card(
      color: Colors.grey[800],
      child: ListTile(
        leading: Icon(
          Icons.fastfood,
          color: tx['type'] == 'expense' ? Colors.orange : Colors.green,
        ),
        title: Text(tx['category']),
        subtitle: Text(DateTime.fromMillisecondsSinceEpoch(
            tx['timestamp'].millisecondsSinceEpoch)
            .toString()
            .split(' ')[1]
            .substring(0, 5)), // Show only time (HH:MM)
        trailing: Text(
          'RM${tx['amount'].toStringAsFixed(1)}',
          style: TextStyle(
            color: tx['type'] == 'expense' ? Colors.red : Colors.green,
          ),
        ),
      ),
    );
  }
}