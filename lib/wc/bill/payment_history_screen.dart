import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onRefresh;

  const PaymentHistoryScreen({Key? key, required this.userId, this.onRefresh}) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  bool _isDeleting = false;

  Future<void> _clearAllPayments(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(50, 50, 50, 1),
        title: const Text('Clear All Payment History', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to clear all payment history? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('payments')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var paymentDoc in paymentsSnapshot.docs) {
        batch.delete(paymentDoc.reference);
      }

      await batch.commit().then((_) {
        print('Batch commit successful for clearAllPayments');
      }).catchError((e, stackTrace) {
        print('Batch commit failed for clearAllPayments: $e\nStackTrace: $stackTrace');
        throw e;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All payment history cleared')),
        );
      }
      widget.onRefresh?.call();
    } catch (e, stackTrace) {
      print('Error clearing payment history: $e\nStackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing payment history: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<void> _deleteSinglePayment(BuildContext context, String paymentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(50, 50, 50, 1),
        title: const Text('Delete Payment', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this payment? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('payments')
          .doc(paymentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted')),
        );
      }
      widget.onRefresh?.call();
    } catch (e, stackTrace) {
      print('Error deleting payment: $e\nStackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text('Payment History', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: _isDeleting ? null : () => _clearAllPayments(context),
            tooltip: 'Clear All Payments',
          ),
        ],
        elevation: 0,
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('payments')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }
          if (snapshot.hasError) {
            print('StreamBuilder error: ${snapshot.error}');
            return const Center(
              child: Text('Error loading payment history', style: TextStyle(color: Colors.redAccent)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No payments found', style: TextStyle(color: Colors.white70)),
            );
          }

          final payments = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index].data() as Map<String, dynamic>;
              final paymentId = payments[index].id;
              final billerName = payment['billerName'] as String? ?? 'Unknown Biller';
              final description = payment['description'] as String? ?? 'No description';
              final amount = payment['amount'] as double? ?? 0.0;
              final timestamp = (payment['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final categoryName = payment['categoryName'] as String? ?? 'Uncategorized';

              return GestureDetector(
                onLongPress: _isDeleting ? null : () => _deleteSinglePayment(context, paymentId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(50, 50, 50, 1),
                    borderRadius: BorderRadius.circular(8),
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
                            'Description: $description',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Text(
                            'Paid: ${DateFormat('MMM dd, yyyy HH:mm').format(timestamp)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                      Text(
                        'RM${amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}