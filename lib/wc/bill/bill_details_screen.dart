import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'notification_service.dart';

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
  bool _isViewingImage = false;

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
          if (widget.billData['billImageUrl'] != null)
            'billImageUrl': widget.billData['billImageUrl'],
        },
      );

      await batch.commit();

      // Show notification for bill paid
      await NotificationService().showBillPaidNotification(
        billerName: billerName,
        amount: amount,
        categoryName: categoryName,
      );

      // Cancel scheduled notification for this bill
      await NotificationService().cancelNotification(widget.billId);

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
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  void _showFullScreenImage(String imageUrl) {
    setState(() {
      _isViewingImage = true;
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _isViewingImage = false;
                });
              },
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 3.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isViewingImage = false;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billerName = widget.billData['billerName'] as String? ?? 'Unknown Biller';

    final description = widget.billData['description'] as String? ?? 'No description';
    final amount = widget.billData['amount'] as double? ?? 0.0;
    final dueDate = (widget.billData['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = widget.billData['status'] as String? ?? 'pending';
    final createdAt = (widget.billData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final categoryName = widget.billData['categoryName'] as String? ?? 'Uncategorized';
    final billImageUrl = widget.billData['billImageUrl'] as String?;

    final isOverdue = status == 'pending' && dueDate.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        elevation: 0,
        title: Text(
          billerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isPaying || _isViewingImage
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.teal),
            const SizedBox(height: 16),
            Text(
              _isPaying ? 'Processing payment...' : 'Loading image...',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Status Header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOverdue
                    ? [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)]
                    : status == 'paid'
                    ? [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]
                    : [Colors.teal.withOpacity(0.1), Colors.teal.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOverdue
                    ? Colors.red.withOpacity(0.3)
                    : status == 'paid'
                    ? Colors.green.withOpacity(0.3)
                    : Colors.teal.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? Colors.red.withOpacity(0.1)
                            : status == 'paid'
                            ? Colors.green.withOpacity(0.1)
                            : Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOverdue
                            ? Icons.warning_rounded
                            : status == 'paid'
                            ? Icons.check_circle_rounded
                            : Icons.schedule_rounded,
                        color: isOverdue
                            ? Colors.red
                            : status == 'paid'
                            ? Colors.green
                            : Colors.teal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOverdue
                                ? 'OVERDUE'
                                : status == 'paid'
                                ? 'PAID'
                                : 'PENDING',
                            style: TextStyle(
                              color: isOverdue
                                  ? Colors.red
                                  : status == 'paid'
                                  ? Colors.green
                                  : Colors.teal,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RM${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isOverdue) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'This bill is overdue',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Bill Image Section
          if (billImageUrl != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bill Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showFullScreenImage(billImageUrl),
                    child: Hero(
                      tag: 'billImage-${widget.billId}',
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color.fromRGBO(45, 45, 45, 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CachedNetworkImage(
                                imageUrl: billImageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(color: Colors.teal),
                                ),
                                errorWidget: (context, url, error) => const Center(
                                  child: Icon(Icons.error, color: Colors.red, size: 32),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to zoom',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Bill Details Section
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bill Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(45, 45, 45, 1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.business_rounded,
                            label: 'Biller Name',
                            value: billerName,
                            isBold: true,
                          ),

                          const SizedBox(height: 20),
                          _buildDetailRow(
                            icon: Icons.description_rounded,
                            label: 'Description',
                            value: description,
                          ),
                          const SizedBox(height: 20),
                          _buildDetailRow(
                            icon: Icons.category_rounded,
                            label: 'Category',
                            value: categoryName,
                          ),
                          const SizedBox(height: 20),
                          _buildDetailRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Due Date',
                            value: DateFormat('MMM dd, yyyy').format(dueDate),
                            valueColor: isOverdue ? Colors.red : null,
                          ),
                          const SizedBox(height: 20),
                          _buildDetailRow(
                            icon: Icons.access_time_rounded,
                            label: 'Created On',
                            value: DateFormat('MMM dd, yyyy • HH:mm').format(createdAt),
                          ),
                          if (status == 'paid') ...[
                            const SizedBox(height: 20),
                            _buildDetailRow(
                              icon: Icons.check_circle_rounded,
                              label: 'Payment Status',
                              value: 'Completed',
                              valueColor: Colors.green,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Pay Button Section
          if (status == 'pending')
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(28, 28, 28, 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOverdue ? Colors.red : Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                  ),
                  onPressed: _isPaying ? null : () => _markBillAsPaid(context),
                  child: _isPaying
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        isOverdue ? 'Pay Overdue Bill' : 'Mark as Paid',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.teal, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}