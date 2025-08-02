import 'package:flutter/material.dart';
import 'card_record.dart';

class CardOptionsPage extends StatelessWidget {
  final String cardType;

  const CardOptionsPage({super.key, required this.cardType});

  final List<Map<String, dynamic>> banks = const [
    {'name': 'Maybank', 'logo': '🟡'},
    {'name': 'Public Bank', 'logo': '🔴'},
    {'name': 'RHB Bank', 'logo': '🔵'},
    {'name': 'CIMB Bank', 'logo': '🟥'},
    {'name': 'HSBC', 'logo': '🏦'},
    {'name': 'Bank Islam', 'logo': '🟠'},
    {'name': 'AmBank', 'logo': '🟥'},
    {'name': 'OCBC', 'logo': '🔶'},
    {'name': 'UOB', 'logo': '🔷'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Select Bank', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: banks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final bank = banks[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CardRecordPage(
                    cardType: cardType,
                    bankName: bank['name'],
                    bankLogo: bank['logo'],
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: Row(
                children: [
                  Text(bank['logo'], style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Text(bank['name'],
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
