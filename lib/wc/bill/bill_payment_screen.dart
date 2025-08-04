import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'record_bill.dart';
import 'payment_history_screen.dart';
import 'bill_details_screen.dart';
import 'notification_service.dart';

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
    // Initialize notifications
    NotificationService().init();
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
          if (billData['billImageUrl'] != null)
            'billImageUrl': billData['billImageUrl'],
        },
      );

      await batch.commit().then((_) {
        print('Batch commit successful for markBillAsPaid: billId=$billId');
      }).catchError((e, stackTrace) {
        print('Batch commit failed for markBillAsPaid: $e\nStackTrace: $stackTrace');
        throw e;
      });

      // Show notification for bill paid
      await NotificationService().showBillPaidNotification(
        billerName: billerName,
        amount: amount,
        categoryName: categoryName,
      );

      // Cancel scheduled notification for this bill
      await NotificationService().cancelNotification(billId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill marked as paid'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error marking bill as paid: $e\nStackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking bill as paid: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _streamKey = UniqueKey(); // Refresh stream to reflect changes
        });
      }
    }
  }

  Widget _buildBillCard(Map<String, dynamic> bill, String billId, int index, int totalBills) {
    final billerName = bill['billerName'] as String? ?? 'Unknown Biller';
    final amount = bill['amount'] as double? ?? 0.0;
    final dueDate = (bill['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final categoryName = bill['categoryName'] as String? ?? 'Uncategorized';
    final description = bill['description'] as String? ?? '';

    final isOverdue = dueDate.isBefore(DateTime.now());
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;

    return Container(
      margin: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: index == totalBills - 1 ? 100 : 16, // Extra bottom margin for last item
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOverdue
              ? [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)]
              : [Colors.teal.withOpacity(0.1), Colors.teal.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? Colors.red.withOpacity(0.3)
              : Colors.teal.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? Colors.red.withOpacity(0.1)
                            : Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOverdue
                            ? Icons.warning_rounded
                            : Icons.receipt_rounded,
                        color: isOverdue ? Colors.red : Colors.teal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            billerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500, // Corrected from Weight.w500
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'RM${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? Colors.red.withOpacity(0.1)
                                : daysUntilDue <= 3
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOverdue
                                ? 'OVERDUE'
                                : daysUntilDue == 0
                                ? 'DUE TODAY'
                                : daysUntilDue <= 3
                                ? '${daysUntilDue}d left'
                                : 'On time',
                            style: TextStyle(
                              color: isOverdue
                                  ? Colors.red
                                  : daysUntilDue <= 3
                                  ? Colors.orange
                                  : Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Description (if available)
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                ],

                // Bottom Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due Date',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM dd, yyyy').format(dueDate),
                          style: TextStyle(
                            color: isOverdue ? Colors.red : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isUpdating
                          ? null
                          : () => _markBillAsPaid(billId, bill),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOverdue ? Colors.red : Colors.teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payment_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            isOverdue ? 'Pay Now' : 'Mark Paid',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.teal,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Pending Bills',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You\'re all caught up! No bills\nare waiting for payment.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add New Bill',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('bill_payment_scaffold'),
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        elevation: 0,
        title: const Text(
          'Pending Bills',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
            ),
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
          const SizedBox(width: 8),
        ],
        centerTitle: true,
      ),
      body: _isUpdating
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Processing payment...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        key: _streamKey,
        stream: _firestore
            .collection('users')
            .doc(widget.userId)
            .collection('bills')
            .where('status', isEqualTo: 'pending')
            .orderBy('dueDate', descending: false) // Show earliest due dates first
            .snapshots(),
        builder: (context, snapshot) {
          print('StreamBuilder snapshot: ConnectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, docs: ${snapshot.data?.docs.length ?? 0}, error: ${snapshot.error}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('failed-precondition')) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error Loading Bills',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A Firestore index is required. Please create it here:',
                      style: TextStyle(color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      'https://console.firebase.google.com/v1/r/project/fyp1-da867/firestore/indexes?create_composite=Ckhwcm9qZWN0cy9meXAxLWRhODY3L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9iaWxscy9pbmRleGVzL18QARoKCgZzdGF0dXMQARoLCgdkdWVEYXRlEAEaDAoIX19uYW1lX18QAQ',
                      style: TextStyle(color: Colors.teal, decoration: TextDecoration.underline),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _streamKey = UniqueKey();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error Loading Bills',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please try again later.',
                    style: TextStyle(color: Colors.white60),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _streamKey = UniqueKey();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final bills = snapshot.data!.docs;

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 16),
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index].data() as Map<String, dynamic>;
              final billId = bills[index].id;

              print('Navigating to BillDetailsScreen with billId: $billId, billData: $bill');

              return _buildBillCard(bill, billId, index, bills.length);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordBillPage(
                userId: widget.userId,
                onBillAdded: () {
                  setState(() {
                    _streamKey = UniqueKey(); // Force re-fetch when a bill is added
                  });
                },
              ),
            ),
          );
        },
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Bill',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}