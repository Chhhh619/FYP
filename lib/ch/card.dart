import 'package:flutter/material.dart';
import 'card_options.dart';

class CardTypeSelectionPage extends StatelessWidget {
  const CardTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        title: const Text("Add New Card", style: TextStyle(color: Colors.white)),
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Select Card Type",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            _buildCardTypeButton(
              context,
              title: '💳 Debit Card',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CardOptionsPage(cardType: 'Debit'),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            _buildCardTypeButton(
              context,
              title: '🏦 Credit Card',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CardOptionsPage(cardType: 'Credit'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardTypeButton(BuildContext context,
      {required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: Color.fromRGBO(33, 35, 34, 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color.fromRGBO(33, 35, 34, 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
