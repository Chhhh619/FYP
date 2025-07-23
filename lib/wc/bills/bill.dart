import 'package:cloud_firestore/cloud_firestore.dart';

class Bill {
  final String id;
  final String userId;
  final String category;
  final String description;
  final double amount;
  final DateTime dueDate;
  final DateTime? paymentDate;
  final bool isPaid;
  final String frequency;

  Bill({
    required this.id,
    required this.userId,
    required this.category,
    required this.description,
    required this.amount,
    required this.dueDate,
    this.paymentDate,
    this.isPaid = false,
    required this.frequency,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'category': category,
      'description': description,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'paymentDate': paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'isPaid': isPaid,
      'frequency': frequency,
    };
  }

  factory Bill.fromMap(String id, Map<String, dynamic> data) {
    return Bill(
      id: id,
      userId: data['userId'],
      category: data['category'],
      description: data['description'],
      amount: data['amount'],
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paymentDate: data['paymentDate'] != null
          ? (data['paymentDate'] as Timestamp).toDate()
          : null,
      isPaid: data['isPaid'] ?? false,
      frequency: data['frequency'],
    );
  }
}