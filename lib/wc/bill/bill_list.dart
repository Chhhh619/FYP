import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bill/bill.dart';
import '../bill/notification_service.dart';

class BillListItem extends StatelessWidget {
  final Bill bill;
  final String userId;
  BillListItem({required this.bill, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        title: Text(
          bill.title,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        subtitle: Text(
          '${bill.category} - \$${bill.amount.toStringAsFixed(2)} - Due: ${bill.dueDate.toString().substring(0, 10)}',
          style: TextStyle(color: Colors.grey[400]),
        ),
        trailing: Icon(
          bill.isPaid ? Icons.check_circle : Icons.warning,
          color: bill.isPaid ? Colors.green[300] : Colors.red[300],
        ),
        onTap: () {
          if (bill.isPaid) return; // Prevent action if already paid
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
                  Text('Due: ${bill.dueDate.toString().substring(0, 10)}', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  Text('Status: Unpaid', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      bill.isPaid = true;
                      bill.paymentHistory.add(PaymentRecord(
                        paymentDate: DateTime.now(),
                        amount: bill.amount,
                      ));
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('bills')
                          .doc(bill.id)
                          .update(bill.toJson())
                          .then((_) {
                        NotificationService.showNotification(context, '${bill.title} marked as paid!');
                        Navigator.pushReplacementNamed(context, '/payment_history', arguments: userId);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Mark as Paid', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child:  Text('Close', style: TextStyle(color: Colors.grey[400])),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}