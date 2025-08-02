import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'select_card_popup.dart';

class IncomeDetailsPage extends StatefulWidget {
  final Map<String, dynamic> category;
  final String categoryId;

  const IncomeDetailsPage({
    super.key,
    required this.category,
    required this.categoryId,
  });

  @override
  State<IncomeDetailsPage> createState() => _IncomeDetailsPageState();
}

class _IncomeDetailsPageState extends State<IncomeDetailsPage> {
  final formatter = NumberFormat.currency(symbol: 'RM');
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  DateTime _startDate = DateTime.now();
  String _repeatType = 'Monthly';
  Map<String, dynamic>? _toCard;
  bool _isEnabled = false;
  String? _existingIncomeId;

  final userId = FirebaseAuth.instance.currentUser!.uid;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
    _loadExistingIncome();
  }

  Future<void> _loadExistingIncome() async {
    try {
      final categoryRef = _firestore.collection('categories').doc(widget.categoryId);
      final incomeSnapshot = await _firestore
          .collection('incomes')
          .where('userid', isEqualTo: userId)
          .where('category', isEqualTo: categoryRef)
          .limit(1)
          .get();

      if (incomeSnapshot.docs.isNotEmpty) {
        final incomeData = incomeSnapshot.docs.first.data();
        setState(() {
          _existingIncomeId = incomeSnapshot.docs.first.id;
          _nameController.text = incomeData['name'] ?? '';
          _amountController.text = (incomeData['amount'] ?? 0.0).toString();
          _startDate = (incomeData['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          _repeatType = incomeData['repeat'] ?? 'Monthly';
          _isEnabled = incomeData['isEnabled'] ?? false;

          // Load card info if exists
          if (incomeData['toCardId'] != null) {
            _loadCardInfo(incomeData['toCardId']);
          }
        });
      } else {
        // Set default values for new income
        setState(() {
          _nameController.text = widget.category['name'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading existing income: $e');
    }
  }

  Future<void> _loadCardInfo(String cardId) async {
    try {
      final cardDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(cardId)
          .get();

      if (cardDoc.exists) {
        setState(() {
          _toCard = {
            'id': cardDoc.id,
            ...cardDoc.data()!,
          };
        });
      }
    } catch (e) {
      print('Error loading card info: $e');
    }
  }

  void _selectCard() async {
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
        _toCard = selectedCard;
      });
    }
  }

  void _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Color.fromRGBO(33, 35, 34, 1),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  void _showRepeatTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Repeat Type',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['Daily', 'Weekly', 'Monthly', 'Annually'].map((type) {
                  return ChoiceChip(
                    label: Text(type, style: const TextStyle(color: Colors.white)),
                    selected: _repeatType == type,
                    selectedColor: Colors.teal,
                    backgroundColor: Colors.grey[800],
                    onSelected: (_) {
                      setState(() => _repeatType = type);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveIncome() async {
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final enteredName = _nameController.text.trim();

    if (enteredName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an income name')),
      );
      return;
    }

    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    try {
      final categoryRef = _firestore.collection('categories').doc(widget.categoryId);
      final incomeData = {
        'userid': userId,
        'name': enteredName,
        'amount': enteredAmount,
        'startDate': Timestamp.fromDate(_startDate),
        'repeat': _repeatType,
        'category': categoryRef,
        'icon': widget.category['icon'] ?? '💰',
        'isEnabled': _isEnabled,
        'toCardId': _toCard?['id'],
        'lastGenerated': null, // Will be set when first transaction is generated
      };

      if (_existingIncomeId != null) {
        // Update existing income
        await _firestore.collection('incomes').doc(_existingIncomeId).update(incomeData);
      } else {
        // Create new income
        final docRef = await _firestore.collection('incomes').add(incomeData);
        _existingIncomeId = docRef.id;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEnabled
              ? 'Automated income setup successfully!'
              : 'Income saved. Enable automation to start recording.'),
          backgroundColor: _isEnabled ? Colors.green : Colors.orange,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save income: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteIncome() async {
    if (_existingIncomeId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
        title: const Text('Delete Income Setup', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this automated income? This will not affect existing transactions.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('incomes').doc(_existingIncomeId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income setup deleted successfully')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete income: ${e.toString()}')),
        );
      }
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
    final categoryName = widget.category['name'] ?? 'Income';

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
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  categoryName,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_existingIncomeId != null)
                GestureDetector(
                  onTap: _deleteIncome,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white, size: 20),
                  ),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Automation toggle
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isEnabled ? Colors.green[900] : Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isEnabled ? Colors.green : Colors.grey[700]!,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isEnabled ? Icons.autorenew : Icons.pause_circle_outline,
                  color: _isEnabled ? Colors.green : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEnabled ? 'Automation Enabled' : 'Automation Disabled',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isEnabled
                            ? 'Income will be automatically recorded'
                            : 'Enable to start automatic recording',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),

          const Text(
            'Income Details',
            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildTile(
            icon: Icons.edit,
            title: 'Income Name',
            trailing: SizedBox(
              width: 150,
              child: TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.end,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter name',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),

          _buildTile(
            icon: Icons.monetization_on,
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
                  hintText: 'RM 0.00',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),

          _buildTile(
            icon: Icons.calendar_today,
            title: 'Start Date',
            onTap: _pickStartDate,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(_startDate),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),

          _buildTile(
            icon: Icons.repeat,
            title: 'Repeat',
            onTap: _showRepeatTypeSelector,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _repeatType,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),

          _buildTile(
            icon: Icons.account_balance_wallet,
            title: 'Deposit to Card',
            onTap: _selectCard,
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
            onPressed: _saveIncome,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _existingIncomeId != null ? 'Update Income Setup' : 'Save Income Setup',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}