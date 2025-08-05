import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/card_model.dart';
import 'card_transaction_record.dart';
import 'select_card_popup.dart'; // You'll need to import this from your goal_details.dart location
import 'record_transaction.dart'; // Import for the transaction recording

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

      // Query 1: Incoming transfers (where this card is the recipient)
      try {
        final QuerySnapshot incomingTransfers = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('toCardId', isEqualTo: currentCard.id)
            .orderBy('timestamp', descending: true)
            .get();

        // Process incoming transfers
        for (var doc in incomingTransfers.docs) {
          final data = doc.data() as Map<String, dynamic>;
          String type = data['type'] ?? 'Transfer In';
          String description = data['description'] ?? 'Transfer received';
          IconData icon;

          // Handle different transaction types
          switch (type) {
            case 'goal_deposit':
              icon = Icons.savings;
              break;
            case 'transfer':
              icon = Icons.arrow_downward;
              break;
            default:
              icon = Icons.arrow_downward;
          }

          allTransactions.add(Transaction(
            id: doc.id,
            type: _formatTransactionType(type),
            description: description,
            amount: (data['amount'] ?? 0.0).toDouble(),
            date: (data['timestamp'] as Timestamp).toDate(),
            isIncoming: true,
            icon: icon,
          ));
        }
        print('Found ${incomingTransfers.docs.length} incoming transfers');
      } catch (e) {
        print('Error loading incoming transfers: $e');
      }

      // Query 2: Outgoing transfers (where this card is the sender)
      try {
        final QuerySnapshot outgoingTransfers = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('fromCardId', isEqualTo: currentCard.id)
            .orderBy('timestamp', descending: true)
            .get();

        // Process outgoing transfers
        for (var doc in outgoingTransfers.docs) {
          final data = doc.data() as Map<String, dynamic>;
          String type = data['type'] ?? 'Transfer Out';
          String description = data['description'] ?? 'Transfer sent';
          IconData icon;

          // Handle different transaction types
          switch (type) {
            case 'goal_deposit':
              icon = Icons.savings;
              break;
            case 'transfer':
              icon = Icons.arrow_upward;
              break;
            default:
              icon = Icons.arrow_upward;
          }

          allTransactions.add(Transaction(
            id: doc.id,
            type: _formatTransactionType(type),
            description: description,
            amount: (data['amount'] ?? 0.0).toDouble(),
            date: (data['timestamp'] as Timestamp).toDate(),
            isIncoming: false,
            icon: icon,
          ));
        }
        print('Found ${outgoingTransfers.docs.length} outgoing transfers');
      } catch (e) {
        print('Error loading outgoing transfers: $e');
      }

      // Query 3: Direct card transactions (income, expenses, etc.)
      try {
        final QuerySnapshot cardTransactions = await FirebaseFirestore.instance
            .collection('transactions')
            .where('userId', isEqualTo: userId)
            .where('cardId', isEqualTo: currentCard.id)
            .orderBy('timestamp', descending: true)
            .get();

        // Process direct card transactions
        for (var doc in cardTransactions.docs) {
          final data = doc.data() as Map<String, dynamic>;
          String type = data['type'] ?? 'Transaction';
          IconData icon = Icons.credit_card;
          bool isIncoming = false;

          switch (type.toLowerCase()) {
            case 'income':
            case 'deposit':
              icon = Icons.attach_money;
              isIncoming = true;
              break;
            case 'expense':
            case 'withdrawal':
              icon = Icons.money_off;
              isIncoming = false;
              break;
            case 'card_creation':
              icon = Icons.credit_card;
              isIncoming = true;
              type = 'Card Created';
              break;
          }

          allTransactions.add(Transaction(
            id: doc.id,
            type: type,
            description: data['description'] ?? type,
            amount: (data['amount'] ?? 0.0).toDouble(),
            date: (data['timestamp'] as Timestamp).toDate(),
            isIncoming: isIncoming,
            icon: icon,
          ));
        }
        print('Found ${cardTransactions.docs.length} direct card transactions');
      } catch (e) {
        print('Error loading card transactions: $e');
      }

      // Query 4: Income transactions from the incomes collection
      try {
        final QuerySnapshot incomesSnapshot = await FirebaseFirestore.instance
            .collection('incomes')
            .where('userId', isEqualTo: userId)
            .where('toCardId', isEqualTo: currentCard.id)
            .orderBy('lastGenerated', descending: true)
            .get();

        // Process income transactions from incomes collection
        for (var doc in incomesSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          allTransactions.add(Transaction(
            id: doc.id,
            type: 'Income',
            description: data['name'] ?? 'Income received',
            amount: (data['amount'] ?? 0.0).toDouble(),
            date: (data['lastGenerated'] as Timestamp).toDate(),
            isIncoming: true,
            icon: Icons.attach_money,
          ));
        }
        print('Found ${incomesSnapshot.docs.length} income transactions');
      } catch (e) {
        print('Error loading income transactions: $e');
      }

      // Add card creation transaction if no transactions exist
      if (allTransactions.isEmpty) {
        allTransactions.add(Transaction(
          id: 'initial_${currentCard.id}',
          type: 'Card Created',
          description: 'Initial card setup',
          amount: currentCard.balance,
          date: DateTime.now(),
          isIncoming: true,
          icon: Icons.credit_card,
        ));
      }

      // Sort all transactions by date (newest first)
      allTransactions.sort((a, b) => b.date.compareTo(a.date));

      print('Total transactions loaded: ${allTransactions.length}');

      setState(() {
        transactions = allTransactions;
        isLoading = false;
      });

    } catch (e) {
      print('Error loading transactions: $e');
      setState(() {
        isLoading = false;
      });

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  String _formatTransactionType(String type) {
    switch (type) {
      case 'goal_deposit':
        return 'Goal Deposit';
      case 'transfer':
        return 'Transfer';
      default:
        return type;
    }
  }

  // Transfer money between cards
  Future<void> _showTransferDialog() async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController(text: 'Transfer');
    Map<String, dynamic>? toCard;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Transfer Money', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // From Card (current card - read only)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('From: ${currentCard.name}',
                                    style: TextStyle(color: Colors.white)),
                                Text('Balance: RM${currentCard.balance.toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    // To Card (selectable)
                    GestureDetector(
                      onTap: () async {
                        final selectedCard = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (context) => SelectCardPopup(
                            onCardSelected: (card) {
                              Navigator.pop(context, card);
                            },
                          ),
                        );
                        if (selectedCard != null) {
                          setState(() {
                            toCard = selectedCard;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: toCard != null
                                  ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('To: ${toCard!['name']}',
                                      style: TextStyle(color: Colors.white)),
                                  Text('Balance: RM${(toCard!['balance'] ?? 0.0).toStringAsFixed(2)}',
                                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              )
                                  : Text('Select destination card',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                            Icon(Icons.chevron_right, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Amount input
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixText: 'RM ',
                        prefixStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Description input
                    TextField(
                      controller: descriptionController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    if (toCard == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a destination card')),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    await _executeTransfer(amount, toCard!, descriptionController.text);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: Text('Transfer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _executeTransfer(double amount, Map<String, dynamic> toCard, String description) async {
    if (amount > currentCard.balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. Available: RM${currentCard.balance.toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        // References for both cards
        final fromCardRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(currentCard.id);

        final toCardRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(toCard['id']);

        // Read current balances
        final fromCardDoc = await txn.get(fromCardRef);
        final toCardDoc = await txn.get(toCardRef);

        if (!fromCardDoc.exists || !toCardDoc.exists) {
          throw Exception('One or both cards not found');
        }

        final fromBalance = (fromCardDoc.data()!['balance'] ?? 0.0).toDouble();
        final toBalance = (toCardDoc.data()!['balance'] ?? 0.0).toDouble();

        // Update card balances
        txn.update(fromCardRef, {'balance': fromBalance - amount});
        txn.update(toCardRef, {'balance': toBalance + amount});

        // Create transaction record
        final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();
        txn.set(transactionRef, {
          'userId': userId,
          'amount': amount,
          'timestamp': Timestamp.now(),
          'fromCardId': currentCard.id,
          'toCardId': toCard['id'],
          'type': 'transfer',
          'description': description.isEmpty ? 'Transfer' : description,
        });
      });

      // Update local card balance
      setState(() {
        currentCard = CardModel(
          id: currentCard.id,
          name: currentCard.name,
          bankName: currentCard.bankName,
          bankLogo: currentCard.bankLogo,
          type: currentCard.type,
          last4: currentCard.last4,
          balance: currentCard.balance - amount,
        );
      });

      _loadTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer successful! RM${amount.toStringAsFixed(2)} sent to ${toCard['name']}'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Transfer error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add money to card (similar to income recording)
  Future<void> _showAddMoneyDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Choose Action', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add Money Option
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_circle, color: Colors.green),
                ),
                title: Text('Add Money', style: TextStyle(color: Colors.white)),
                subtitle: Text('Add income to this card', style: TextStyle(color: Colors.grey[400])),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CardTransactionPage(
                        card: currentCard,
                        transactionType: 'income',
                        onTransactionSaved: (newBalance) {
                          setState(() {
                            currentCard = CardModel(
                              id: currentCard.id,
                              name: currentCard.name,
                              bankName: currentCard.bankName,
                              bankLogo: currentCard.bankLogo,
                              type: currentCard.type,
                              last4: currentCard.last4,
                              balance: newBalance,
                            );
                          });
                          _loadTransactions();
                        },
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 8),

              // Record Expense Option
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.remove_circle, color: Colors.red),
                ),
                title: Text('Record Expense', style: TextStyle(color: Colors.white)),
                subtitle: Text('Record spending from this card', style: TextStyle(color: Colors.grey[400])),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CardTransactionPage(
                        card: currentCard,
                        transactionType: 'expense',
                        onTransactionSaved: (newBalance) {
                          setState(() {
                            currentCard = CardModel(
                              id: currentCard.id,
                              name: currentCard.name,
                              bankName: currentCard.bankName,
                              bankLogo: currentCard.bankLogo,
                              type: currentCard.type,
                              last4: currentCard.last4,
                              balance: newBalance,
                            );
                          });
                          _loadTransactions();
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
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

          // Action Buttons
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showTransferDialog,
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
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showAddMoneyDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[600],
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Transaction', // Changed from 'Add Money'
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
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