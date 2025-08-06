import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/card_model.dart';
import 'card_transfer.dart'; // Import the card transfer page

class CardDetailsPage extends StatefulWidget {
  final CardModel card;

  CardDetailsPage({required this.card});

  @override
  _CardDetailsPageState createState() => _CardDetailsPageState();
}

class _CardDetailsPageState extends State<CardDetailsPage> {
  List<Transaction> transactions = [];
  bool isLoading = true;
  late CardModel currentCard; // Track the current card state

  @override
  void initState() {
    super.initState();
    currentCard = widget.card; // Initialize with the passed card
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final String userId = FirebaseAuth.instance.currentUser!.uid;
      List<Transaction> allTransactions = [];

      print('Loading transactions for card: ${currentCard.id}');

      // Query 1: Transactions where this card receives money (toCardId)
      // This includes: transfers, goal deposits to card, income transactions etc.
      try {
        final QuerySnapshot incomingQuery = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('toCardId', isEqualTo: currentCard.id)
            .orderBy('timestamp', descending: true)
            .get();

        for (var doc in incomingQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          allTransactions.add(_createTransactionFromData(doc.id, data, true));
        }
        print('Found ${incomingQuery.docs.length} incoming transactions');
      } catch (e) {
        print('Error loading incoming transactions: $e');
      }

      // Query 2: Transactions where this card sends money (fromCardId)
      // This includes: transfers, goal deposits from card, subscription payments, etc.
      try {
        final QuerySnapshot outgoingQuery = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('fromCardId', isEqualTo: currentCard.id)
            .orderBy('timestamp', descending: true)
            .get();

        for (var doc in outgoingQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          // For outgoing transactions, they are expenses (money leaving the card)
          allTransactions.add(_createTransactionFromData(doc.id, data, false));
        }
        print('Found ${outgoingQuery.docs.length} outgoing transactions (including subscriptions)');
      } catch (e) {
        print('Error loading outgoing transactions: $e');
      }

      // Query 3: Direct card transactions (cardId field)
      // This includes: manual income/expense recordings
      try {
        final QuerySnapshot cardQuery = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('cardId', isEqualTo: currentCard.id)
            .orderBy('timestamp', descending: true)
            .get();

        for (var doc in cardQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          bool isIncoming = data['type'] == 'income';
          allTransactions.add(_createTransactionFromData(doc.id, data, isIncoming));
        }
        print('Found ${cardQuery.docs.length} direct card transactions');
      } catch (e) {
        print('Error loading card transactions: $e');
      }

      // Remove duplicates (in case a transaction appears in multiple queries)
      Map<String, Transaction> uniqueTransactions = {};
      for (var transaction in allTransactions) {
        uniqueTransactions[transaction.id] = transaction;
      }

      // Sort all transactions by date (newest first)
      List<Transaction> finalTransactions = uniqueTransactions.values.toList();
      finalTransactions.sort((a, b) => b.date.compareTo(a.date));

      print('Total unique transactions loaded: ${finalTransactions.length}');

      setState(() {
        transactions = finalTransactions;
        isLoading = false;
      });

    } catch (e) {
      print('Error loading transactions: $e');
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

// Helper method to create Transaction objects from Firestore data
  Transaction _createTransactionFromData(String docId, Map<String, dynamic> data, bool isIncoming) {
    String type = data['type'] ?? 'transaction';
    String name = data['name'] ?? '';
    String subscriptionId = data['subscriptionId'] ?? '';
    String incomeId = data['incomeId'] ?? '';

    IconData icon = _getIconForTransactionType(type, isIncoming);
    String description = _getTransactionDescription(type, data, name);

    return Transaction(
      id: docId,
      type: _formatTransactionType(type, subscriptionId, incomeId, name),
      description: description,
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: (data['timestamp'] as Timestamp).toDate(),
      isIncoming: isIncoming,
      icon: icon,
    );
  }

// Helper method to get appropriate icon for transaction type
  IconData _getIconForTransactionType(String type, bool isIncoming) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return isIncoming ? Icons.arrow_downward : Icons.arrow_upward;
      case 'goal_deposit':
        return Icons.savings;
      case 'goal_withdrawal':
        return Icons.savings_outlined;
      case 'subscription':
        return Icons.subscriptions;
      case 'income':
        return Icons.attach_money;
      case 'expense':
        return Icons.money_off;
      default:
        return Icons.credit_card;
    }
  }

// Helper method to get transaction description
  String _getTransactionDescription(String type, Map<String, dynamic> data, String name) {
    switch (type.toLowerCase()) {
      case 'transfer':
        return 'Card transfer';
      case 'goal_deposit':
        String desc = data['description'] ?? '';
        if (desc.contains('Goal deposit:')) {
          return desc;
        }
        return 'Goal deposit';
      case 'goal_withdrawal':
        return 'Goal withdrawal';
      case 'subscription':
        return name.isNotEmpty ? name : 'Subscription payment';
      case 'income':
        return name.isNotEmpty ? name : 'Income received';
      case 'expense':
        return name.isNotEmpty ? name : 'Expense';
      default:
        return data['description'] ?? 'Transaction';
    }
  }

  String _formatTransactionType(String type, String subscriptionId, String incomeId, String name) {
    // If it has a subscriptionId, it's a subscription payment
    if (subscriptionId.isNotEmpty) {
      return name.isNotEmpty ? name : 'Subscription';
    }

    // If it has an incomeId, it's an income transaction
    if (incomeId.isNotEmpty) {
      return 'Income';
    }

    switch (type.toLowerCase()) {
      case 'goal_deposit':
        return 'Goal Deposit';
      case 'goal_withdrawal':
        return 'Goal Withdrawal';
      case 'transfer':
        return 'Transfer';
      case 'subscription':
        return name.isNotEmpty ? name : 'Subscription';
      case 'income':
        return 'Income';
      case 'expense':
        return 'Expense';
      default:
        return type.split('_').map((word) =>
        word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  // Navigate to transfer page
  Future<void> _navigateToTransfer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardTransferPage(fromCard: currentCard),
      ),
    );

    // If transfer was successful, reload transactions and update balance
    if (result == true) {
      _loadTransactions();
      // Refresh card balance from Firestore
      _refreshCardBalance();
    }
  }

  Future<void> _refreshCardBalance() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final cardDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(currentCard.id)
          .get();

      if (cardDoc.exists) {
        final data = cardDoc.data()!;
        setState(() {
          currentCard = CardModel(
            id: currentCard.id,
            name: currentCard.name,
            bankName: currentCard.bankName,
            bankLogo: currentCard.bankLogo,
            type: currentCard.type,
            last4: currentCard.last4,
            balance: (data['balance'] ?? 0.0).toDouble(),
          );
        });
      }
    } catch (e) {
      print('Error refreshing card balance: $e');
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
    String logoPath = currentCard.bankLogo.contains('assets/')
        ? currentCard.bankLogo
        : _getBankLogoPath(currentCard.bankName);

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Card Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Card Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _getBankColor(currentCard.bankName).withOpacity(0.3),
                      width: 1.5,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.06),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getBankColor(currentCard.bankName).withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    logoPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.account_balance,
                        color: Colors.white70,
                        size: 28,
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
                        currentCard.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${currentCard.type} card • •••• ${currentCard.last4}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
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
                      'RM${currentCard.balance.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Transactions Section
          Expanded(
            child: Container(
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${transactions.length} transaction${transactions.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transactions List
                  Expanded(
                    child: isLoading
                        ? Center(
                      child: CircularProgressIndicator(
                        color: Colors.teal[600],
                      ),
                    )
                        : transactions.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            color: Colors.grey[600],
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No transactions found',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Transactions will appear here once you start using this card',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        return _buildTransactionItem(transactions[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transfer Button (Single button now)
          Container(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Transfer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
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

  Widget _buildTransactionItem(Transaction transaction) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: transaction.isIncoming
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              transaction.icon,
              color: transaction.isIncoming ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.type,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (transaction.description.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    transaction.description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
                SizedBox(height: 4),
                Text(
                  '${transaction.date.day} ${_getMonthName(transaction.date.month)} ${transaction.date.year}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${transaction.isIncoming ? '+' : '-'}RM${transaction.amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: transaction.isIncoming ? Colors.green : Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

// Transaction model class
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