import 'package:cloud_firestore/cloud_firestore.dart';

class Bill {
  String id;
  String title;
  double amount;
  DateTime dueDate;
  String category;
  bool isPaid;
  List<PaymentRecord> paymentHistory;

  Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.category,
    this.isPaid = false,
    this.paymentHistory = const [],
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'dueDate': dueDate,
    'category': category,
    'isPaid': isPaid,
    'paymentHistory': paymentHistory.map((record) => {
      'paymentDate': record.paymentDate,
      'amount': record.amount,
    }).toList(),
  };

  // Create Bill from Firestore snapshot
  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'],
    title: json['title'],
    amount: json['amount'],
    dueDate: (json['dueDate'] as Timestamp).toDate(),
    category: json['category'],
    isPaid: json['isPaid'],
    paymentHistory: (json['paymentHistory'] as List).map((record) => PaymentRecord(
      paymentDate: (record['paymentDate'] as Timestamp).toDate(),
      amount: record['amount'],
    )).toList(),
  );
}

class PaymentRecord {
  DateTime paymentDate;
  double amount;

  PaymentRecord({
    required this.paymentDate,
    required this.amount,
  });
}