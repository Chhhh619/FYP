import 'package:flutter/material.dart';
import 'package:fyp/ch/subscription.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:fyp/wc/bill/bill_payment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/ch/goal.dart';
import 'package:fyp/wc/rewards_page.dart';
import 'package:fyp/wc/currencyconverter.dart';
import 'package:fyp/ch/budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'income.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double availableScreenWidth = 0;
  double availableScreenHeight = 0;
  int? totalDays;
  int? totalTransactions;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final createdAt = data['createdAt']?.toDate() ?? DateTime(2025, 7, 8);
        final transactionsCount = await _calculateTotalTransactions(userId);

        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'totalTransactions': transactionsCount},
        );

        setState(() {
          totalDays = DateTime.now().difference(createdAt).inDays;
          totalTransactions = transactionsCount;
        });
      } else {
        await _initializeUserData(userId);
      }
    }
  }

  Future<void> _initializeUserData(String userId) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'createdAt': Timestamp.fromDate(DateTime(2025, 7, 8)),
      'totalTransactions': 0, // Initial value, will be updated by function
      'lastUpdated': Timestamp.fromDate(now),
    }, SetOptions(merge: true));
    await _loadUserData();
  }

  Future<int> _calculateTotalTransactions(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    availableScreenWidth = MediaQuery.of(context).size.width;
    availableScreenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text('Mine', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: availableScreenWidth * 0.45,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(50, 50, 50, 1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total days',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        totalDays?.toString() ?? 'Loading...',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: availableScreenWidth * 0.45,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(50, 50, 50, 1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        totalTransactions?.toString() ?? 'Loading...',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              children: [
                _buildListTile(
                  leadingIcon: Icons.edit,
                  title: 'Edit my page',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    // Add navigation or action for Edit my page
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.account_balance,
                  title: 'Budget',
                  trailing: const Text(
                    'RM393/monthly',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BudgetPage(
                          selectedDate: DateTime.now(),
                          viewMode: 'month',
                        ),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.subscriptions,
                  title: 'Subscription and installment',
                  trailing: const Text(
                    '1 items',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SubscriptionPage(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.currency_exchange,
                  title: 'Currency Converter',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CurrencyConverterScreen(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.emoji_events,
                  title: 'Rewards',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RewardsPage(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.savings,
                  title: 'Savings Goals',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoalPage(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.currency_exchange,
                  title: 'Income Management',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IncomePage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: PersistentAddButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 3) {
            // Stay on SettingsPage
          } else {
            // Handle other tabs
          }
        },
      ),
    );
  }

  Widget _buildListTile({
    required IconData leadingIcon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(50, 50, 50, 1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListTile(
        leading: Icon(leadingIcon, color: Colors.white70),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
