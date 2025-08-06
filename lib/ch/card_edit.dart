import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/card_model.dart';

class CardEditPage extends StatefulWidget {
  final CardModel card;

  CardEditPage({required this.card});

  @override
  _CardEditPageState createState() => _CardEditPageState();
}

class _CardEditPageState extends State<CardEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _last4Controller;
  late TextEditingController _balanceController;

  String _selectedBankName = '';
  String _selectedCardType = '';
  bool _isLoading = false;

  final List<String> _bankNames = [
    'Maybank',
    'Public Bank',
    'RHB Bank',
    'CIMB Bank',
    'HSBC',
    'Bank Islam',
    'AmBank',
    'OCBC',
    'UOB',
  ];

  final List<String> _cardTypes = [
    'Debit',
    'Credit',
    'Savings',
    'Current',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card.name);
    _last4Controller = TextEditingController(text: widget.card.last4);
    _balanceController = TextEditingController(text: widget.card.balance.toString());
    _selectedBankName = widget.card.bankName;
    _selectedCardType = widget.card.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _last4Controller.dispose();
    _balanceController.dispose();
    super.dispose();
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

  Future<void> _updateCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final balance = double.parse(_balanceController.text);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(widget.card.id)
          .update({
        'name': _nameController.text.trim(),
        'bankName': _selectedBankName,
        'bankLogo': _getBankLogoPath(_selectedBankName),
        'type': _selectedCardType,
        'last4': _last4Controller.text.trim(),
        'balance': balance,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return true to indicate successful update

    } catch (e) {
      print('Error updating card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update card: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCard() async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text('Delete Card', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this card?',
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All transaction history for this card will be preserved.',
                        style: TextStyle(
                          color: Colors.red[300],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Delete the card
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(widget.card.id)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, 'deleted'); // Return 'deleted' to indicate deletion

    } catch (e) {
      print('Error deleting card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete card: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
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
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Card',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _isLoading ? null : _deleteCard,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Preview
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getBankColor(_selectedBankName).withOpacity(0.8),
                            _getBankColor(_selectedBankName).withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _getBankColor(_selectedBankName).withOpacity(0.3),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedBankName.isEmpty ? 'Bank Name' : _selectedBankName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: _selectedBankName.isNotEmpty
                                    ? Image.asset(
                                  _getBankLogoPath(_selectedBankName),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.account_balance,
                                      color: Colors.white,
                                      size: 20,
                                    );
                                  },
                                )
                                    : Icon(Icons.account_balance,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Text(
                            '**** **** **** ${_last4Controller.text.isEmpty ? '0000' : _last4Controller.text}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CARD HOLDER',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _nameController.text.isEmpty ? 'Card Name' : _nameController.text.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'BALANCE',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'RM${_balanceController.text.isEmpty ? '0' : _balanceController.text}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Form Fields
                    Text(
                      'Card Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: 16),

                    // Card Name
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Card Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a card name';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),

                    SizedBox(height: 16),

                    // Bank Name Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedBankName.isEmpty ? null : _selectedBankName,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Bank Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                      ),
                      dropdownColor: Colors.grey[800],
                      items: _bankNames.map((String bank) {
                        return DropdownMenuItem<String>(
                          value: bank,
                          child: Text(bank, style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedBankName = newValue ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a bank';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16),

                    // Card Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCardType.isEmpty ? null : _selectedCardType,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Card Type',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                      ),
                      dropdownColor: Colors.grey[800],
                      items: _cardTypes.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type, style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCardType = newValue ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a card type';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16),

                    // Last 4 Digits
                    TextFormField(
                      controller: _last4Controller,
                      style: TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: 'Last 4 Digits',
                        labelStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length != 4) {
                          return 'Please enter exactly 4 digits';
                        }
                        if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) {
                          return 'Please enter only numbers';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),

                    SizedBox(height: 16),

                    // Balance
                    TextFormField(
                      controller: _balanceController,
                      style: TextStyle(color: Colors.white),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Current Balance',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixText: 'RM ',
                        prefixStyle: TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.teal),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the current balance';
                        }
                        if (double.tryParse(value.trim()) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value.trim()) < 0) {
                          return 'Balance cannot be negative';
                        }
                        return null;
                      },
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateCard,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                        'Update Card',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // Delete Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _deleteCard,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete Card',
                        style: TextStyle(
                          color: Colors.red,
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
      ),
    );
  }
}