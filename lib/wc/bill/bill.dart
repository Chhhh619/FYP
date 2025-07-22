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

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
    id: json['id'] as String? ?? 'Unknown ID',
    title: json['title'] as String? ?? 'Untitled',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    dueDate: (json['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    category: json['category'] as String? ?? 'Uncategorized',
    isPaid: json['isPaid'] as bool? ?? false,
    paymentHistory: (json['paymentHistory'] as List<dynamic>?)?.map((record) => PaymentRecord(
      paymentDate: (record['paymentDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: (record['amount'] as num?)?.toDouble() ?? 0.0,
    )).toList() ?? [],
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