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
  final String? selectedFromCardId;
  final String? selectedToCardId;

  const GoalDetailsPage({
    super.key,
    required this.goal,
    required this.goalId,
    required this.intervalIndex,
    required this.intervalDueDate,
    required this.amountPerInterval,
    this.selectedFromCardId,
    this.selectedToCardId,
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
  @override
  @override
  @override
  void initState() {
    super.initState();

    final intervalsDeposited = Map<String, dynamic>.from(
      widget.goal['intervalsDeposited'] ?? {},
    );

    final intervalData = intervalsDeposited['${widget.intervalIndex}'];
    if (intervalData != null) {
      if (intervalData is Map<String, dynamic>) {
        // New format: {amount: 400.0, cardId: "4LEt0WSpu8sneAdpFpzY"}
        _amountController = TextEditingController(
          text: (intervalData['amount'] as num).toStringAsFixed(0),
        );
        // Prefill From Card if cardId exists
        if (intervalData['cardId'] != null) {
          _fetchCardDetails(intervalData['cardId'] as String, 'from');
        }
        // Prefill To Card if toCardId exists (add if needed)
        // if (intervalData['toCardId'] != null) {
        //   _fetchCardDetails(intervalData['toCardId'] as String, 'to');
        // }
      } else if (intervalData is num) {
        // Legacy format: 400.0
        _amountController = TextEditingController(
          text: intervalData.toStringAsFixed(0),
        );
        // No cardId in legacy format, rely on selectedFromCardId if provided
        if (widget.selectedFromCardId != null) {
          _fetchCardDetails(widget.selectedFromCardId!, 'from');
        }
      }
    } else {
      // No existing data, use calculated amount per interval
      _amountController = TextEditingController(
        text: widget.amountPerInterval.toStringAsFixed(0),
      );
    }

    // Prefill From Card if selectedFromCardId is provided and _fromCard is null
    if (widget.selectedFromCardId != null && _fromCard == null) {
      _fetchCardDetails(widget.selectedFromCardId!, 'from');
    }
    // Prefill To Card if selectedToCardId is provided and _toCard is null (add if needed)
    if (widget.selectedToCardId != null && _toCard == null) {
      _fetchCardDetails(widget.selectedToCardId!, 'to');
    }
  }
// Make _fetchCardDetails async and handle the fetch
  Future<void> _fetchCardDetails(String cardId, String role) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final cardRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(cardId);

      final cardSnap = await cardRef.get();
      if (cardSnap.exists) {
        setState(() {
          if (role == 'from') {
            _fromCard = cardSnap.data() as Map<String, dynamic>;
          } else {
            _toCard = cardSnap.data() as Map<String, dynamic>;
          }
        });
      }
    } catch (e) {
      print('Error fetching card details: $e');
    }
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

  Future<void> _saveDeposit(double enteredAmount) async {
    final goalRef = FirebaseFirestore.instance
        .collection('goals')
        .doc(widget.goalId);

    final goalSnap = await goalRef.get();
    if (!goalSnap.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal not found'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final goalData = goalSnap.data() as Map<String, dynamic>;
    final totalAmount = (goalData['totalAmount'] ?? 0).toDouble();
    final intervalsDeposited =
    Map<String, dynamic>.from(goalData['intervalsDeposited'] ?? {});
    final intervalData = intervalsDeposited['${widget.intervalIndex}'] ?? {};
    final oldAmount = (intervalData['amount'] ?? 0).toDouble();

    final diff = enteredAmount - oldAmount;
    final updatedDeposited =
        (goalData['depositedAmount'] ?? 0).toDouble() + diff;

    // 🚫 Prevent over-deposit BEFORE transaction
    if (updatedDeposited > totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Deposit exceeds goal amount by RM${(updatedDeposited - totalAmount).toStringAsFixed(2)}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final fromCardRef = _fromCard != null
        ? FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cards')
        .doc(_fromCard!['id'])
        : null;

    final toCardRef = _toCard != null
        ? FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cards')
        .doc(_toCard!['id'])
        : null;

    // ✅ Run transaction only if deposit is valid
    await FirebaseFirestore.instance.runTransaction((txn) async {
      if (fromCardRef != null) {
        final fromCardSnap = await txn.get(fromCardRef);
        if (fromCardSnap.exists) {
          txn.update(fromCardRef, {
            'balance': (fromCardSnap['balance'] ?? 0).toDouble() - diff,
          });
        }
      }

      if (toCardRef != null) {
        final toCardSnap = await txn.get(toCardRef);
        if (toCardSnap.exists) {
          txn.update(toCardRef, {
            'balance': (toCardSnap['balance'] ?? 0).toDouble() + diff,
          });
        }
      }

      // Update intervalData with amount and cardId
      final updatedIntervalData = {
        'amount': enteredAmount,
        'cardId': _fromCard?['id'], // Store the fromCardId
        // 'toCardId': _toCard?['id'], // Uncomment if you want to store toCardId
      };
      intervalsDeposited['${widget.intervalIndex}'] = updatedIntervalData;

      final updates = {
        'intervalsDeposited': intervalsDeposited,
        'depositedAmount': updatedDeposited,
      };

      if (updatedDeposited >= totalAmount) {
        updates['status'] = 'completed';
        updates['completedDate'] = FieldValue.serverTimestamp();
      }

      txn.update(goalRef, updates);
    });

    // 🔹 Log transaction
    final transactionsRef =
    FirebaseFirestore.instance.collection('transactions').doc();

    if (diff > 0 && _fromCard != null) {
      await transactionsRef.set({
        'userId': userId,
        'fromCardId': _fromCard!['id'],
        'toCardId': _toCard?['id'],
        'type': 'goal_deposit',
        'description': 'Deposit to goal ${widget.goal['name']}',
        'amount': diff,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else if (diff < 0 && _fromCard != null) {
      await transactionsRef.set({
        'userId': userId,
        'fromCardId': _toCard?['id'],
        'toCardId': _fromCard!['id'],
        'type': 'goal_withdrawal',
        'description': 'Refund from goal ${widget.goal['name']}',
        'amount': diff.abs(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    Navigator.pop(context, true);
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
            onPressed: () {
              final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
              _saveDeposit(enteredAmount);
            },
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