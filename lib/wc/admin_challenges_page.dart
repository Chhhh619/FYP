import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminChallengesPage extends StatefulWidget {
  const AdminChallengesPage({super.key});

  @override
  _AdminChallengesPageState createState() => _AdminChallengesPageState();
}

class _AdminChallengesPageState extends State<AdminChallengesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _iconController = TextEditingController();
  final TextEditingController _targetValueController = TextEditingController();
  final TextEditingController _rewardPointsController = TextEditingController();
  final TextEditingController _badgeNameController = TextEditingController();
  final TextEditingController _badgeDescriptionController = TextEditingController();
  final TextEditingController _badgeIconController = TextEditingController();
  final TextEditingController _categoryNameController = TextEditingController(); // Changed from _categoryIdController

  String _selectedType = 'transaction_count';
  String _selectedPeriod = 'monthly';
  String _selectedComparison = 'greater_equal';
  bool _isActive = true;
  bool _hasBadgeReward = false;
  bool _isLoading = false;
  Set<String> _selectedChallengeIds = {};

  final List<String> _challengeTypes = [
    'transaction_count',
    'spending_limit',
    'category_spending',
    'savings_goal',
    'consecutive_days',
    'budget_adherence',
  ];

  final List<String> _periods = [
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];

  final List<String> _comparisonTypes = [
    'greater_equal',
    'less_equal',
    'equal',
  ];

  final Map<String, String> _typeDescriptions = {
    'transaction_count': 'Count of transactions recorded',
    'spending_limit': 'Total amount spent (expenses only)',
    'category_spending': 'Amount spent in specific category',
    'savings_goal': 'Net savings (income - expenses)',
    'consecutive_days': 'Days in a row with transactions',
    'budget_adherence': 'Percentage of budget adherence',
  };

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

  Future<void> _createChallenge() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final challengeData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'icon': _iconController.text.trim(),
        'type': _selectedType,
        'period': _selectedType == 'consecutive_days' ? 'daily' : _selectedPeriod,
        'targetValue': double.parse(_targetValueController.text),
        'comparisonType': _selectedComparison,
        'rewardPoints': int.parse(_rewardPointsController.text),
        'isActive': _isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
      };

      if (_selectedType == 'category_spending' &&
          _categoryNameController.text.isNotEmpty) {
        challengeData['categoryName'] = _categoryNameController.text.trim(); // Changed from categoryId
      }

      if (_hasBadgeReward &&
          _badgeNameController.text.isNotEmpty &&
          _badgeDescriptionController.text.isNotEmpty) {
        challengeData['rewardBadge'] = {
          'id': _badgeNameController.text.toLowerCase().replaceAll(' ', '_'),
          'name': _badgeNameController.text.trim(),
          'description': _badgeDescriptionController.text.trim(),
          'icon': _badgeIconController.text.trim().isNotEmpty
              ? _badgeIconController.text.trim()
              : '🏆',
        };
      }

      await _firestore.collection('challenges').add(challengeData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating challenge: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Title is required');
      return false;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showError('Description is required');
      return false;
    }
    if (_targetValueController.text.trim().isEmpty) {
      _showError('Target value is required');
      return false;
    }
    if (double.tryParse(_targetValueController.text) == null) {
      _showError('Target value must be a valid number');
      return false;
    }
    if (_rewardPointsController.text.trim().isEmpty) {
      _showError('Reward points is required');
      return false;
    }
    if (int.tryParse(_rewardPointsController.text) == null) {
      _showError('Reward points must be a valid integer');
      return false;
    }
    if (_selectedType == 'category_spending' &&
        _categoryNameController.text.trim().isEmpty) {
      _showError('Category name is required for category spending challenges');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _iconController.clear();
    _targetValueController.clear();
    _rewardPointsController.clear();
    _badgeNameController.clear();
    _badgeDescriptionController.clear();
    _badgeIconController.clear();
    _categoryNameController.clear();
    setState(() {
      _selectedType = 'transaction_count';
      _selectedPeriod = 'monthly';
      _selectedComparison = 'greater_equal';
      _isActive = true;
      _hasBadgeReward = false;
    });
  }

  Future<void> _toggleChallengeStatus(String challengeId, bool currentStatus) async {
    try {
      await _firestore.collection('challenges').doc(challengeId).update({
        'isActive': !currentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge ${!currentStatus ? "activated" : "deactivated"}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating challenge: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteChallenge(String challengeId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Delete Challenge', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
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
        await _firestore.collection('challenges').doc(challengeId).delete();
        setState(() {
          _selectedChallengeIds.remove(challengeId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting challenge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignChallengesToAllUsers() async {
    if (_selectedChallengeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one challenge to assign'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Assign Challenges to All Users', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to assign the selected challenges to all users?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Assign', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all users
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      int assignments = 0;

      // Fetch selected challenges data
      final challengesSnapshot = await _firestore
          .collection('challenges')
          .where(FieldPath.documentId, whereIn: _selectedChallengeIds.toList())
          .get();
      final challenges = Map.fromEntries(
        challengesSnapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
      );

      // Iterate through users
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        // Skip banned users or admins
        if (userDoc.data()['banned'] == true || userDoc.data()['isAdmin'] == true) {
          continue;
        }

        for (var challengeId in _selectedChallengeIds) {
          final challengeData = challenges[challengeId];
          if (challengeData == null || challengeData['isActive'] != true) {
            continue; // Skip inactive or invalid challenges
          }

          // Check if user already has the challenge
          final progressRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('challengeProgress')
              .doc(challengeId);
          final existingProgress = await progressRef.get();

          if (!existingProgress.exists) {
            batch.set(progressRef, {
              'progress': 0,
              'isCompleted': false,
              'isClaimed': false,
              'assignedAt': FieldValue.serverTimestamp(),
              'assignedBy': _auth.currentUser?.uid,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            assignments++;
          }
        }
      }

      await batch.commit();
      setState(() {
        _selectedChallengeIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assigned challenges to $assignments user-challenge pairs'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning challenges: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
          'Manage Challenges',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Create Challenge Form
            Card(
              color: const Color.fromRGBO(33, 35, 34, 1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Challenge',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildFormField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'e.g., Transaction Master',
                      required: true,
                    ),

                    _buildFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Describe what users need to do',
                      maxLines: 2,
                      required: true,
                    ),

                    _buildFormField(
                      controller: _iconController,
                      label: 'Icon',
                      hint: 'e.g., 🎯 📝 💰',
                    ),

                    _buildDropdownField<String>(
                      label: 'Challenge Type',
                      value: _selectedType,
                      items: _challengeTypes,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                      itemLabel: (type) => type.replaceAll('_', ' ').toUpperCase(),
                    ),

                    if (_selectedType != 'consecutive_days')
                      _buildDropdownField<String>(
                        label: 'Period',
                        value: _selectedPeriod,
                        items: _periods,
                        onChanged: (value) {
                          setState(() {
                            _selectedPeriod = value!;
                          });
                        },
                        itemLabel: (period) => period.toUpperCase(),
                      ),

                    _buildFormField(
                      controller: _targetValueController,
                      label: 'Target Value',
                      hint: 'The goal number to achieve',
                      keyboardType: TextInputType.number,
                      required: true,
                    ),

                    _buildDropdownField<String>(
                      label: 'Comparison Type',
                      value: _selectedComparison,
                      items: _comparisonTypes,
                      onChanged: (value) {
                        setState(() {
                          _selectedComparison = value!;
                        });
                      },
                      itemLabel: (comp) {
                        switch (comp) {
                          case 'greater_equal':
                            return 'Greater than or equal to';
                          case 'less_equal':
                            return 'Less than or equal to';
                          case 'equal':
                            return 'Equal to';
                          default:
                            return comp;
                        }
                      },
                    ),

                    if (_selectedType == 'category_spending')
                      _buildFormField(
                        controller: _categoryNameController,
                        label: 'Category Name',
                        hint: 'e.g., dining',
                        required: true,
                      ),

                    _buildFormField(
                      controller: _rewardPointsController,
                      label: 'Reward Points',
                      keyboardType: TextInputType.number,
                      required: true,
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _hasBadgeReward,
                          onChanged: (value) {
                            setState(() {
                              _hasBadgeReward = value ?? false;
                            });
                          },
                          activeColor: Colors.teal,
                        ),
                        const Text(
                          'Include Badge Reward',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    if (_hasBadgeReward) ...[
                      _buildFormField(
                        controller: _badgeNameController,
                        label: 'Badge Name',
                        hint: 'e.g., Transaction Master',
                      ),
                      _buildFormField(
                        controller: _badgeDescriptionController,
                        label: 'Badge Description',
                        hint: 'What this badge represents',
                      ),
                      _buildFormField(
                        controller: _badgeIconController,
                        label: 'Badge Icon',
                        hint: 'e.g., 🏆 ⭐ 🎖️',
                      ),
                    ],

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
                          'Active',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    if (_typeDescriptions.containsKey(_selectedType))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Info: ${_typeDescriptions[_selectedType]}',
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createChallenge,
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
                          'Create Challenge',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Existing Challenges List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Existing Challenges',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedChallengeIds.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _assignChallengesToAllUsers,
                    icon: const Icon(Icons.group_add, color: Colors.white),
                    label: const Text('Assign to All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('challenges')
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
                  return const Center(
                    child: Text(
                      'No challenges created yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final challenge = doc.data() as Map<String, dynamic>;
                    final challengeId = doc.id;

                    return Card(
                      color: const Color.fromRGBO(33, 35, 34, 1),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _selectedChallengeIds.contains(challengeId),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedChallengeIds.add(challengeId);
                                  } else {
                                    _selectedChallengeIds.remove(challengeId);
                                  }
                                });
                              },
                              activeColor: Colors.teal,
                            ),
                            CircleAvatar(
                              backgroundColor: challenge['isActive'] == true
                                  ? Colors.green
                                  : Colors.grey,
                              child: Text(
                                challenge['icon'] ?? '🎯',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          challenge['title'] ?? 'Untitled',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge['description'] ?? '',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type: ${challenge['type']?.toString().replaceAll('_', ' ') ?? 'Unknown'} | '
                                  'Target: ${challenge['targetValue']} | '
                                  'Points: ${challenge['rewardPoints']}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            if (challenge['categoryName'] != null) // Changed from categoryId
                              Text(
                                'Category: ${challenge['categoryName']}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            if (challenge['createdAt'] != null)
                              Text(
                                'Created: ${DateFormat('MMM dd, yyyy').format((challenge['createdAt'] as Timestamp).toDate())}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                challenge['isActive'] == true ? Icons.pause : Icons.play_arrow,
                                color: challenge['isActive'] == true ? Colors.orange : Colors.green,
                              ),
                              onPressed: () => _toggleChallengeStatus(challengeId, challenge['isActive'] ?? false),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteChallenge(challengeId, challenge['title'] ?? 'Untitled'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
    _titleController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _targetValueController.dispose();
    _rewardPointsController.dispose();
    _badgeNameController.dispose();
    _badgeDescriptionController.dispose();
    _badgeIconController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }
}