import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecordBillPage extends StatefulWidget {
  final String userId;
  final VoidCallback? onBillAdded;

  const RecordBillPage({Key? key, required this.userId, this.onBillAdded}) : super(key: key);

  @override
  State<RecordBillPage> createState() => _RecordBillPageState();
}

class _RecordBillPageState extends State<RecordBillPage> {
  final _formKey = GlobalKey<FormState>();
  final _billerNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  DateTime? _dueDate;
  String? _selectedCategory;
  bool _isLoading = false;

  // Hardcoded bill categories
  final List<Map<String, String>> _categories = [
    {'name': 'Utilities', 'icon': 'bolt'},
    {'name': 'Phone Bill', 'icon': 'phone'},
    {'name': 'Rent', 'icon': 'home'},
    {'name': 'Internet', 'icon': 'wifi'},
    {'name': 'Insurance', 'icon': 'security'},
    {'name': 'Other', 'icon': 'category'},
  ];

  @override
  void initState() {
    super.initState();
    // Set default category
    _selectedCategory = _categories.first['name'];
    print('Initial category: $_selectedCategory');
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Color.fromRGBO(50, 50, 50, 1),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color.fromRGBO(50, 50, 50, 1),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _saveBill() async {
    if (_formKey.currentState!.validate() && _dueDate != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        final categoryName = _selectedCategory == 'Other'
            ? _customCategoryController.text.trim()
            : _selectedCategory!;
        final billData = {
          'userId': widget.userId,
          'billerName': _billerNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'description': _descriptionController.text.trim(),
          'amount': double.parse(_amountController.text.trim()),
          'categoryName': categoryName,
          'dueDate': Timestamp.fromDate(_dueDate!),
          'status': 'pending',
          'createdAt': Timestamp.now(),
          'paidAt': null,
        };
        print('Saving bill: $billData');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('bills')
            .add(billData);
        print('Bill saved successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill added successfully')),
        );
        widget.onBillAdded?.call();
        Navigator.pop(context);
      } catch (e) {
        print('Error saving bill: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bill: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
    }
  }

  @override
  void dispose() {
    _billerNameController.dispose();
    _accountNumberController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text('Add Bill', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(context);
            });
          },
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _billerNameController,
                decoration: const InputDecoration(
                  labelText: 'Biller Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter biller name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Account Number',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter account number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (RM)',
                  labelStyle: TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Color.fromRGBO(50, 50, 50, 1),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value.trim()) == null || double.parse(value.trim()) <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDueDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color.fromRGBO(50, 50, 50, 1),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dueDate == null
                        ? 'Select due date'
                        : DateFormat('MMM dd, yyyy').format(_dueDate!),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color.fromRGBO(50, 50, 50, 1), // Dropdown menu background
                  dropdownMenuTheme: DropdownMenuThemeData(
                    textStyle: const TextStyle(color: Colors.white),
                    menuStyle: MenuStyle(
                      backgroundColor: WidgetStateProperty.all(const Color.fromRGBO(50, 50, 50, 1)),
                      surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                      elevation: WidgetStateProperty.all(8.0),
                    ),
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color.fromRGBO(50, 50, 50, 1),
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCategory,
                  items: _categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['name'],
                      child: Text(
                        category['name']!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      if (_selectedCategory != 'Other') {
                        _customCategoryController.clear();
                      }
                      print('Selected category: $value');
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a category';
                    }
                    if (value == 'Other' && (_customCategoryController.text.trim().isEmpty)) {
                      return 'Please enter a custom category';
                    }
                    return null;
                  },
                ),
              ),
              if (_selectedCategory == 'Other') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customCategoryController,
                  decoration: const InputDecoration(
                    labelText: 'Others Category',
                    labelStyle: TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: Color.fromRGBO(50, 50, 50, 1),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (_selectedCategory == 'Other' && (value == null || value.trim().isEmpty)) {
                      return 'Please enter other category';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveBill,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Save Bill', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}