import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_card_popup.dart';

class GoalDetailsPage extends StatefulWidget {
  final Map<String, dynamic> goal;
  final String goalId;
  final int intervalIndex;
  final DateTime intervalDueDate;
  final double amountPerInterval;

  const GoalDetailsPage({
    super.key,
    required this.goal,
    required this.goalId,
    required this.intervalIndex,
    required this.intervalDueDate,
    required this.amountPerInterval,
  });

  @override
  State<GoalDetailsPage> createState() => _GoalDetailsPageState();
}

class _GoalDetailsPageState extends State<GoalDetailsPage> {
  final formatter = NumberFormat.currency(symbol: 'RM');
  late TextEditingController _amountController;
  double? deposited;
  Map<String, dynamic>? _fromCard;
  Map<String, dynamic>? _toCard;

  final userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.amountPerInterval.toStringAsFixed(0),
    );
    final intervalsDeposited = Map<String, dynamic>.from(
      widget.goal['intervalsDeposited'] ?? {},
    );
    deposited = (intervalsDeposited['${widget.intervalIndex}'] ?? 0).toDouble();
  }

  void _selectCard(String role) async {
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
        if (role == 'from') {
          _fromCard = selectedCard;
        } else {
          _toCard = selectedCard;
        }
      });
    }
  }

  Future<void> _saveDeposit() async {
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0;

    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Check if at least one card is selected
    if (_fromCard == null && _toCard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one card')),
      );
      return;
    }

    // Calculate the difference from previous deposit
    final previousDeposit = deposited ?? 0;
    final diff = enteredAmount - previousDeposit;

    final goalRef = FirebaseFirestore.instance
        .collection('goals')
        .doc(widget.goalId);

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        // FIRST: Read all required documents
        DocumentReference<Map<String, dynamic>>? fromCardRef;
        DocumentReference<Map<String, dynamic>>? toCardRef;
        DocumentSnapshot<Map<String, dynamic>>? fromCardDoc;
        DocumentSnapshot<Map<String, dynamic>>? toCardDoc;

        if (_fromCard != null) {
          fromCardRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(_fromCard!['id']);
          fromCardDoc = await txn.get(fromCardRef);
        }

        if (_toCard != null) {
          toCardRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('cards')
              .doc(_toCard!['id']);
          toCardDoc = await txn.get(toCardRef);
        }

        // Validate card existence and balance
        if (_fromCard != null && fromCardDoc != null) {
          if (!fromCardDoc.exists) {
            throw Exception('From card not found: ${_fromCard!['name']}');
          }
          final currentFromBalance = (fromCardDoc.data()!['balance'] ?? 0.0).toDouble();

          if (diff > 0 && currentFromBalance < diff) {
            throw Exception('Insufficient balance in ${_fromCard!['name']}. Available: RM${currentFromBalance.toStringAsFixed(2)}, Required: RM${diff.toStringAsFixed(2)}');
          }
        }

        if (_toCard != null && toCardDoc != null) {
          if (!toCardDoc.exists) {
            throw Exception('To card not found: ${_toCard!['name']}');
          }
        }

        // SECOND: Perform all writes
        // Update goal progress
        final currentIntervalsDeposited = Map<String, dynamic>.from(
          widget.goal['intervalsDeposited'] ?? {},
        );
        currentIntervalsDeposited['${widget.intervalIndex}'] = enteredAmount;

        txn.update(goalRef, {
          'intervalsDeposited': currentIntervalsDeposited,
          'depositedAmount': FieldValue.increment(diff),
        });

        // Update card balances and create transaction records
        if (_fromCard != null && fromCardRef != null && fromCardDoc != null) {
          final currentFromBalance = (fromCardDoc.data()!['balance'] ?? 0.0).toDouble();
          txn.update(fromCardRef, {'balance': currentFromBalance - diff});

          // Create transaction record for from card (outgoing)
          if (diff != 0) {
            final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();
            txn.set(transactionRef, {
              'userId': userId,
              'amount': diff.abs(),
              'timestamp': FieldValue.serverTimestamp(),
              'fromCardId': _fromCard!['id'],
              'toCardId': _toCard?['id'], // nullable
              'type': 'goal_deposit',
              'description': 'Goal deposit: ${widget.goal['name']}',
              'goalId': widget.goalId,
              'intervalIndex': widget.intervalIndex,
            });
          }
        }

        if (_toCard != null && toCardRef != null && toCardDoc != null) {
          final currentToBalance = (toCardDoc.data()!['balance'] ?? 0.0).toDouble();
          txn.update(toCardRef, {'balance': currentToBalance + diff});

          // Create transaction record for to card (incoming) - only if different from fromCard
          if (diff != 0 && (_fromCard == null || _fromCard!['id'] != _toCard!['id'])) {
            final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();
            txn.set(transactionRef, {
              'userId': userId,
              'amount': diff.abs(),
              'timestamp': FieldValue.serverTimestamp(),
              'fromCardId': _fromCard?['id'], // nullable
              'toCardId': _toCard!['id'],
              'type': 'goal_deposit',
              'description': 'Goal deposit received: ${widget.goal['name']}',
              'goalId': widget.goalId,
              'intervalIndex': widget.intervalIndex,
            });
          }
        }
      });

      // Update local state after successful transaction - fetch fresh data
      if (_fromCard != null) {
        final updatedFromCard = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(_fromCard!['id'])
            .get();
        if (updatedFromCard.exists) {
          setState(() {
            _fromCard!['balance'] = (updatedFromCard.data()!['balance'] ?? 0.0).toDouble();
          });
        }
      }

      if (_toCard != null) {
        final updatedToCard = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cards')
            .doc(_toCard!['id'])
            .get();
        if (updatedToCard.exists) {
          setState(() {
            _toCard!['balance'] = (updatedToCard.data()!['balance'] ?? 0.0).toDouble();
          });
        }
      }

      setState(() {
        deposited = enteredAmount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit saved successfully!')),
      );
      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save deposit: ${e.toString()}')),
      );
    }
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.tealAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white70)),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalName = widget.goal['name'] ?? 'Goal';

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              // Title
              Expanded(
                child: Text(
                  goalName,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 40), // Spacer to balance the layout
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                tileColor: Colors.grey[900],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: const Text(
                  'Deposit',
                  style: TextStyle(color: Colors.white70),
                ),
                subtitle: Text(
                  DateFormat(
                    'dd MMM yyyy • HH:mm',
                  ).format(widget.intervalDueDate),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Text(
                  'RM${_amountController.text}',
                  style: const TextStyle(color: Colors.tealAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Deposit Details',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _buildTile(
            icon: Icons.money,
            title: 'Amount',
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                onChanged: (value) {
                  setState(() {}); // Rebuild to update the display
                },
              ),
            ),
          ),
          _buildTile(
            icon: Icons.arrow_circle_up,
            title: 'From Card',
            onTap: () => _selectCard('from'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_fromCard != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fromCard!['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'RM${(_fromCard!['balance'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Select Card',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ],
            ),
          ),
          _buildTile(
            icon: Icons.arrow_circle_down,
            title: 'To Card',
            onTap: () => _selectCard('to'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_toCard != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _toCard!['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'RM${(_toCard!['balance'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Select Card',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _saveDeposit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Save Deposit',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}