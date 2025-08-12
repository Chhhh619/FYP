import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPointShopPage extends StatefulWidget {
  const AdminPointShopPage({super.key});

  @override
  _AdminPointShopPageState createState() => _AdminPointShopPageState();
}

class _AdminPointShopPageState extends State<AdminPointShopPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _iconController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _badgeIdController = TextEditingController();

  String _selectedCategory = 'common';
  String _selectedRarity = 'common';
  bool _isActive = true;
  bool _limitedStock = false;
  bool _isLoading = false;

  final List<String> _categories = ['exclusive', 'seasonal', 'rare', 'common'];
  final List<String> _rarities = ['legendary', 'epic', 'rare', 'uncommon', 'common'];

  final List<Map<String, dynamic>> _badgeTemplates = [
    {
      'name': 'Gold Saver',
      'description': 'Elite savings champion',
      'icon': '🏆',
      'price': 500,
      'category': 'exclusive',
      'rarity': 'legendary',
    },
    {
      'name': 'Budget Master',
      'description': 'Master of budget management',
      'icon': '💎',
      'price': 300,
      'category': 'rare',
      'rarity': 'epic',
    },
    {
      'name': 'Star Performer',
      'description': 'Consistent financial excellence',
      'icon': '⭐',
      'price': 200,
      'category': 'common',
      'rarity': 'rare',
    },
    {
      'name': 'Money Wizard',
      'description': 'Financial wisdom unlocked',
      'icon': '🧙',
      'price': 400,
      'category': 'exclusive',
      'rarity': 'epic',
    },
    {
      'name': 'Savings Hero',
      'description': 'Heroic savings achievements',
      'icon': '🦸',
      'price': 150,
      'category': 'common',
      'rarity': 'uncommon',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showAccessDenied();
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc.data()?['isAdmin'] != true) {
        _showAccessDenied();
      }
    } catch (e) {
      _showAccessDenied();
    }
  }

  void _showAccessDenied() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Access denied: Admin only')),
    );
    Navigator.pop(context);
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _nameController.text = template['name'];
      _descriptionController.text = template['description'];
      _iconController.text = template['icon'];
      _priceController.text = template['price'].toString();
      _selectedCategory = template['category'];
      _selectedRarity = template['rarity'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Template applied! Customize as needed.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _addShopItem() async {
    if (_nameController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final itemData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'icon': _iconController.text.trim().isEmpty ? '🎖️' : _iconController.text.trim(),
        'badgeId': _badgeIdController.text.trim().isEmpty
            ? _nameController.text.toLowerCase().replaceAll(' ', '_')
            : _badgeIdController.text.trim(),
        'price': int.parse(_priceController.text),
        'category': _selectedCategory,
        'rarity': _selectedRarity,
        'isActive': _isActive,
        'limitedStock': _limitedStock,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
      };

      if (_limitedStock && _stockController.text.isNotEmpty) {
        final stock = int.parse(_stockController.text);
        itemData['stock'] = stock;
        itemData['initialStock'] = stock;
      }

      await _firestore.collection('pointShop').add(itemData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Badge added to shop successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _nameController.clear();
      _descriptionController.clear();
      _iconController.clear();
      _priceController.clear();
      _stockController.clear();
      _badgeIdController.clear();
      setState(() {
        _selectedCategory = 'common';
        _selectedRarity = 'common';
        _limitedStock = false;
        _isActive = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleItemStatus(String itemId, bool currentStatus) async {
    try {
      await _firestore.collection('pointShop').doc(itemId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Badge ${!currentStatus ? "activated" : "deactivated"}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteItem(String itemId, String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Delete Badge', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "$itemName"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
        await _firestore.collection('pointShop').doc(itemId).delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Badge deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restockItem(String itemId, String itemName, int currentStock) async {
    final TextEditingController restockController = TextEditingController();

    final newStock = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: Text('Restock $itemName', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current stock: $currentStock',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: restockController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Add stock quantity',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final quantity = int.tryParse(restockController.text);
              Navigator.pop(context, quantity);
            },
            child: const Text('Add Stock', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );

    if (newStock != null && newStock > 0) {
      try {
        await _firestore.collection('pointShop').doc(itemId).update({
          'stock': FieldValue.increment(newStock),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $newStock stock to $itemName'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restocking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.grey[400]),
          hintStyle: TextStyle(color: Colors.grey[600]),
          filled: true,
          fillColor: const Color.fromRGBO(40, 42, 41, 1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[600]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[600]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    String Function(T)? itemLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              itemLabel != null ? itemLabel(item) : item.toString(),
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: const Color.fromRGBO(40, 42, 41, 1),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          filled: true,
          fillColor: const Color.fromRGBO(40, 42, 41, 1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[600]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[600]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return Colors.orange;
      case 'epic':
        return Colors.purple;
      case 'rare':
        return Colors.blue;
      case 'uncommon':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Point Shop',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Templates Section
            Card(
              color: const Color.fromRGBO(33, 35, 34, 1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Templates',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a template to quickly add premium badges',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _badgeTemplates.length,
                        itemBuilder: (context, index) {
                          final template = _badgeTemplates[index];
                          return Card(
                            color: const Color.fromRGBO(40, 42, 41, 1),
                            child: InkWell(
                              onTap: () => _applyTemplate(template),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 150,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      template['icon'],
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      template['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Add Item Form
            Card(
              color: const Color.fromRGBO(33, 35, 34, 1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Shop Item',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildFormField(
                      controller: _nameController,
                      label: 'Badge Name',
                      hint: 'e.g., Gold Saver',
                      required: true,
                    ),

                    _buildFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Description of the badge',
                      maxLines: 2,
                      required: true,
                    ),

                    _buildFormField(
                      controller: _iconController,
                      label: 'Icon (Emoji)',
                      hint: 'e.g., 💎 🏆 ⭐',
                    ),

                    _buildFormField(
                      controller: _badgeIdController,
                      label: 'Badge ID (Optional)',
                      hint: 'Unique identifier (auto-generated if empty)',
                    ),

                    _buildFormField(
                      controller: _priceController,
                      label: 'Price (Points)',
                      hint: 'How many points to purchase',
                      keyboardType: TextInputType.number,
                      required: true,
                    ),

                    _buildDropdownField<String>(
                      label: 'Category',
                      value: _selectedCategory,
                      items: _categories,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                      itemLabel: (cat) => cat.toUpperCase(),
                    ),

                    _buildDropdownField<String>(
                      label: 'Rarity',
                      value: _selectedRarity,
                      items: _rarities,
                      onChanged: (value) {
                        setState(() {
                          _selectedRarity = value!;
                        });
                      },
                      itemLabel: (rarity) => rarity.toUpperCase(),
                    ),

                    Row(
                      children: [
                        Checkbox(
                          value: _limitedStock,
                          onChanged: (value) {
                            setState(() {
                              _limitedStock = value ?? false;
                            });
                          },
                          activeColor: Colors.teal,
                        ),
                        const Text(
                          'Limited Stock',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    if (_limitedStock)
                      _buildFormField(
                        controller: _stockController,
                        label: 'Initial Stock',
                        hint: 'Number of items available',
                        keyboardType: TextInputType.number,
                      ),

                    Row(
                      children: [
                        Checkbox(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value ?? true;
                            });
                          },
                          activeColor: Colors.teal,
                        ),
                        const Text(
                          'Active (Visible in shop)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addShopItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Add to Shop',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Existing Items List
            const Text(
              'Shop Items',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('pointShop')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Card(
                    color: const Color.fromRGBO(33, 35, 34, 1),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No shop items yet',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use the templates above to get started!',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final items = snapshot.data!.docs;

                // Group items by category
                final Map<String, List<QueryDocumentSnapshot>> groupedItems = {};
                for (var doc in items) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'] ?? 'uncategorized';
                  if (!groupedItems.containsKey(category)) {
                    groupedItems[category] = [];
                  }
                  groupedItems[category]!.add(doc);
                }

                return Column(
                  children: groupedItems.entries.map((entry) {
                    final category = entry.key;
                    final categoryItems = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                category.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${categoryItems.length}',
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...categoryItems.map((doc) {
                          final item = doc.data() as Map<String, dynamic>;
                          final itemId = doc.id;
                          final rarity = item['rarity'] ?? 'common';
                          final rarityColor = _getRarityColor(rarity);

                          return Card(
                            color: const Color.fromRGBO(33, 35, 34, 1),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: rarityColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(color: rarityColor),
                                ),
                                child: Center(
                                  child: Text(
                                    item['icon'] ?? '🎖️',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['name'] ?? 'Unnamed',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (item['isActive'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['description'] ?? '',
                                    style: const TextStyle(color: Colors.grey),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      _buildInfoChip(
                                        '${item['price']} pts',
                                        Icons.stars,
                                        Colors.yellow,
                                      ),
                                      _buildInfoChip(
                                        rarity.toUpperCase(),
                                        Icons.diamond,
                                        rarityColor,
                                      ),
                                      if (item['limitedStock'] == true)
                                        _buildInfoChip(
                                          'Stock: ${item['stock'] ?? 0}',
                                          Icons.inventory,
                                          item['stock'] > 0 ? Colors.orange : Colors.red,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item['limitedStock'] == true)
                                    IconButton(
                                      icon: const Icon(Icons.add_box, color: Colors.blue),
                                      onPressed: () => _restockItem(
                                        itemId,
                                        item['name'] ?? 'Item',
                                        item['stock'] ?? 0,
                                      ),
                                      tooltip: 'Restock',
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      item['isActive'] == true ? Icons.pause : Icons.play_arrow,
                                      color: item['isActive'] == true ? Colors.orange : Colors.green,
                                    ),
                                    onPressed: () => _toggleItemStatus(itemId, item['isActive'] ?? false),
                                    tooltip: item['isActive'] == true ? 'Deactivate' : 'Activate',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteItem(itemId, item['name'] ?? 'Item'),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _badgeIdController.dispose();
    super.dispose();
  }
}