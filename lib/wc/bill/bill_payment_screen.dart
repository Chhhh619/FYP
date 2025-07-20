import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bill/bill.dart';
import 'payment_history_screen.dart';
import 'bill_form.dart';

class BillPaymentScreen extends StatefulWidget {
  final String userId;
  BillPaymentScreen({required this.userId});

  @override
  _BillPaymentScreenState createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  int selectedIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _markAsPaid(Bill bill) async {
    try {
      await _firestore.collection('users').doc(widget.userId).collection('bills').doc(bill.id).update({
        'isPaid': true,
        'paymentHistory': FieldValue.arrayUnion([{
          'amount': bill.amount,
          'paymentDate': FieldValue.serverTimestamp(),
        }]),
      });
      // Sync with transactions
      await _firestore.collection('transactions').add({
        'userid': widget.userId,
        'amount': bill.amount,
        'timestamp': FieldValue.serverTimestamp(),
        'category': _firestore.collection('categories').doc('bill_category_id'), // Define a bill category
        'categoryType': 'expense',
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking bill as paid: $e')),
      );
    }
  }

  void _showBillForm({Bill? bill}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillForm(userId: widget.userId, bill: bill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Bill Payment & Reminders',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          SizedBox(
            width: 150,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search bills...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          DropdownButton<String>(
            value: _selectedCategory,
            dropdownColor: Colors.grey[900],
            style: TextStyle(color: Colors.white),
            underline: Container(height: 1, color: Colors.grey[400]),
            items: ['All', 'Utilities', 'Rent', 'Credit Card', 'Subscription', 'Other']
                .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                .toList(),
            onChanged: (value) => setState(() => _selectedCategory = value!),
          ),
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PaymentHistoryScreen(userId: widget.userId),
              ),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(widget.userId)
                .collection('bills')
                .where('isPaid', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.grey[700]));
              var bills = snapshot.data!.docs
                  .map((doc) => Bill.fromJson(doc.data() as Map<String, dynamic>))
                  .where((bill) {
                final matchesSearch = _searchQuery.isEmpty || bill.title.toLowerCase().contains(_searchQuery);
                final matchesCategory = _selectedCategory == 'All' || bill.category == _selectedCategory;
                return matchesSearch && matchesCategory;
              })
                  .toList();
              if (bills.isEmpty) {
                return Center(
                  child: Text(
                    'No unpaid bills available.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.0),
                itemCount: bills.length,
                itemBuilder: (context, index) {
                  final bill = bills[index];
                  return Card(
                    color: Colors.grey[900],
                    margin: EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16.0),
                      title: Text(
                        bill.title,
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Due: \$${bill.amount.toStringAsFixed(2)} by ${bill.dueDate.toString().substring(0, 10)}',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.grey[900],
                              title: Text('Confirm', style: TextStyle(color: Colors.white)),
                              content: Text('Mark ${bill.title} as paid?', style: TextStyle(color: Colors.white)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _markAsPaid(bill);
                                    Navigator.pop(context);
                                  },
                                  child: Text('Yes', style: TextStyle(color: Colors.teal)),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        child: Text('Paid'),
                      ),
                      onTap: () => _showBillForm(bill: bill),
                    ),
                  );
                },
              );
            },
          ),
          // Placeholder for other tabs (e.g., summary, insights)
          Center(child: Text('Tab 1 Placeholder', style: TextStyle(color: Colors.white, fontSize: 20))),
          Center(child: Text('Tab 2 Placeholder', style: TextStyle(color: Colors.white, fontSize: 20))),
          Center(child: Text('Tab 3 Placeholder', style: TextStyle(color: Colors.white, fontSize: 20))),
        ],
      ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBillForm(),
        backgroundColor: Colors.teal,
        child: Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}