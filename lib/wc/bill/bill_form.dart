import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../bill/bill.dart';

class BillForm extends StatefulWidget {
  final Bill? bill;
  final String userId;
  BillForm({this.bill, required this.userId});

  @override
  _BillFormState createState() => _BillFormState();
}

class _BillFormState extends State<BillForm> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late double _amount;
  late DateTime _dueDate;
  late String _category;
  final _categories = ['Utilities', 'Rent', 'Credit Card', 'Subscription', 'Other'];

  @override
  void initState() {
    super.initState();
    _title = widget.bill?.title ?? '';
    _amount = widget.bill?.amount ?? 0.0;
    _dueDate = widget.bill?.dueDate ?? DateTime.now();
    _category = widget.bill?.category ?? _categories[0];
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Bill',
            style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _title,
            decoration: InputDecoration(
              labelText: 'Bill Title',
              labelStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) => value!.isEmpty ? 'Enter a title' : null,
            onSaved: (value) => _title = value!,
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _amount.toString(),
            decoration: InputDecoration(
              labelText: 'Amount',
              labelStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            validator: (value) => value!.isEmpty ? 'Enter an amount' : null,
            onSaved: (value) => _amount = double.parse(value!),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: Colors.grey[900],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[900],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            items: _categories.map((category) => DropdownMenuItem(
              value: category,
              child: Text(category),
            )).toList(),
            onChanged: (value) => setState(() => _category = value!),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Due Date: ${_dueDate.toString().substring(0, 10)}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Icon(Icons.calendar_today, color: Colors.grey[400]),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: Colors.grey[700]!,
                        onPrimary: Colors.white,
                        surface: Colors.grey[900]!,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) setState(() => _dueDate = date);
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final bill = Bill(
                  id: widget.bill?.id ?? Uuid().v4(),
                  title: _title,
                  amount: _amount,
                  dueDate: _dueDate,
                  category: _category,
                  isPaid: widget.bill?.isPaid ?? false,
                  paymentHistory: widget.bill?.paymentHistory ?? [],
                );
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .collection('bills')
                    .doc(bill.id)
                    .set(bill.toJson());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Add Bill',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}