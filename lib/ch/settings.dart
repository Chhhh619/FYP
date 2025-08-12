import 'package:flutter/material.dart';
import 'package:fyp/ch/profile.dart';
import 'package:fyp/ch/subscription.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:fyp/wc/bill/bill_payment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/ch/goal.dart';
import 'package:fyp/wc/financial_plan.dart';
import 'package:fyp/wc/point_shop_page.dart';
import 'package:fyp/wc/rewards_page.dart';
import 'package:fyp/wc/currencyconverter.dart';
import 'package:fyp/ch/budget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/wc/trending.dart';
import 'package:intl/intl.dart';
import 'package:fyp/wc/financial_tips.dart';
import 'package:fyp/wc/gamification_page.dart';
import 'package:fyp/wc/adminpage.dart'; // Add this import for AdminPage
import 'card_list.dart';
import 'export_page.dart';
import 'income.dart';
import 'billing_start_date_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ScrollController _scrollController = ScrollController();
  double availableScreenWidth = 0;
  double availableScreenHeight = 0;
  int? totalDays;
  int? totalTransactions;
  int? totalSubscriptions;
  double? monthlyBudget;
  int? billStartDate;
  int selectedIndex = 3;
  bool? _isAdmin; // Add admin status tracking

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
        final createdAt = data['created_at']?.toDate() ??
            data['createdAt']?.toDate() ??
            DateTime(2025, 7, 8);
        final transactionsCount = await _calculateTotalTransactions(userId);
        final subscriptionsCount = await _calculateTotalSubscriptions(userId);
        final budget = await _fetchMonthlyBudget(userId);
        final startDate = data['billStartDate'] ?? 23;

        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'totalTransactions': transactionsCount},
        );

        setState(() {
          totalDays = DateTime.now().difference(createdAt).inDays;
          totalTransactions = transactionsCount;
          totalSubscriptions = subscriptionsCount;
          monthlyBudget = budget;
          billStartDate = startDate;
          _isAdmin = data['isAdmin'] == true; // Set admin status
        });
      } else {
        await _initializeUserData(userId);
      }
    }
  }

  Future<void> _initializeUserData(String userId) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'created_at': Timestamp.fromDate(DateTime(2025, 7, 8)),
      'totalTransactions': 0,
      'lastUpdated': Timestamp.fromDate(now),
      'billStartDate': 23,
      'isAdmin': false, // Initialize as non-admin
    }, SetOptions(merge: true));
    await _loadUserData();
  }

  Future<int> _calculateTotalTransactions(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<int> _calculateTotalSubscriptions(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.size;
  }

  Future<double?> _fetchMonthlyBudget(String userId) async {
    try {
      final now = DateTime.now();
      final docId = DateFormat('yyyy-MM').format(now);

      print('Fetching budget for docId: $docId');
      print('UserId: $userId');

      final budgetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('budgets')
          .doc(docId)
          .get();

      print('Budget document exists: ${budgetDoc.exists}');

      if (budgetDoc.exists) {
        final data = budgetDoc.data()!;
        print('Budget data: $data');

        double? amount;
        if (data.containsKey('amount')) {
          amount = data['amount']?.toDouble();
        } else if (data.containsKey('budget')) {
          amount = data['budget']?.toDouble();
        } else if (data.containsKey('budgetAmount')) {
          amount = data['budgetAmount']?.toDouble();
        } else if (data.containsKey('totalBudget')) {
          amount = data['totalBudget']?.toDouble();
        }

        print('Extracted amount: $amount');
        return amount;
      } else {
        print('Current month budget not found, searching for latest budget...');

        final budgetsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('budgets')
            .orderBy(FieldPath.documentId, descending: true)
            .limit(1)
            .get();

        if (budgetsSnapshot.docs.isNotEmpty) {
          final latestBudget = budgetsSnapshot.docs.first;
          final data = latestBudget.data();
          print('Latest budget data: $data');
          print('Latest budget docId: ${latestBudget.id}');

          double? amount;
          if (data.containsKey('amount')) {
            amount = data['amount']?.toDouble();
          } else if (data.containsKey('budget')) {
            amount = data['budget']?.toDouble();
          } else if (data.containsKey('budgetAmount')) {
            amount = data['budgetAmount']?.toDouble();
          } else if (data.containsKey('totalBudget')) {
            amount = data['totalBudget']?.toDouble();
          }

          return amount;
        }
      }

      return null;
    } catch (e) {
      print('Error fetching budget: $e');
      return null;
    }
  }

  String _formatSubscriptionText() {
    if (totalSubscriptions == null) {
      return 'Loading...';
    } else if (totalSubscriptions == 0) {
      return 'No subscriptions';
    } else if (totalSubscriptions == 1) {
      return '1 item';
    } else {
      return '$totalSubscriptions items';
    }
  }

  String _formatBudgetText() {
    if (monthlyBudget == null) {
      return 'No budget set';
    } else {
      return 'RM${monthlyBudget!.toStringAsFixed(0)}/monthly';
    }
  }

  String _formatBillStartDateText() {
    if (billStartDate == null) {
      return 'Loading...';
    } else {
      return 'Monthly ${_getOrdinalNumber(billStartDate!)}';
    }
  }

  String _getOrdinalNumber(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  void _handleNavBarTap(int index) {
    print('BottomNavBar tapped: index = $index'); // Debug print
    setState(() {
      selectedIndex = index;
      if (index == 0) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const HomePage()));
      } else if (index == 1) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TrendingPage()));
      } else if (index == 2) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialPlanPage()));
      } else if (index == 3) {
        // Stay on SettingsPage
      }
    });
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
        surfaceTintColor: const Color.fromRGBO(28, 28, 28, 1),
        elevation: 0,
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
                    color: const Color.fromRGBO(33, 35, 34, 1),
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
                    color: const Color.fromRGBO(33, 35, 34, 1),
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
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              children: [
                // Add Admin Dashboard section if user is admin
                if (_isAdmin == true) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 8.0, left: 4.0),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildListTile(
                    leadingIcon: Icons.admin_panel_settings,
                    title: 'Admin Dashboard',
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminPage(),
                        ),
                      );
                    },
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 8.0, left: 4.0),
                  child: Text(
                    'App Features',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildListTile(
                  leadingIcon: Icons.account_balance,
                  title: 'Budget',
                  trailing: Text(
                    _formatBudgetText(),
                    style: const TextStyle(color: Colors.white70),
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
                  title: 'Subscription',
                  trailing: Text(
                    _formatSubscriptionText(),
                    style: const TextStyle(color: Colors.white70),
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
                  leadingIcon: Icons.receipt,
                  title: 'Bills',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    if (userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BillPaymentScreen(userId: userId),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User not logged in'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
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
                      MaterialPageRoute(builder: (context) => GoalPage()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.book,
                  title: 'Financial Tips',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FinancialTipsScreen(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.gamepad,
                  title: 'Challenges',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GamificationPage(),
                      ),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.shopping_cart,
                  title: 'Point Shop',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PointShopPage(),
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
                _buildListTile(
                  leadingIcon: Icons.currency_exchange,
                  title: 'Export Report',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExportReportPage(),
                      ),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 24.0, bottom: 8.0, left: 4.0),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildListTile(
                  leadingIcon: Icons.edit,
                  title: 'Edit profile',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.calendar_today,
                  title: 'Billing start date',
                  trailing: Text(
                    _formatBillStartDateText(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BillingStartDatePage(),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        billStartDate = result;
                      });
                    }
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.account_balance,
                  title: 'Card details',
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Colors.white70,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CardListPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: PersistentAddButton(
        scrollController: _scrollController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: selectedIndex,
        onTap: _handleNavBarTap,
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
        color: const Color.fromRGBO(33, 35, 34, 1),
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