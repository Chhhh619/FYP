import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/ch/subscription.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:fyp/wc/bill/bill_payment_screen.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/ch/goal.dart';
import 'package:fyp/wc/rewards_page.dart';
import 'package:fyp/wc/currencyconverter.dart';
import 'package:fyp/ch/budget.dart';
import 'package:intl/intl.dart';
import 'package:fyp/wc/financial_tips.dart';
import 'package:fyp/wc/gamification_page.dart';
import 'card_list.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  String? _selectedCurrency = 'MYR';
  bool _isLoading = false;
  bool? _isAdmin;
  int _selectedIndex = 3; // Set to 3 for SettingsPage

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final createdAt = data['createdAt']?.toDate() ?? DateTime(2025, 7, 8);
        final transactionsCount = await _calculateTotalTransactions(userId);
        final subscriptionsCount = await _calculateTotalSubscriptions(userId);
        final budget = await _fetchMonthlyBudget(userId);
        final startDate = data['billStartDate'] ?? 23;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'totalTransactions': transactionsCount,
          'currency': data['currency'] ?? 'MYR',
        });

        setState(() {
          totalDays = DateTime.now().difference(createdAt).inDays;
          totalTransactions = transactionsCount;
          totalSubscriptions = subscriptionsCount;
          monthlyBudget = budget;
          billStartDate = startDate;
          _selectedCurrency = data['currency'] ?? 'MYR';
          _isAdmin = data['isAdmin'] == true;
        });
      } else {
        await _initializeUserData(userId);
      }
    } catch (e) {
      print('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user data: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _initializeUserData(String userId) async {
    final now = DateTime.now();
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'createdAt': Timestamp.fromDate(DateTime(2025, 7, 8)),
      'totalTransactions': 0,
      'lastUpdated': Timestamp.fromDate(),
      'billStartDate': 23,'
      'currency': 'MYR',
      'points': 0,
      'equippedBadge': null,
      'isAdmin': false,
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

  Future<void> _updateDisplayName(String newName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(newName);
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'displayName': newName,
      }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating display name: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showEditNameDialog() {
    final TextEditingController nameController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(50, 50, 50, 1),
        title: const Text(
          'Edit Display Name',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Display Name',
            labelStyle: TextStyle(color: Colors.grey[400]),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _updateDisplayName(nameController.text.trim());
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid name')),
                );
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view settings',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final userId = user.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final displayName = userData['displayName'] ?? user.email?.split('@')[0] ?? 'User';
        final points = userData['points']?.toString() ?? '0';
        final equippedBadge = userData['equippedBadge'] ?? 'None';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(50, 50, 50, 1),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildListTile(
                leadingIcon: Icons.person,
                title: 'Display Name: $displayName',
                trailing: const Icon(Icons.edit, color: Colors.white70),
                onTap: _showEditNameDialog,
              ),
              _buildListTile(
                leadingIcon: Icons.email,
                title: 'Email: ${user.email ?? 'N/A'}',
                onTap: () {},
              ),
              _buildListTile(
                leadingIcon: Icons.star,
                title: 'Points: $points',
                onTap: () {},
              ),
              _buildListTile(
                leadingIcon: Icons.badge,
                title: 'Equipped Badge: $equippedBadge',
                trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RewardsPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleNavigation(int index) {
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/trending');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/financial_plan');
    } else if (index == 3) {
      // Stay on SettingsPage
    }
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
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialTipsScreen()));
      } else if (index == 2) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const GamificationPage()));
      } else if (index == 3) {
        // Stay on SettingsPage
      }
    });
  }

  Future<void> addFromCardIdToAllTransactions(String fromCardIdValue) async {
    const int batchSize = 500;
    QueryDocumentSnapshot? lastDoc;
    bool more = true;
    int totalUpdated = 0;

    while (more) {
      Query query = FirebaseFirestore.instance
          .collection('transactions')
          .orderBy(FieldPath.documentId)
          .limit(batchSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        more = false;
        break;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'fromCardId': fromCardIdValue, // 🔁 You can change logic here
        });
      }

      await batch.commit();
      lastDoc = snapshot.docs.last;
      totalUpdated += snapshot.docs.length;
      print("✅ Updated ${snapshot.docs.length} docs...");
    }

    print("🎉 All done. Total updated: $totalUpdated");
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    availableScreenWidth = MediaQuery.of(context).size.width;
    availableScreenHeight = MediaQuery.of(context).size.height;

    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
          title: const Text(
            'Mine',
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Please log in to view settings',
            style: TextStyle(color: Colors.white),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _handleNavigation,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        surfaceTintColor: const Color.fromRGBO(28, 28, 28, 1),
        elevation: 0,
        title: const Text('Mine', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                        'Total Transactions',
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
          _buildProfileSection(),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              children: [
                if (_isAdmin == true)
                  _buildListTile(
                    leadingIcon: Icons.admin_panel_settings,
                    title: 'Admin Dashboard',
                    trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminPage()),
                      );
                    },
                  ),
                _buildListTile(
                  leadingIcon: Icons.edit,
                  title: 'Edit my page',
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    // Add navigation or action for Edit my page
                  },
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

                ),
                _buildListTile(
                  leadingIcon: Icons.receipt,
                  title: 'Bills',
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
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
                        const SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.currency_exchange,
                  title: 'Currency Converter',
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CurrencyConverterScreen()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.savings,
                  title: 'Savings Goals',
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => GoalPage()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.book, // Changed from Icons.savings to Icons.book
                  title: 'Financial Tips',
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FinancialTipsScreen()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.currency_exchange,
                  title: 'Income Management',
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const IncomePage()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.gamepad,
                  title: 'Challenges',
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GamificationPage()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.logout,
                  title: 'Logout',
                  trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                  onTap: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/login');
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error logging out: $e'), backgroundColor: Colors.red),
                      );
                    }
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
                        builder: (context) => CardListPage(
                        ),
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
      floatingActionButton: const PersistentAddButton(),
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
