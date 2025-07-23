import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import '../bill/bill.dart';
import '../bill/notification_service.dart';

class BillListItem extends StatelessWidget {
  final Bill bill;
  final String userId;
  BillListItem({required this.bill, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(bill.title),
      subtitle: Text('${bill.category} - \$${bill.amount} - Due: ${bill.dueDate.toString().substring(0, 10)}'),
      trailing: Icon(bill.isPaid ? Icons.check_circle : Icons.warning, color: bill.isPaid ? Colors.green : Colors.red),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(bill.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Amount: \$${bill.amount}'),
                Text('Category: ${bill.category}'),
                Text('Due: ${bill.dueDate.toString().substring(0, 10)}'),
                Text('Status: ${bill.isPaid ? "Paid" : "Unpaid"}'),
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
                        .update(bill.toJson());
                    NotificationService.showNotification(context, '${bill.title} marked as paid!');
                    Navigator.pop(context);
                  },
                  child: Text('Mark as Paid'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/payment_history', arguments: bill);
                  },
                  child: Text('View Payment History'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}