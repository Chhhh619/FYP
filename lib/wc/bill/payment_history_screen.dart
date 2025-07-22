import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bill/bill.dart';
import 'bill_payment_screen.dart'; // For navigation back reference

class PaymentHistoryScreen extends StatefulWidget {
  final String userId;
  PaymentHistoryScreen({required this.userId});

  @override
  _PaymentHistoryScreenState createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  int selectedIndex = 0; // Default to Payment History tab

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Payment History',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/bill', arguments: widget.userId);
          },
        ),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: [
          // Payment History Tab
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .collection('bills')
                .where('isPaid', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.grey[700]));
              var paidBills = snapshot.data!.docs.map((doc) => Bill.fromJson(doc.data() as Map<String, dynamic>)).toList();
              if (paidBills.isEmpty) {
                return Center(
                  child: Text(
                    'No payment history available.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: paidBills.length,
                itemBuilder: (context, index) {
                  final bill = paidBills[index];
                  return Card(
                    color: Colors.grey[900],
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16.0),
                      title: Text(
                        bill.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Paid: \$${bill.amount.toStringAsFixed(2)} on ${bill.paymentHistory.isNotEmpty ? bill.paymentHistory.last.paymentDate.toString().substring(0, 10) : 'N/A'}',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.grey[900],
                            title: Text(
                              bill.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Amount: \$${bill.amount.toStringAsFixed(2)}', style: TextStyle(color: Colors.white)),
                                const SizedBox(height: 10),
                                Text('Category: ${bill.category}', style: TextStyle(color: Colors.white)),
                                const SizedBox(height: 10),
                                Text('Due Date: ${bill.dueDate.toString().substring(0, 10)}', style: TextStyle(color: Colors.white)),
                                const SizedBox(height: 10),
                                Text('Status: Paid', style: TextStyle(color: Colors.white)),
                                const SizedBox(height: 10),
                                if (bill.paymentHistory.isNotEmpty)
                                  Text(
                                    'Payment History:',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ...bill.paymentHistory.map((record) => Padding(
                                  padding: const EdgeInsets.only(left: 10, top: 5),
                                  child: Text(
                                    'Paid: \$${record.amount.toStringAsFixed(2)} on ${record.paymentDate.toString().substring(0, 10)}',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                )),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Close', style: TextStyle(color: Colors.grey[400])),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          // Placeholder for other tabs (e.g., summary or details)
          Center(
            child: Text(
              'Tab 1 Placeholder',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          // Placeholder for another tab
          Center(
            child: Text(
              'Tab 2 Placeholder',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          // Placeholder for another tab
          Center(
            child: Text(
              'Tab 3 Placeholder',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Payment History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up),
              label: 'Trending',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Mine',
            ),
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
  }
}