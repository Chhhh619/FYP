import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateFlexibleGoalPage extends StatefulWidget {
  const CreateFlexibleGoalPage({super.key});

  @override
  State<CreateFlexibleGoalPage> createState() => _CreateFlexibleGoalPageState();
}

class _CreateFlexibleGoalPageState extends State<CreateFlexibleGoalPage> {
  final _nameController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  double _totalAmount = 0;
  String _selectedIcon = '🎯';

  final userId = FirebaseAuth.instance.currentUser!.uid;

  void _selectDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showIconPicker() async {
    final incomeIcons = await FirebaseFirestore.instance
        .collection('categories')
        .where('type', isEqualTo: 'income')
        .get();

    showModalBottomSheet(
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: incomeIcons.docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final icon = incomeIcons.docs[index]['icon'] ?? '💰';
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIcon = icon);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _saveGoal() async {
    final goal = {
      'userId': userId,
      'name': _nameController.text.trim(),
      'icon': _selectedIcon,
      'startDate': Timestamp.fromDate(_startDate),
      'endDate': Timestamp.fromDate(_endDate),
      'type': 'flexible',
      'totalAmount': _totalAmount,
      'depositedAmount': 0.0,
      'intervalsDeposited': {},
    };

    await FirebaseFirestore.instance.collection('goals').add(goal);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        title: const Text('Flexible', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _showIconPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(_selectedIcon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Plan Name', style: TextStyle(color: Colors.white70)),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Enter a name',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Date Range', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          _buildSettingTile(
            icon: Icons.calendar_today,
            title: 'Start Date',
            value: DateFormat('dd MMM yyyy').format(_startDate),
            onTap: () => _selectDate(isStart: true),
          ),
          _buildSettingTile(
            icon: Icons.calendar_today,
            title: 'End Date',
            value: DateFormat('dd MMM yyyy').format(_endDate),
            onTap: () => _selectDate(isStart: false),
          ),
          const SizedBox(height: 24),
          const Text('Amount Setting', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          _buildSettingTile(
            icon: Icons.money,
            title: 'Total Amount',
            value: 'RM${_totalAmount.toStringAsFixed(0)}',
            onTap: () async {
              final result = await showDialog<double>(
                context: context,
                builder: (_) => AmountPickerDialog(initialAmount: _totalAmount),
              );
              if (result != null) setState(() => _totalAmount = result);
            },
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _saveGoal,
            child: const Text('Add', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String value,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70)),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}

class AmountPickerDialog extends StatefulWidget {
  final double initialAmount;
  const AmountPickerDialog({super.key, required this.initialAmount});

  @override
  State<AmountPickerDialog> createState() => _AmountPickerDialogState();
}

class _AmountPickerDialogState extends State<AmountPickerDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    _controller = TextEditingController(text: widget.initialAmount.toStringAsFixed(0));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Enter Total Amount', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Amount in RM',
          hintStyle: TextStyle(color: Colors.white38),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final value = double.tryParse(_controller.text.trim()) ?? 0;
            Navigator.pop(context, value);
          },
          child: const Text('OK', style: TextStyle(color: Colors.tealAccent)),
        ),
      ],
    );
  }
}
