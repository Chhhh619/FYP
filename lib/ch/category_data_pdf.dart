import 'package:pdf/pdf.dart';

class CategoryData {
  final String name;
  final double amount;
  final double percentage;
  final PdfColor color;
  final String type;

  CategoryData({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.type,
  });
}