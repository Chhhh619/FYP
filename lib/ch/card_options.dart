import 'package:flutter/material.dart';
import 'card_record.dart';

class CardOptionsPage extends StatelessWidget {
  final String cardType;

  const CardOptionsPage({super.key, required this.cardType});

  final List<Map<String, dynamic>> banks = const [
    {'name': 'Maybank', 'logo': 'assets/images/maybank.png'},
    {'name': 'Public Bank', 'logo': 'assets/images/pbb.png'},
    {'name': 'RHB Bank', 'logo': 'assets/images/rhb.png'},
    {'name': 'CIMB Bank', 'logo': 'assets/images/cimb.png'},
    {'name': 'HSBC', 'logo': 'assets/images/hsbc.png'},
    {'name': 'Bank Islam', 'logo': 'assets/images/bankislam.png'},
    {'name': 'AmBank', 'logo': 'assets/images/ambank.png'},
    {'name': 'OCBC', 'logo': 'assets/images/ocbc.png'},
    {'name': 'UOB', 'logo': 'assets/images/uob.png'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        title: const Text('Select Bank', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: banks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final bank = banks[index];
          return GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
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
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                    child: Image.asset(
                      bank['logo'],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.account_balance,
                          color: Colors.white70,
                          size: 20,
                        );
                      },
                    ),
                  ),
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