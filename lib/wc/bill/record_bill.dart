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
  final _accountNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _customCategoryController = TextEditingController();
  DateTime? _dueDate;
  String? _selectedCategory;
  bool _isLoading = false;
  File? _billImage;
  String? _billImageUrl;
  bool _isUploadingImage = false;

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

        final billData = {
          'userId': widget.userId,
          'billerName': _billerNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'description': _descriptionController.text.trim(),
          'amount': amount,
          'categoryName': categoryName,
          'dueDate': Timestamp.fromDate(_dueDate!),
          'status': 'pending',
          'createdAt': Timestamp.now(),
          'paidAt': null,
          if (_billImageUrl != null) 'billImageUrl': _billImageUrl,
        };

        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('bills')
            .add(billData);

        // Schedule notification for the bill
        await NotificationService().scheduleBillNotification(
          billId: docRef.id,
          billerName: _billerNameController.text.trim(),
          amount: amount,
          categoryName: categoryName,
          dueDate: _dueDate!,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill added successfully')),
        );
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

                // Account Number Field
                TextFormField(
                  controller: _accountNumberController,
                  decoration: _buildInputDecoration(
                    'Account Number *',
                    suffixIcon: const Icon(Icons.numbers, color: Colors.white54, size: 20),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter account number';
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
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.teal.withOpacity(0.5),
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
                        : const Text(
                      'Save Bill',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
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