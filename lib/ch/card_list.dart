import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'card_details.dart';
import 'card.dart';
import '../models/card_model.dart';
import '../wc/financial_tips.dart';
import '../wc/gamification_page.dart';
import '../ch/settings.dart';

class CardListPage extends StatefulWidget {
  @override
  _CardListPageState createState() => _CardListPageState();
}

class _CardListPageState extends State<CardListPage> {
  List<CardModel> debitCards = [];
  List<CardModel> creditCards = [];
  bool isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchCards();
  }

  Future<void> _fetchCards() async {
    try {
      final String userId = FirebaseAuth.instance.currentUser!.uid;
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cards')
          .orderBy('timestamp', descending: true)
          .get();

      List<CardModel> fetchedDebitCards = [];
      List<CardModel> fetchedCreditCards = [];

      for (var doc in snapshot.docs) {
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
          fetchedDebitCards.add(card);
        } else {
          fetchedCreditCards.add(card);
        }
      }

      setState(() {
        debitCards = fetchedDebitCards;
        creditCards = fetchedCreditCards;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching cards: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  double get totalBalance =>
      debitCards.fold(0.0, (sum, card) => sum + card.balance);

  double get totalCreditAvailable =>
      creditCards.fold(0.0, (sum, card) => sum + card.balance);

  void _onBottomNavTapped(int index) {
    setState(() => _selectedIndex = index);

    switch (index) {
      case 0:
        _fetchCards();
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FinancialTipsScreen()));
        break;
      case 2:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GamificationPage()));
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
            // Custom back + title + plus button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Assets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CardTypeSelectionPage()),
                      );
                      if (result == true) _fetchCards();
                    },
                  ),
                ],
              ),
            ),

            Expanded(
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(color: Colors.teal[600]),
              )
                  : RefreshIndicator(
                onRefresh: _fetchCards,
                color: Colors.teal[600],
                backgroundColor: Colors.grey[800],
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary card
                      _buildSummaryCard(),

                      const SizedBox(height: 24),
                      _buildSection(
                          title: 'Debit Cards',
                          cards: debitCards,
                          balance: totalBalance),
                      if (creditCards.isNotEmpty)
                        _buildSection(
                          title: 'Credit Cards',
                          cards: creditCards,
                          balance: totalCreditAvailable,
                          isCredit: true,
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal[600]!, Colors.teal[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Balance',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text('RM${totalBalance.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${debitCards.length + creditCards.length} card${(debitCards.length + creditCards.length) != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const Spacer(),
              const Icon(Icons.trending_up, color: Colors.white70, size: 20),
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
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.credit_card_off,
                    color: Colors.grey, size: 48),
                const SizedBox(height: 12),
                Text('No ${title.toLowerCase()} found',
                    style: const TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Tap the + button to add your first card',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CardDetailsPage(card: card)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.1),
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
                      color: Colors.white70, size: 24),
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
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('${card.type} •••• ${card.last4}',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 13)),
                    ]),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Balance',
                        style:
                        TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('RM${card.balance.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
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
