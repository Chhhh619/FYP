import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'notification_service.dart';

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

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  DateTime? _dueDate;
  String? _selectedCategory;
  bool _isLoading = false;
  File? _billImage;
  String? _billImageUrl;
  bool _isUploadingImage = false;

  // Card selection variables
  String? _selectedCardId;
  String? _selectedCardName;
  double _selectedCardBalance = 0.0;
  List<Map<String, dynamic>> _availableCards = [];
  bool _payWithCard = false;

  // Initialize Cloudinary - replace with your credentials
  final cloudinary = CloudinaryPublic('dftbkgqni', 'my_unsigned_preset', cache: false);

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
    _selectedCategory = _categories.first['name'];
    _loadUserCards();
  }

  Future<void> _loadUserCards() async {
    try {
      final cardsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cards')
          .orderBy('balance', descending: true)
          .get();

      setState(() {
        _availableCards = cardsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Card',
            'balance': (data['balance'] ?? 0.0).toDouble(),
            'bankName': data['bankName'] ?? '',
            'type': data['type'] ?? 'Debit',
            'last4': data['last4'] ?? '****',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading cards: $e');
    }
  }

  void _showCardSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color.fromRGBO(45, 45, 45, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.credit_card,
                        color: Colors.teal,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Payment Card',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Cards List
                Flexible(
                  child: _availableCards.isEmpty
                      ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.credit_card_off,
                          color: Colors.grey[600],
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No cards available',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add a card first to pay bills directly',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableCards.length,
                    itemBuilder: (context, index) {
                      final card = _availableCards[index];
                      final isSelected = card['id'] == _selectedCardId;
                      final hasEnoughBalance = card['balance'] >= (double.tryParse(_amountController.text) ?? 0);

                      return GestureDetector(
                        onTap: hasEnoughBalance ? () {
                          setState(() {
                            _selectedCardId = card['id'];
                            _selectedCardName = card['name'];
                            _selectedCardBalance = card['balance'];
                            _payWithCard = true;
                          });
                          Navigator.pop(context);
                        } : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.teal.withOpacity(0.2)
                                : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.teal
                                  : hasEnoughBalance
                                  ? Colors.grey[700]!
                                  : Colors.red.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: hasEnoughBalance
                                      ? Colors.teal.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.credit_card,
                                  color: hasEnoughBalance ? Colors.teal : Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${card['type']} • •••• ${card['last4']}',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'RM${card['balance'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: hasEnoughBalance ? Colors.white : Colors.red,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!hasEnoughBalance)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Insufficient',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Option to not use card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[700]!, width: 1),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _payWithCard = false;
                        _selectedCardId = null;
                        _selectedCardName = null;
                        _selectedCardBalance = 0.0;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Don\'t use card (Manual payment)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _billImage = File(pickedFile.path);
        _isUploadingImage = true;
      });

      try {
        final response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            pickedFile.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );

        setState(() {
          _billImageUrl = response.secureUrl;
          _isUploadingImage = false;
        });
      } catch (e) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _billImage = null;
      _billImageUrl = null;
    });
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
        final amount = double.parse(_amountController.text.trim());

        // Check if paying with card and has sufficient balance
        if (_payWithCard && _selectedCardId != null) {
          if (_selectedCardBalance < amount) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Insufficient card balance'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }

        final billData = {
          'userId': widget.userId,
          'billerName': _billerNameController.text.trim(),

          'description': _descriptionController.text.trim(),
          'amount': amount,
          'categoryName': categoryName,
          'dueDate': Timestamp.fromDate(_dueDate!),
          'status': _payWithCard && _selectedCardId != null ? 'paid' : 'pending',
          'createdAt': Timestamp.now(),
          'paidAt': _payWithCard && _selectedCardId != null ? Timestamp.now() : null,
          if (_billImageUrl != null) 'billImageUrl': _billImageUrl,
          if (_payWithCard && _selectedCardId != null) 'paidWithCardId': _selectedCardId,
          if (_payWithCard && _selectedCardName != null) 'paidWithCardName': _selectedCardName,
        };

        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('bills')
            .add(billData);

        // If paying with card, update card balance and create payment record
        if (_payWithCard && _selectedCardId != null) {
          // Update card balance
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('cards')
              .doc(_selectedCardId)
              .update({
            'balance': FieldValue.increment(-amount),
          });

          // Create payment record
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('payments')
              .add({
            'userId': widget.userId,
            'billId': docRef.id,
            'billerName': _billerNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'amount': amount,
            'categoryName': categoryName,
            'timestamp': Timestamp.now(),
            'cardId': _selectedCardId,
            'cardName': _selectedCardName,
            if (_billImageUrl != null) 'billImageUrl': _billImageUrl,
          });

          // Create transaction record for the card
          await FirebaseFirestore.instance
              .collection('transactions')
              .add({
            'userId': widget.userId,
            'amount': amount,
            'timestamp': Timestamp.now(),
            'fromCardId': _selectedCardId,
            'type': 'expense',
            'description': 'Bill payment: ${_billerNameController.text.trim()}',
            'name': _billerNameController.text.trim(),
            'category': categoryName,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill paid successfully with $_selectedCardName'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          // Schedule notification for unpaid bill
          await NotificationService().scheduleBillNotification(
            billId: docRef.id,
            billerName: _billerNameController.text.trim(),
            amount: amount,
            categoryName: categoryName,
            dueDate: _dueDate!,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bill added successfully'),
              backgroundColor: Colors.teal,
            ),
          );
        }

        widget.onBillAdded?.call();
        Navigator.pop(context);
      } catch (e) {
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

  // Enhanced input decoration with consistent styling
  InputDecoration _buildInputDecoration(String labelText, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      filled: true,
      fillColor: const Color.fromRGBO(45, 45, 45, 1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  @override
  void dispose() {
    _billerNameController.dispose();

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
        elevation: 0,
        title: const Text(
          'Add New Bill',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'Saving your bill...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with icon
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.teal,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bill Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Fill in the details below to track your bill',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Basic Information Section
                const Text(
                  'Basic Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Biller Name Field
                TextFormField(
                  controller: _billerNameController,
                  decoration: _buildInputDecoration(
                    'Biller Name *',
                    suffixIcon: const Icon(Icons.business, color: Colors.white54, size: 20),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter biller name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),



                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  decoration: _buildInputDecoration(
                    'Description *',
                    suffixIcon: const Icon(Icons.description, color: Colors.white54, size: 20),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Financial Information Section
                const Text(
                  'Financial Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  decoration: _buildInputDecoration(
                    'Amount (RM) *',
                    suffixIcon: const Icon(Icons.attach_money, color: Colors.white54, size: 20),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    if (double.tryParse(value.trim()) == null || double.parse(value.trim()) <= 0) {
                      return 'Please enter a valid amount';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // Reload cards when amount changes to update insufficient balance warnings
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Due Date Field
                GestureDetector(
                  onTap: () => _selectDueDate(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(45, 45, 45, 1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey, width: 0.5),
                    ),
                    child: InputDecorator(
                      decoration: _buildInputDecoration(
                        'Due Date *',
                        suffixIcon: const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                      ),
                      child: Text(
                        _dueDate == null
                            ? 'Select due date'
                            : DateFormat('MMM dd, yyyy').format(_dueDate!),
                        style: TextStyle(
                          color: _dueDate == null ? Colors.white54 : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Payment Method Section
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Card Selection
                GestureDetector(
                  onTap: _showCardSelectionDialog,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(45, 45, 45, 1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _payWithCard ? Colors.teal : Colors.grey,
                        width: _payWithCard ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _payWithCard
                                ? Colors.teal.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.credit_card,
                            color: _payWithCard ? Colors.teal : Colors.white54,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _payWithCard && _selectedCardName != null
                                    ? _selectedCardName!
                                    : 'Select payment card',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_payWithCard && _selectedCardBalance > 0)
                                Text(
                                  'Balance: RM${_selectedCardBalance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              if (!_payWithCard)
                                Text(
                                  'Pay manually later',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          _payWithCard ? Icons.check_circle : Icons.arrow_forward_ios,
                          color: _payWithCard ? Colors.teal : Colors.white54,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_payWithCard && _selectedCardId != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.teal,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'This bill will be marked as paid immediately',
                            style: TextStyle(
                              color: Colors.teal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Category Section
                const Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color.fromRGBO(45, 45, 45, 1),
                    dropdownMenuTheme: DropdownMenuThemeData(
                      textStyle: const TextStyle(color: Colors.white),
                      menuStyle: MenuStyle(
                        backgroundColor: WidgetStateProperty.all(const Color.fromRGBO(45, 45, 45, 1)),
                        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
                        elevation: WidgetStateProperty.all(8.0),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    decoration: _buildInputDecoration(
                      'Category *',
                      suffixIcon: const Icon(Icons.category, color: Colors.white54, size: 20),
                    ),
                    value: _selectedCategory,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    dropdownColor: const Color.fromRGBO(45, 45, 45, 1),
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category['name'],
                        child: Text(
                          category['name']!,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        if (_selectedCategory != 'Other') {
                          _customCategoryController.clear();
                        }
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

                // Custom Category Field (conditional)
                if (_selectedCategory == 'Other') ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _customCategoryController,
                    decoration: _buildInputDecoration(
                      'Custom Category *',
                      suffixIcon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    validator: (value) {
                      if (_selectedCategory == 'Other' && (value == null || value.trim().isEmpty)) {
                        return 'Please enter custom category';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // Image Upload Section
                const Text(
                  'Bill Image (Optional)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload an image of your bill for reference',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Image Upload Container
                GestureDetector(
                  onTap: _isUploadingImage ? null : _pickImage,
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(45, 45, 45, 1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _billImage != null ? Colors.teal : Colors.grey.withOpacity(0.5),
                        width: _billImage != null ? 2 : 1,
                      ),
                    ),
                    child: _isUploadingImage
                        ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.teal),
                        SizedBox(height: 16),
                        Text(
                          'Uploading image...',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    )
                        : _billImage != null
                        ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _billImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Colors.teal,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Tap to add bill image',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'JPG, PNG • Max 5MB',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveBill,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _payWithCard ? Colors.green : Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: (_payWithCard ? Colors.green : Colors.teal).withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _payWithCard ? Icons.payment : Icons.save,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _payWithCard ? 'Pay Bill Now' : 'Save Bill',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}