import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'record_bill.dart';
import 'payment_history_screen.dart';
import 'bill_details_screen.dart';

class BillPaymentScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onRefresh;

  const BillPaymentScreen({Key? key, required this.userId, this.onRefresh}) : super(key: key);

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Key _streamKey = UniqueKey();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _checkDueBills();
  }

  Future<void> _checkDueBills() async {
    final now = DateTime.now();
    final oneDayFromNow = now.add(const Duration(days: 1));
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('bills')
          .where('status', isEqualTo: 'pending')
          .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(oneDayFromNow))
          .get();
      print('Due bills check: Found ${snapshot.docs.length} bills: ${snapshot.docs.map((doc) => doc.data()).toList()}');
      if (snapshot.docs.isNotEmpty && mounted) {
        final bill = snapshot.docs.first.data();
        final billerName = bill['billerName'] as String? ?? 'Unknown Biller';
        final amount = bill['amount'] as double? ?? 0.0;
        final dueDate = (bill['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
        final categoryName = bill['categoryName'] as String? ?? 'Uncategorized';
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color.fromRGBO(50, 50, 50, 1),
            title: const Text('Bill Due Soon', style: TextStyle(color: Colors.white)),
            content: Text(
              '$billerName ($categoryName) bill of RM${amount.toStringAsFixed(2)} is due on ${DateFormat('MMM dd, yyyy').format(dueDate)}.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.teal)),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error checking due bills: $e\nStackTrace: $stackTrace');
    }
  }

  Future<void> _markBillAsPaid(String billId, Map<String, dynamic> billData) async {
    final userId = widget.userId;
    final amount = billData['amount'] as double? ?? 0.0;
    final billerName = billData['billerName'] as String? ?? 'Unknown Biller';
    final description = billData['description'] as String? ?? 'No description';
    final categoryName = billData['categoryName'] as String? ?? 'Uncategorized';

    setState(() {
      _isUpdating = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(
        _firestore.collection('users').doc(userId).collection('bills').doc(billId),
        {
          'status': 'paid',
          'paidAt': Timestamp.now(),
        },
      );
      batch.set(
        _firestore.collection('users').doc(userId).collection('payments').doc(),
        {
          'userId': userId,
          'billId': billId,
          'billerName': billerName,
          'description': description,
          'amount': amount,
          'categoryName': categoryName,
          'timestamp': Timestamp.now(),
        },
      );

      await batch.commit().then((_) {
        print('Batch commit successful for markBillAsPaid: billId=$billId');
      }).catchError((e, stackTrace) {
        print('Batch commit failed for markBillAsPaid: $e\nStackTrace: $stackTrace');
        throw e;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill marked as paid')),
      );
    } catch (e, stackTrace) {
      print('Error marking bill as paid: $e\nStackTrace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking bill as paid: $e')),
      );
    } finally {
      setState(() {
        _isUpdating = false;
        _streamKey = UniqueKey();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('bill_payment_scaffold'),
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text('Bills', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentHistoryScreen(
                    userId: widget.userId,
                    onRefresh: () {
                      setState(() {
                        _streamKey = UniqueKey();
                      });
                    },
                  ),
                  settings: RouteSettings(arguments: widget.userId),
                ),
              );
            },
          ),
        ],
        elevation: 0,
      ),
      body: _isUpdating
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : StreamBuilder<QuerySnapshot>(
        key: _streamKey,
        stream: _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('bills')
            .where('status', isEqualTo: 'pending')
            .orderBy('dueDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          print('StreamBuilder snapshot: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, docs: ${snapshot.data?.docs.length ?? 0}, error: ${snapshot.error}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Error loading bills. Please check Firestore indexes.',
                    style: TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _streamKey = UniqueKey();
                      });
                    },
                    child: const Text('Retry', style: TextStyle(color: Colors.teal)),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No pending bills found', style: TextStyle(color: Colors.white70)),
            );
          }

          final bills = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index].data() as Map<String, dynamic>;
              final billId = bills[index].id;
              final billerName = bill['billerName'] as String? ?? 'Unknown Biller';
              final amount = bill['amount'] as double? ?? 0.0;
              final dueDate = (bill['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
              final categoryName = bill['categoryName'] as String? ?? 'Uncategorized';

              print('Navigating to BillDetailsScreen with billId: $billId, billData: $bill');

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BillDetailsScreen(
                        userId: widget.userId,
                        billId: billId,
                        billData: bill,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(50, 50, 50, 1),
                    borderRadius: BorderRadius.circular(8),
                    border: dueDate.isBefore(DateTime.now())
                        ? Border.all(color: Colors.redAccent, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            billerName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Category: $categoryName',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            'Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            'RM${amount.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _isUpdating ? null : () => _markBillAsPaid(billId, bill),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Pay'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordBillPage(
                userId: widget.userId,
                onBillAdded: () {
                  setState(() {
                    _streamKey = UniqueKey();
                  });
                },
              ),
            ),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}