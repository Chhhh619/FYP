import 'package:flutter/material.dart';
import 'package:fyp/ch/subscription.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/persistent_add_button.dart';
import 'package:fyp/wc/bill/bill_payment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/rewards_page.dart';
import 'package:fyp/wc/currencyconverter.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total days',
                  style: TextStyle(color: Colors.white70),
                ),
                const Text(
                  '950 days',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Total',
                  style: TextStyle(color: Colors.white70),
                ),
                const Text(
                  '2,848 times',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white70),
                  title: const Text('Edit my page', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    // Add navigation or action for Edit my page
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.white70),
                  title: const Text('Asset', style: TextStyle(color: Colors.white)),
                  trailing: const Text('0 Assets', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    // Add navigation or action for Asset
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance, color: Colors.white70),
                  title: const Text('Budget', style: TextStyle(color: Colors.white)),
                  trailing: const Text('RM339/monthly', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    // Add navigation or action for Budget
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.subscriptions, color: Colors.white70),
                  title: const Text('Subscriptions', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SubscriptionPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt, color: Colors.white70),
                  title: const Text('Bills', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    if (userId != null) {
                      Navigator.pushNamed(context, '/bill', arguments: userId);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.currency_exchange, color: Colors.white70), // Icon for currency
                  title: const Text('Currency Converter', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white70),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CurrencyConverterScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.emoji_events, color: Colors.white70),
                  title: const Text('Rewards', style: TextStyle(color: Colors.white)),
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
          ),
        ],
      ),
      floatingActionButton: PersistentAddButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavBar(
        currentIndex: 3, // Set to "Mine" tab (index 3) as default
        onTap: (index) {
          if (index == 0) {
            // Navigate to HomePage
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          } else if (index == 3) {
            // Stay on SettingsPage (do nothing or reset if needed)
          } else {
            // Handle other tabs (e.g., navigate to other pages if implemented)
          }
        },
      ),
    );
  }
}