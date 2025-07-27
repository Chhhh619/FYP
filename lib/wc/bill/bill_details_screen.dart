import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BillDetailsScreen extends StatefulWidget {
  final String userId;
  final String billId;
  final Map<String, dynamic> billData;

  const BillDetailsScreen({
    Key? key,
    required this.userId,
    required this.billId,
    required this.billData,
  }) : super(key: key);

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  bool _isPaying = false;

  Future<void> _markBillAsPaid(BuildContext context) async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final amount = widget.billData['amount'] as double? ?? 0.0;
    final billerName = widget.billData['billerName'] as String? ?? 'Unknown Biller';
    final description = widget.billData['description'] as String? ?? 'No description';
    final categoryName = widget.billData['categoryName'] as String? ?? 'Uncategorized';

    setState(() {
      _isPaying = true;
    });

    try {
      final batch = _firestore.batch();
      batch.update(
        _firestore.collection('users').doc(widget.userId).collection('bills').doc(widget.billId),
        {
          'status': 'paid',
          'paidAt': Timestamp.now(),
        },
      );
      batch.set(
        _firestore.collection('users').doc(widget.userId).collection('payments').doc(),
        {
          'userId': widget.userId,
          'billId': widget.billId,
          'billerName': billerName,
          'description': description,
          'amount': amount,
          'categoryName': categoryName,
          'timestamp': Timestamp.now(),
        },
      );

      await batch.commit();
      print('Batch commit successful for markBillAsPaid: billId=${widget.billId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill marked as paid')),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('Error marking bill as paid: $e\nStackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking bill as paid: $e')),
        );
      }
    } finally {
      if (mounted) {
        print('Resetting _isPaying to false');
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract bill data with fallback values
    final billerName = widget.billData['billerName'] as String? ?? 'Unknown Biller';
    final accountNumber = widget.billData['accountNumber'] as String? ?? 'N/A';
    final description = widget.billData['description'] as String? ?? 'No description';
    final amount = widget.billData['amount'] as double? ?? 0.0;
    final dueDate = (widget.billData['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = widget.billData['status'] as String? ?? 'pending';
    final createdAt = (widget.billData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final categoryName = widget.billData['categoryName'] as String? ?? 'Uncategorized';

    print('BillDetailsScreen billData: ${widget.billData}');

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: Text(
          billerName,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            print('Back button pressed');
            try {
              Navigator.pop(context);
            } catch (e) {
              print('Navigation error: $e');
            }
          },
        ),
        elevation: 0,
      ),
      body: _isPaying
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  color: const Color.fromRGBO(50, 50, 50, 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          icon: Icons.person,
                          label: 'Biller',
                          value: billerName,
                          isBold: true,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.account_circle,
                          label: 'Account Number',
                          value: accountNumber,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.description,
                          label: 'Description',
                          value: description,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.category,
                          label: 'Category',
                          value: categoryName,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.monetization_on,
                          label: 'Amount',
                          value: 'RM${amount.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.calendar_today,
                          label: 'Due Date',
                          value: DateFormat('MMM dd, yyyy').format(dueDate),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.check_circle,
                          label: 'Status',
                          value: status,
                          valueColor: status == 'pending' ? Colors.white70 : Colors.greenAccent,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.access_time,
                          label: 'Created',
                          value: DateFormat('MMM dd, yyyy HH:mm').format(createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (status == 'pending')
            Container(
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isPaying ? null : () => _markBillAsPaid(context),
                child: const Text(
                  'Pay Bill',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.teal, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 18,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}