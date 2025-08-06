import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'card_details.dart';
import 'card.dart';
import '../models/card_model.dart';
import '../wc/financial_tips.dart';
import '../wc/gamification_page.dart';
import '../ch/settings.dart';
import 'card_options.dart';

class CardListPage extends StatefulWidget {
  @override
  _CardListPageState createState() => _CardListPageState();
}

class _CardListPageState extends State<CardListPage> {
  int _selectedIndex = 0;

  void _onBottomNavTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        break; // Already on this page
      case 1:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const FinancialTipsScreen()));
        break;
      case 2:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const GamificationPage()));
        break;
      case 3:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SettingsPage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Assets',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardOptionsPage(cardType: 'Debit'),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('cards')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.teal[600]),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.credit_card_off, color: Colors.grey, size: 48),
                          SizedBox(height: 16),
                          Text('No cards yet',
                              style: TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  final debitCards = <CardModel>[];
                  final creditCards = <CardModel>[];

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final card = CardModel(
                      id: doc.id,
                      name: data['name'] ?? '',
                      type: data['type'] ?? 'Debit',
                      balance: (data['balance'] ?? 0.0).toDouble(),
                      bankName: data['bankName'] ?? '',
                      bankLogo: data['bankLogo'] ?? 'assets/images/ambank.png',
                      last4: data['last4'] ?? '',
                    );

                    if (card.type.toLowerCase() == 'debit') {
                      debitCards.add(card);
                    } else {
                      creditCards.add(card);
                    }
                  }

                  final totalBalance = debitCards.fold(0.0, (sum, c) => sum + c.balance);
                  final totalCredit = creditCards.fold(0.0, (sum, c) => sum + c.balance);

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(totalBalance, debitCards.length + creditCards.length),
                        const SizedBox(height: 24),
                        _buildSection(title: 'Debit Cards', cards: debitCards, balance: totalBalance),
                        if (creditCards.isNotEmpty)
                          _buildSection(
                            title: 'Credit Cards',
                            cards: creditCards,
                            balance: totalCredit,
                            isCredit: true,
                          ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double totalBalance, int cardCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[600]!, Colors.teal[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Balance',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 12),
          Text('RM${totalBalance.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$cardCount card${cardCount != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<CardModel> cards,
    required double balance,
    bool isCredit = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            if (cards.isNotEmpty)
              Text(
                isCredit
                    ? 'Available Credit RM${balance.toStringAsFixed(0)}'
                    : 'Balance RM${balance.toStringAsFixed(0)}',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (cards.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[700]!, width: 1),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Icon(Icons.credit_card_off,
                      color: Colors.grey, size: 48),
                ),
                const SizedBox(height: 16),
                Text('No ${title.toLowerCase()} found',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('Tap the + button above to add your first card',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          )
        else
          ...cards.map(_buildCardItem).toList()
      ],
    );
  }

  Widget _buildCardItem(CardModel card) {
    final String logoPath = card.bankLogo.contains('assets/')
        ? card.bankLogo
        : _getBankLogoPath(card.bankName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CardDetailsPage(card: card)),
        ),
        onLongPress: () => _showDeleteDialog(card),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Image.asset(
                  logoPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.account_balance,
                      color: Colors.white70, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('${card.type} •••• ${card.last4}',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 14)),
                    ]),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Balance',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('RM${card.balance.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ]),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(CardModel card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text(
          'Delete Card',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete ${card.name} (${card.type} •••• ${card.last4})?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('cards')
                    .doc(card.id)
                    .delete();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.teal[600],
                    content: const Text('Card deleted successfully'),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red[600],
                    content: const Text('Failed to delete card'),
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getBankLogoPath(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'maybank':
        return 'assets/images/maybank.png';
      case 'public bank':
        return 'assets/images/pbb.png';
      case 'rhb bank':
        return 'assets/images/rhb.png';
      case 'cimb bank':
        return 'assets/images/cimb.png';
      case 'hsbc':
        return 'assets/images/hsbc.png';
      case 'bank islam':
        return 'assets/images/bankislam.png';
      case 'ambank':
        return 'assets/images/ambank.png';
      case 'ocbc':
        return 'assets/images/ocbc.png';
      case 'uob':
        return 'assets/images/uob.png';
      default:
        return 'assets/images/ambank.png';
    }
  }
}