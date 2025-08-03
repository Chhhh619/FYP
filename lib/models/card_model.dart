import 'package:flutter/material.dart';

class CardModel {
  final String id;
  final String name;
  final String type;
  final double balance;
  final String bankName;
  final String bankLogo;
  final String last4;

  CardModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.bankName,
    required this.bankLogo,
    required this.last4,
  });
}

class Transaction {
  final String id;
  final String type;
  final String description;
  final double amount;
  final DateTime date;
  final bool isIncoming;
  final IconData icon;

  Transaction({
    required this.id,
    required this.type,
    required this.description,
    required this.amount,
    required this.date,
    required this.isIncoming,
    required this.icon,
  });
}