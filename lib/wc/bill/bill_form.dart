import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../bill/bill.dart';

class BillForm extends StatefulWidget {
  final String userId;
  final Bill? bill;
  BillForm({required this.userId, this.bill});

  @override
  _BillFormState createState() => _BillFormState();
}

class _BillFormState extends State<BillForm> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late double _amount;
  late DateTime _dueDate;
  late String _category;
  bool _isRecurring = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Safely initialize with default String values
    _title = widget.bill?.title ?? '';
    _amount = widget.bill?.amount ?? 0.0;
    _dueDate = widget.bill?.dueDate is Timestamp
        ? (widget.bill!.dueDate as Timestamp).toDate()
        : (widget.bill?.dueDate ?? DateTime.now());
    _category = widget.bill?.category ?? 'Utilities'; // Ensure a valid default category
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _saveBill() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        final billData = {
          'title': _title,
          'amount': _amount,
          'dueDate': Timestamp.fromDate(_dueDate),
          'category': _category,
          'isPaid': false,
          'paymentHistory': [],
        };
        if (widget.bill == null) {
          await _firestore.collection('users').doc(widget.userId).collection('bills').add(billData);
          if (_isRecurring) {
            final nextDueDate = _dueDate.add(Duration(days: 30)); // Monthly recurrence
            await _firestore.collection('users').doc(widget.userId).collection('bills').add({
              ...billData,
              'dueDate': Timestamp.fromDate(nextDueDate),
            });
          }
        } else {
          await _firestore.collection('users').doc(widget.userId).collection('bills').doc(widget.bill!.id).update(billData);
        }
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving bill: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(widget.bill == null ? 'Add Bill' : 'Edit Bill', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _title,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: Colors.white), filled: true, fillColor: Colors.grey[900]),
                validator: (value) => value!.isEmpty ? 'Enter a title' : null,
                onSaved: (value) => _title = value!,
              ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: _amount.toString(),
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Amount', labelStyle: TextStyle(color: Colors.white), filled: true, fillColor: Colors.grey[900]),
                keyboardType: TextInputType.number,
                validator: (value) => double.tryParse(value!) == null ? 'Enter a valid amount' : null,
                onSaved: (value) => _amount = double.parse(value!),
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text('Due Date', style: TextStyle(color: Colors.white)),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(_dueDate), style: TextStyle(color: Colors.grey[400])),
                trailing: Icon(Icons.calendar_today, color: Colors.white),
                onTap: () => _selectDate(context),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: Colors.grey[900],
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white), filled: true, fillColor: Colors.grey[900]),
                items: ['Utilities', 'Rent', 'Credit Card', 'Subscription', 'Other']
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
                validator: (value) => value == null ? 'Select a category' : null,
              ),
              SizedBox(height: 16),
              CheckboxListTile(
                title: Text('Recurring', style: TextStyle(color: Colors.white)),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value!),
                activeColor: Colors.teal,
                checkColor: Colors.white,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveBill,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                child: Text(widget.bill == null ? 'Add Bill' : 'Update Bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}