import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'card.dart';

class SelectCardPopup extends StatelessWidget {
  final Function(Map<String, dynamic>) onCardSelected;

  const SelectCardPopup({super.key, required this.onCardSelected});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a Card',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('cards')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final cards = snapshot.data!.docs;

                  if (cards.isEmpty) {
                    return const Center(
                      child: Text('No cards yet',
                          style: TextStyle(color: Colors.white70)),
                    );
                  }

                  return ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final cardDoc = cards[index];
                      final card = cardDoc.data() as Map<String, dynamic>;

                      // Add the document ID to the card data
                      card['id'] = cardDoc.id;

                      final name = card['name'] ?? '';
                      final last4 = card['last4'] ?? '';
                      final balance = card['balance'] ?? 0.0;
                      final bankLogo = card['logo'] ?? '';
                      final type = card['type'] ?? '';

                      return ListTile(
                        onTap: () {
                          onCardSelected(card);
                        },
                        leading: bankLogo != ''
                            ? Image.network(bankLogo, width: 40, height: 40)
                            : const Icon(Icons.credit_card, color: Colors.white),
                        title: Text('$name ($type)',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text('•••• $last4',
                            style: const TextStyle(color: Colors.white70)),
                        trailing: Text('RM ${balance.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.tealAccent)),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close popup
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const CardTypeSelectionPage()),
                  );
                },
              icon: const Icon(Icons.add),
              label: const Text('Add New Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}