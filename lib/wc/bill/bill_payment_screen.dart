import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bill/bill.dart';
import '../bill/bill_form.dart';
import '../bill/bill_list_item.dart';
import '../bill/notification_service.dart';
import 'payment_history_screen.dart';
import 'package:fyp/bottom_nav_bar.dart';

class BillPaymentScreen extends StatefulWidget {
  final String userId;
  BillPaymentScreen({required this.userId});

  @override
  _BillPaymentScreenState createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  int selectedIndex = 0;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (selectedIndex == 0) {
        NotificationService.checkBillReminders(context, []); // Initial check with empty list
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Bill Payment & Reminders',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          if (selectedIndex == 0) // Show category filter only on Details tab
            DropdownButton<String>(
              value: _selectedCategory,
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              underline: Container(
                height: 1,
                color: Colors.grey[400],
              ),
              items: ['All', 'Utilities', 'Rent', 'Credit Card', 'Subscription', 'Other']
                  .map((category) => DropdownMenuItem(
                value: category,
                child: Text(category),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
                if (selectedIndex == 0) {
                  NotificationService.checkBillReminders(context, []); // Recheck on category change
                }
              },
            ),
          if (selectedIndex == 0) // Show history icon only on Details tab
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/payment_history', arguments: widget.userId);
              },
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          // Details Tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('bills')
                .where('isPaid', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.grey[700]));
              var bills = snapshot.data!.docs.map((doc) => Bill.fromJson(doc.data() as Map<String, dynamic>)).toList();
              if (_selectedCategory != 'All') {
                bills = bills.where((bill) => bill.category == _selectedCategory).toList();
              }
              // Remove NotificationService.checkBillReminders here
              return bills.isEmpty
                  ? Center(
                child: Text(
                  'No unpaid bills.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: bills.length,
                itemBuilder: (context, index) => BillListItem(bill: bills[index], userId: widget.userId),
              );
            },
          ),
          // Trending Tab (Placeholder)
          Center(
            child: Text(
              'Trending',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          // Insights Tab (Placeholder)
          Center(
            child: Text(
              'Insights',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          // Mine Tab (Placeholder)
          Center(
            child: Text(
              'Mine',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 100,
        child: BottomNavBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
            switch (index) {
              case 0:
                Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                break;
              case 1:
                Navigator.pushNamed(context, '/financial_tips');
                break;
              case 2:
                Navigator.pushNamed(context, '/gamification');
                break;
              case 3:
                Navigator.pushNamed(context, '/settings');
                break;
            }
          },
        ),
      ),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton(
        backgroundColor: Colors.grey[700],
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.grey[900],
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16.0),
              child: BillForm(userId: widget.userId),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null, // Hide FAB on other tabs
    );
  }
}