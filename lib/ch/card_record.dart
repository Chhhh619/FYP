import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CardRecordPage extends StatefulWidget {
  final String cardType;
  final String bankName;
  final String bankLogo;

  const CardRecordPage({
    super.key,
    required this.cardType,
    required this.bankName,
    required this.bankLogo,
  });

  @override
  State<CardRecordPage> createState() => _CardRecordPageState();
}

class _CardRecordPageState extends State<CardRecordPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _last4Controller = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  bool _isLoading = false;

  void _saveCard() async {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final String name = _nameController.text.trim();
    final String last4 = _last4Controller.text.trim();
    final double? balance = double.tryParse(_balanceController.text.trim());

    if (name.isEmpty || last4.length != 4 || balance == null || balance < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create the card document
      final cardDocRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cards')
          .add({
        'name': name,
        'last4': last4,
        'balance': balance,
        'bankName': widget.bankName,
        'bankLogo': widget.bankLogo,
        'type': widget.cardType,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Create an initial transaction for card creation (if balance > 0)
      if (balance > 0) {
        await FirebaseFirestore.instance
            .collection('transactions')
            .add({
          'userId': userId,
          'cardId': cardDocRef.id,
          'type': 'card_creation',
          'description': 'Initial card setup - $name',
          'amount': balance,
          'timestamp': FieldValue.serverTimestamp(),
          'category': 'setup',
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card "$name" added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to the main page with success result
      Navigator.popUntil(context, (route) => route.isFirst);
      // Return true to indicate success
      Navigator.pop(context, true);

    } catch (e) {
      print("Failed to save card: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save card: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = widget.cardType.toLowerCase() == 'debit';

    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Card Info', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bank Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    widget.bankLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.account_balance, color: Colors.white),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.bankName,
                      style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${widget.cardType} Card',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Card Name Field
            Text(
              '${isDebit ? "Debit" : "Credit"} Card Name',
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Personal Account, Business Card',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[600]!, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Last 4 Digits Field
            Text(
              'Last 4 Digits',
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _last4Controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
              decoration: InputDecoration(
                counterText: '',
                hintText: '1234',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[600]!, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Initial Balance Field
            Text(
              'Current Balance',
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixText: 'RM ',
                prefixStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[600]!, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              'Enter your current card balance',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),

            const Spacer(),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent[700],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  'Save Card',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}