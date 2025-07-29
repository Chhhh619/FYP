import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddGoalPage extends StatefulWidget {
  const AddGoalPage({super.key});

  @override
  _AddGoalPageState createState() => _AddGoalPageState();
}

class _AddGoalPageState extends State<AddGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              surface: Color.fromRGBO(33, 35, 34, 1),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color.fromRGBO(33, 35, 34, 1),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save goal')),
      );
      return;
    }

    try {
      await _firestore.collection('goals').add({
        'userId': userId,
        'name': _nameController.text.trim(),
        'targetAmount': double.parse(_targetAmountController.text.trim()),
        'currentAmount': 0.0,
        'deadline': Timestamp.fromDate(_deadline),
        'created_at': Timestamp.now(),
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving goal: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text(
          'Add Goal',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Goal Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                decoration: InputDecoration(
                  labelText: 'Target Amount (RM)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a target amount';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text(
                  'Deadline',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  DateFormat('d MMM yyyy').format(_deadline),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                onTap: () => _selectDeadline(context),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Goal',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditGoalPage extends StatefulWidget {
  const EditGoalPage({super.key});

  @override
  _EditGoalPageState createState() => _EditGoalPageState();
}

class _EditGoalPageState extends State<EditGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  DateTime? _deadline;
  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? goalId;
  Map<String, dynamic>? goalData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          goalId = args['goalId'] as String;
          goalData = args['data'] as Map<String, dynamic>;
          _nameController.text = goalData?['name'] as String;
          _targetAmountController.text = (goalData?['targetAmount'] is int
              ? (goalData?['targetAmount'] as int).toDouble()
              : (goalData?['targetAmount'] as double))
              .toString();
          _deadline = (goalData?['deadline'] as Timestamp).toDate();
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              surface: Color.fromRGBO(33, 35, 34, 1),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color.fromRGBO(33, 35, 34, 1),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<void> _updateGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final userId = _auth.currentUser?.uid;
    if (userId == null || goalId == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to update goal')),
      );
      return;
    }

    try {
      await _firestore.collection('goals').doc(goalId).update({
        'name': _nameController.text.trim(),
        'targetAmount': double.parse(_targetAmountController.text.trim()),
        'deadline': Timestamp.fromDate(_deadline!),
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating goal: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (goalData == null || _deadline == null) {
      return Scaffold(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text(
          'Edit Goal',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Goal Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a goal name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                decoration: InputDecoration(
                  labelText: 'Target Amount (RM)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a target amount';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text(
                  'Deadline',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  DateFormat('d MMM yyyy').format(_deadline!),
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(Icons.calendar_today, color: Colors.white70),
                onTap: () => _selectDeadline(context),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _updateGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Update Goal',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}