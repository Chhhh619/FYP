import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp/ch/subscription.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:fyp/wc/bill/bill_payment_screen.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/rewards_page.dart';
import 'package:fyp/wc/currencyconverter.dart';
import 'package:fyp/ch/budget.dart';
import 'package:intl/intl.dart';
import 'package:fyp/wc/financial_plan.dart';

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
  String? _selectedCurrency = 'MYR';
  bool _isLoading = false;

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
          _selectedCurrency = data['currency'] ?? 'MYR';
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
      'lastUpdated': Timestamp.now(),
      'currency': 'MYR',
      'points': 0,
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
        SnackBar(content: Text('Display name updated successfully')),
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
        backgroundColor: Color.fromRGBO(50, 50, 50, 1),
        title: Text(
          'Edit Display Name',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Display Name',
            labelStyle: TextStyle(color: Colors.grey[400]),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _updateDisplayName(nameController.text.trim());
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid name')),
                );
              }
            },
            child: Text(
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
      return Center(
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
          return Center(child: CircularProgressIndicator());
        }
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final displayName = userData['displayName'] ?? user.email?.split('@')[0] ?? 'User';
        final points = userData['points']?.toString() ?? '0';
        final equippedBadge = userData['equippedBadge'] ?? 'None';

        return Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Color.fromRGBO(50, 50, 50, 1),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildListTile(
                leadingIcon: Icons.person,
                title: 'Display Name: $displayName',
                trailing: Icon(Icons.edit, color: Colors.white70),
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
                trailing: Icon(Icons.chevron_right, color: Colors.white70),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RewardsPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    availableScreenWidth = MediaQuery.of(context).size.width;
    availableScreenHeight = MediaQuery.of(context).size.height;

    if (userId == null) {
      return Scaffold(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        body: Center(
          child: Text(
            'Please log in to view settings',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        title: Text(
          'Mine',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
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
                    color: Color.fromRGBO(50, 50, 50, 1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total days',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        totalDays?.toString() ?? 'Loading...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: availableScreenWidth * 0.45,
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(50, 50, 50, 1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Transactions',
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        totalTransactions?.toString() ?? 'Loading...',
                        style: TextStyle(color: Colors.white),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              children: [
                _buildListTile(
                  leadingIcon: Icons.account_balance,
                  title: 'Budget',
                  trailing: Text('RM393/monthly', style: TextStyle(color: Colors.white70)),
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
                  trailing: Text('1 items', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.receipt,
                  title: 'Bills',
                  trailing: Icon(Icons.chevron_right, color: Colors.white70),
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
                        SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.currency_exchange,
                  title: 'Currency Converter',
                  trailing: Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CurrencyConverterScreen()),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.attach_money,
                  title: 'Multi-currency',
                  trailing: Text('1 currencies', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    // Add navigation or action for Multi-currency
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Multi-currency feature coming soon!')),
                    );
                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.savings,
                  title: 'Savings Plan',
                  trailing: Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.pushNamed(context, '/financial_plan');

                  },
                ),
                _buildListTile(
                  leadingIcon: Icons.logout,
                  title: 'Logout',
                  trailing: Icon(Icons.chevron_right, color: Colors.redAccent),
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
            // Handle other tabs (e.g., FinancialTipsScreen, GamificationPage)
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