import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../bottom_nav_bar.dart';
import 'card_details.dart';
import 'card.dart';
import '../models/card_model.dart';
// Add these imports to match settings.dart navigation
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

  double get totalBalance {
    double total = 0.0;
    for (var card in debitCards) {
      total += card.balance;
    }
    return total;
  }

  double get totalCreditAvailable {
    double total = 0.0;
    for (var card in creditCards) {
      total += card.balance;
    }
    return total;
  }

  void _onBottomNavTapped(int index) {
    print('BottomNavBar tapped: index = $index'); // Debug print
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        _fetchCards();
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FinancialTipsScreen(), // You'll need to import this
          ),
        );
        break;
      case 2:
      // Navigate to Gamification page (same as settings.dart)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GamificationPage(), // You'll need to import this
          ),
        );
        break;
      case 3:
      // Navigate to Settings/Mine page (same as settings.dart)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsPage(), // You'll need to import this
          ),
        );
        break;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Assets',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              // Navigate to add card page
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CardTypeSelectionPage(),
                ),
              );
              // Refresh cards if a card was added
              if (result == true) {
                _fetchCards();
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Colors.teal[600],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchCards,
        color: Colors.teal[600],
        backgroundColor: Colors.grey[800],
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.teal[600]!,
                      Colors.teal[800]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'RM${totalBalance.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${debitCards.length + creditCards.length} card${(debitCards.length + creditCards.length) != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.trending_up,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Debit Cards Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Debit Cards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (debitCards.isNotEmpty)
                    Text(
                      'Balance RM${totalBalance.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),

              // Debit Cards List
              if (debitCards.isEmpty)
                Container(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.credit_card_off,
                          color: Colors.grey[600],
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No debit cards found',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the + button to add your first card',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...debitCards.map((card) => _buildCardItem(card)).toList(),

              // Credit Cards Section (if needed)
              if (creditCards.isNotEmpty) ...[
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Credit Cards',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Available Credit RM${totalCreditAvailable.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ...creditCards.map((card) => _buildCardItem(card)).toList(),
              ],

              // Add some extra space at the bottom for better scrolling
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildCardItem(CardModel card) {
    String logoPath = card.bankLogo.contains('assets/')
        ? card.bankLogo
        : _getBankLogoPath(card.bankName);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CardDetailsPage(card: card),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getBankColor(card.bankName).withOpacity(0.2),
                      width: 1,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Image.asset(
                    logoPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.account_balance,
                        color: Colors.white70,
                        size: 24,
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${card.type} card',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '•••• ${card.last4}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Balance',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'RM${card.balance.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[500],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBankColor(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'maybank':
        return Colors.yellow;
      case 'public bank':
        return Colors.red;
      case 'rhb bank':
        return Colors.blue;
      case 'cimb bank':
        return Colors.red[700]!;
      case 'hsbc':
        return Colors.red[800]!;
      case 'bank islam':
        return Colors.orange;
      case 'ambank':
        return Colors.red[600]!;
      case 'ocbc':
        return Colors.orange[600]!;
      case 'uob':
        return Colors.blue[600]!;
      default:
        return Colors.teal;
    }
  }
}