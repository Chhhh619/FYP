import 'package:flutter/material.dart';
import '../bill/bill.dart';

class NotificationService {
  static OverlayEntry? _overlayEntry;

  static void showNotification(BuildContext context, String message) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 20,
        right: 20,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  static void checkBillReminders(BuildContext context, List<Bill> bills) {
    final now = DateTime.now();
    for (var bill in bills) {
      if (!bill.isPaid && bill.dueDate.isAfter(now) && bill.dueDate.difference(now).inDays <= 1) {
        showNotification(context, 'Reminder: ${bill.title} is due on ${bill.dueDate.toString().substring(0, 10)}');
      }
    }
  }
}