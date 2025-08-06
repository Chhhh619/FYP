import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/card_model.dart';
import 'select_card_popup.dart';

class CardTransferPage extends StatefulWidget {
  final CardModel fromCard;

  CardTransferPage({required this.fromCard});

  @override
  _CardTransferPageState createState() => _CardTransferPageState();
}

class _CardTransferPageState extends State<CardTransferPage> {
  final TextEditingController amountController = TextEditingController();
  Map<String, dynamic>? fromCard;
  Map<String, dynamic>? toCard;
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize fromCard with the passed card data
    fromCard = {
      'id': widget.fromCard.id,
      'name': widget.fromCard.name,
      'balance': widget.fromCard.balance,
      'bankName': widget.fromCard.bankName,
      'type': widget.fromCard.type,
      'last4': widget.fromCard.last4,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transfer',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // From Card (Selectable)
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
                          fromCard = selectedCard;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.arrow_upward, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fromCard != null ? fromCard!['name'] : 'Select source card',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Transfer out',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Show amount input dialog
                              _showAmountDialog();
                            },
                            child: Text(
                              amountController.text.isEmpty
                                  ? 'RM0\nClick to set amount'
                                  : 'RM${amountController.text}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Transfer direction arrow
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.teal,
                      size: 24,
                    ),
                  ),

                  SizedBox(height: 16),

                  // To Card (Selectable)
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
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.arrow_downward, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  toCard != null ? toCard!['name'] : 'Select destination card',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Transfer',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            toCard != null
                                ? 'RM${(toCard!['balance'] ?? 0.0).toStringAsFixed(0)}'
                                : 'RM0',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 32),

                  // Date Section
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, color: Colors.grey[400]),
                          SizedBox(width: 12),
                          Text(
                            'Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Spacer(),
                          Text(
                            _formatDateTime(selectedDate),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transfer Button
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: isLoading ? null : _executeTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                'Transfer',
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
    );
  }

  void _showAmountDialog() {
    final TextEditingController dialogAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Enter Amount', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: dialogAmountController,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  amountController.text = dialogAmountController.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.grey[800]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.teal,
                onPrimary: Colors.white,
                surface: Colors.grey[800]!,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _executeTransfer() async {
    final amount = double.tryParse(amountController.text) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (fromCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a source card')),
      );
      return;
    }

    if (toCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a destination card')),
      );
      return;
    }

    if (fromCard!['id'] == toCard!['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot transfer to the same card')),
      );
      return;
    }

    if (amount > (fromCard!['balance'] ?? 0.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. Available: RM${(fromCard!['balance'] ?? 0.0).toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final userId = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        // References for both cards
        final fromCardRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(fromCard!['id']);

        final toCardRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(toCard!['id']);

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
          'timestamp': Timestamp.fromDate(selectedDate),
          'fromCardId': fromCard!['id'],
          'toCardId': toCard!['id'],
          'type': 'transfer',
          'description': 'Card Transfer',
          'name': 'Transfer to ${toCard!['name']}',
          'icon': '🔄',
          'fromCardName': fromCard!['name'],
          'toCardName': toCard!['name'],
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer successful! RM${amount.toStringAsFixed(2)} sent to ${toCard!['name']}'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return true to indicate successful transfer

    } catch (e) {
      print('Transfer error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transfer failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}