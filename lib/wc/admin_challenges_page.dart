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

  String _selectedType = 'transaction_count';
  String _selectedPeriod = 'monthly';
  String _selectedComparison = 'greater_equal';
  String? _selectedDefaultCategory;
  bool _isActive = true;
  bool _hasBadgeReward = false;
  bool _isLoading = false;
  Set<String> _selectedChallengeIds = {};
  List<Map<String, dynamic>> _defaultCategories = [];
  bool _selectAll = false; // Add select all state

  // Simplified challenge types with clearer descriptions
  final List<String> _challengeTypes = [
    'transaction_count',
    'spending_limit',
    'category_spending',
    'savings_goal',
    'consecutive_days',
  ];

  final List<String> _periods = [
    'daily',
    'weekly',
    'monthly',
  ];

  final List<String> _comparisonTypes = [
    'greater_equal',
    'less_equal',
  ];

  // descriptions and examples for each challenge type
  final Map<String, Map<String, dynamic>> _challengeInfo = {
    'transaction_count': {
      'description': 'Number of transactions recorded',
      'example': 'Record at least 10 transactions this month',
      'icon': '📊',
      'targetHint': 'Number of transactions (e.g., 10)',
      'defaultTarget': 10,
      'defaultPoints': 50,
    },
    'spending_limit': {
      'description': 'Total amount spent (expenses only)',
      'example': 'Keep spending under RM500 this month',
      'icon': '💰',
      'targetHint': 'Maximum spending amount (e.g., 500)',
      'defaultTarget': 500,
      'defaultPoints': 100,
    },
    'category_spending': {
      'description': 'Amount spent in a specific category',
      'example': 'Spend less than RM100 on dining this week',
      'icon': '🍔',
      'targetHint': 'Spending limit for category (e.g., 100)',
      'defaultTarget': 100,
      'defaultPoints': 75,
    },
    'savings_goal': {
      'description': 'Net savings (income minus expenses)',
      'example': 'Save at least RM200 this month',
      'icon': '💎',
      'targetHint': 'Savings target amount (e.g., 200)',
      'defaultTarget': 200,
      'defaultPoints': 150,
    },
    'consecutive_days': {
      'description': 'Track expenses for consecutive days (no time limit)',
      'example': 'Record transactions for 7 consecutive days',
      'icon': '📅',
      'targetHint': 'Number of consecutive days needed (e.g., 7)',
      'defaultTarget': 7,
      'defaultPoints': 100,
    },
  };

  // Predefined challenge templates for quick creation
  final List<Map<String, dynamic>> _challengeTemplates = [
    {
      'title': 'Beginner Tracker',
      'description': 'Start your journey by recording 5 transactions',
      'type': 'transaction_count',
      'targetValue': 5,
      'period': 'monthly',
      'rewardPoints': 25,
      'icon': '🌟',
    },
    {
      'title': 'Budget Master',
      'description': 'Keep your monthly spending under RM1000',
      'type': 'spending_limit',
      'targetValue': 1000,
      'period': 'monthly',
      'rewardPoints': 100,
      'icon': '💵',
    },
    {
      'title': 'Dining Budget',
      'description': 'Spend less than RM200 on dining this month',
      'type': 'category_spending',
      'targetValue': 200,
      'period': 'monthly',
      'rewardPoints': 50,
      'icon': '🍕',
      'categoryName': 'Dining',
    },
    {
      'title': 'Weekly Saver',
      'description': 'Save at least RM50 this week',
      'type': 'savings_goal',
      'targetValue': 50,
      'period': 'weekly',
      'rewardPoints': 30,
      'icon': '💸',
    },
    {
      'title': 'Consistency Champion',
      'description': 'Track expenses for 7 consecutive days',
      'type': 'consecutive_days',
      'targetValue': 7,
      'period': 'daily',
      'rewardPoints': 75,
      'icon': '🏆',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadDefaultCategories();
  }

  Future<void> _loadDefaultCategories() async {
    try {
      final snapshot = await _firestore
          .collection('categories')
          .where('userId', isEqualTo: '')
          .get();

      setState(() {
        _defaultCategories = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'],
            'icon': data['icon'],
            'type': data['type'],
          };
        }).toList();

        _defaultCategories.sort((a, b) =>
            (a['name'] as String).compareTo(b['name'] as String));
      });

      print('Loaded ${_defaultCategories.length} default categories');
    } catch (e) {
      print('Error loading default categories: $e');
    }
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
      _titleController.text = template['title'];
      _descriptionController.text = template['description'];
      _iconController.text = template['icon'];
      _selectedType = template['type'];
      _targetValueController.text = template['targetValue'].toString();
      _selectedPeriod = template['period'];
      _rewardPointsController.text = template['rewardPoints'].toString();

      if (template['categoryName'] != null) {
        final category = _defaultCategories.firstWhere(
              (cat) => cat['name'].toLowerCase() == template['categoryName'].toLowerCase(),
          orElse: () => _defaultCategories.first,
        );
        _selectedDefaultCategory = category['name'];
      }

      if (template['type'] == 'spending_limit' || template['type'] == 'category_spending') {
        _selectedComparison = 'less_equal';
      } else {
        _selectedComparison = 'greater_equal';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Template applied! Customize as needed.'),
        backgroundColor: Colors.green,
      ),
    );
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
        'icon': _iconController.text.trim().isEmpty ? '🎯' : _iconController.text.trim(),
        'type': _selectedType,
        'period': _selectedType == 'consecutive_days' ? 'daily' : _selectedPeriod,
        'targetValue': double.parse(_targetValueController.text),
        'rewardPoints': int.parse(_rewardPointsController.text),
        'isActive': _isActive,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
      };

      // Only add comparison type for non-consecutive days challenges
      if (_selectedType != 'consecutive_days') {
        challengeData['comparisonType'] = _selectedComparison;
      } else {
        // For consecutive days, always use greater_equal
        challengeData['comparisonType'] = 'greater_equal';
      }

      if (_selectedType == 'category_spending' && _selectedDefaultCategory != null) {
        challengeData['categoryName'] = _selectedDefaultCategory;
        challengeData['isDefaultCategory'] = true;
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

      // Create the challenge first
      final challengeRef = await _firestore.collection('challenges').add(challengeData);
      final challengeId = challengeRef.id;

      // If the challenge is active, automatically assign it to all users
      if (_isActive) {
        await _assignChallengeToAllUsers(challengeId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isActive
              ? 'Challenge created and assigned to all users!'
              : 'Challenge created successfully!'),
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

  // Assign challenge to all users
  Future<void> _assignChallengeToAllUsers(String challengeId) async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      int assignments = 0;
      final assignmentTime = FieldValue.serverTimestamp();

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();

        // Skip banned users and admins
        if (userData['banned'] == true || userData['isAdmin'] == true) {
          continue;
        }

        final progressRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('challengeProgress')
            .doc(challengeId);

        // Check if user already has this challenge assigned
        final existingProgress = await progressRef.get();
        if (!existingProgress.exists) {
          batch.set(progressRef, {
            'progress': 0,
            'isCompleted': false,
            'isClaimed': false,
            'assignedAt': assignmentTime, // This is the key - tracks when user got the challenge
            'assignedBy': _auth.currentUser?.uid,
            'lastUpdated': assignmentTime,
          });
          assignments++;
        }
      }

      if (assignments > 0) {
        await batch.commit();
        print('Assigned challenge $challengeId to $assignments users');
      }
    } catch (e) {
      print('Error assigning challenge to all users: $e');
      throw e; // Re-throw to handle in calling method
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
    if (_selectedType == 'category_spending' && _selectedDefaultCategory == null) {
      _showError('Please select a category for category spending challenges');
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
    setState(() {
      _selectedType = 'transaction_count';
      _selectedPeriod = 'monthly';
      _selectedComparison = 'greater_equal';
      _selectedDefaultCategory = null;
      _isActive = true;
      _hasBadgeReward = false;
    });
  }

  // active|deactive challenges
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

  // method to delete selected challenges
  Future<void> _deleteSelectedChallenges() async {
    if (_selectedChallengeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one challenge to delete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Delete Selected Challenges', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${_selectedChallengeIds.length} selected challenge(s)? This action cannot be undone.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final batch = _firestore.batch();

      for (var challengeId in _selectedChallengeIds) {
        final docRef = _firestore.collection('challenges').doc(challengeId);
        batch.delete(docRef);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${_selectedChallengeIds.length} challenge(s) successfully'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _selectedChallengeIds.clear();
        _selectAll = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting challenges: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to toggle select all
  void _toggleSelectAll(List<QueryDocumentSnapshot> allChallenges) {
    setState(() {
      if (_selectAll) {
        _selectedChallengeIds.clear();
        _selectAll = false;
      } else {
        _selectedChallengeIds = Set.from(allChallenges.map((doc) => doc.id));
        _selectAll = true;
      }
    });
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
        content: Text(
          'Are you sure you want to assign the selected challenges to all users?\n\nNote: Users will start tracking progress from the moment they receive these challenges, not from historical data.',
          style: const TextStyle(color: Colors.white),
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
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      int assignments = 0;
      final assignmentTime = FieldValue.serverTimestamp();

      final challengesSnapshot = await _firestore
          .collection('challenges')
          .where(FieldPath.documentId, whereIn: _selectedChallengeIds.toList())
          .get();
      final challenges = Map.fromEntries(
        challengesSnapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
      );

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();

        // Skip banned users and admins
        if (userData['banned'] == true || userData['isAdmin'] == true) {
          continue;
        }

        for (var challengeId in _selectedChallengeIds) {
          final challengeData = challenges[challengeId];
          if (challengeData == null || challengeData['isActive'] != true) {
            continue;
          }

          final progressRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('challengeProgress')
              .doc(challengeId);

          // Check if user already has this challenge
          final existingProgress = await progressRef.get();
          if (!existingProgress.exists) {
            batch.set(progressRef, {
              'progress': 0,
              'isCompleted': false,
              'isClaimed': false,
              'assignedAt': assignmentTime, // Critical: This marks when tracking starts
              'assignedBy': _auth.currentUser?.uid,
              'lastUpdated': assignmentTime,
            });
            assignments++;
          } else {
            // If already exists but no assignedAt, update it
            final existingData = existingProgress.data();
            if (existingData != null && existingData['assignedAt'] == null) {
              batch.update(progressRef, {
                'assignedAt': assignmentTime,
                'assignedBy': _auth.currentUser?.uid,
                'lastUpdated': assignmentTime,
              });
              assignments++;
            }
          }
        }
      }

      if (assignments > 0) {
        await batch.commit();
      }

      setState(() {
        _selectedChallengeIds.clear();
        _selectAll = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(assignments > 0
              ? 'Assigned challenges to $assignments user-challenge pairs'
              : 'No new assignments made (users already have these challenges)'),
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
            // Challenge Templates Section
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
                      'Select a template to quickly create common challenges',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _challengeTemplates.length,
                        itemBuilder: (context, index) {
                          final template = _challengeTemplates[index];
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      template['icon'],
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(height: 8),
                                    Flexible(
                                      child: Text(
                                        template['title'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                      hint: 'e.g., Budget Master',
                      required: true,
                    ),

                    _buildFormField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Clear description of what users need to do',
                      maxLines: 2,
                      required: true,
                    ),

                    _buildFormField(
                      controller: _iconController,
                      label: 'Icon (Emoji)',
                      hint: 'e.g., 🎯 📝 💰',
                    ),

                    _buildDropdownField<String>(
                      label: 'Challenge Type',
                      value: _selectedType,
                      items: _challengeTypes,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                          final info = _challengeInfo[value];
                          if (info != null) {
                            _targetValueController.text = info['defaultTarget'].toString();
                            _rewardPointsController.text = info['defaultPoints'].toString();
                            _iconController.text = info['icon'];

                            if (value == 'spending_limit' || value == 'category_spending') {
                              _selectedComparison = 'less_equal';
                            } else {
                              _selectedComparison = 'greater_equal';
                            }
                          }
                        });
                      },
                      itemLabel: (type) => type.replaceAll('_', ' ').toUpperCase(),
                    ),

                    if (_challengeInfo.containsKey(_selectedType))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _challengeInfo[_selectedType]!['description'],
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Example: ${_challengeInfo[_selectedType]!['example']}',
                              style: const TextStyle(color: Colors.blue, fontSize: 11),
                            ),
                          ],
                        ),
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

                    if (_selectedType == 'category_spending')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: DropdownButtonFormField<String>(
                          value: _selectedDefaultCategory,
                          hint: const Text(
                            'Select Default Category *',
                            style: TextStyle(color: Colors.grey),
                          ),
                          dropdownColor: const Color.fromRGBO(40, 42, 41, 1),
                          decoration: InputDecoration(
                            labelText: 'Category',
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
                          items: _defaultCategories
                              .where((cat) => cat['type'] == 'expense')
                              .map((category) {
                            return DropdownMenuItem<String>(
                              value: category['name'],
                              child: Row(
                                children: [
                                  Text(
                                    category['icon'] ?? '💰',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    category['name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDefaultCategory = value;
                            });
                          },
                        ),
                      ),

                    _buildFormField(
                      controller: _targetValueController,
                      label: 'Target Value',
                      hint: _challengeInfo[_selectedType]?['targetHint'] ?? 'The goal number',
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
                            return 'At least (≥)';
                          case 'less_equal':
                            return 'At most (≤)';
                          default:
                            return comp;
                        }
                      },
                    ),

                    _buildFormField(
                      controller: _rewardPointsController,
                      label: 'Reward Points',
                      hint: 'Points users will earn',
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
                        hint: 'e.g., Budget Master',
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
                          'Active (Users can see this challenge)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                const Text(
                  'Existing Challenges',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Action buttons row (moved below title for better layout)
                if (_selectedChallengeIds.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _deleteSelectedChallenges,
                          icon: const Icon(Icons.delete_sweep, size: 20),
                          label: Text('Delete (${_selectedChallengeIds.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _assignChallengesToAllUsers,
                          icon: const Icon(Icons.group_add, size: 20),
                          label: Text('Assign (${_selectedChallengeIds.length})'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
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
                  return Card(
                    color: const Color.fromRGBO(33, 35, 34, 1),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No challenges created yet',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use the templates above to get started quickly!',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final challenges = snapshot.data!.docs;
                final Map<String, List<QueryDocumentSnapshot>> groupedChallenges = {};

                for (var doc in challenges) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] ?? 'other';
                  if (!groupedChallenges.containsKey(type)) {
                    groupedChallenges[type] = [];
                  }
                  groupedChallenges[type]!.add(doc);
                }

                // Add Select All checkbox when there are challenges
                return Column(
                  children: [
                    if (challenges.isNotEmpty)
                      Card(
                        color: const Color.fromRGBO(33, 35, 34, 1),
                        child: CheckboxListTile(
                          title: Text(
                            'Select All (${challenges.length} challenges)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          value: _selectAll && _selectedChallengeIds.length == challenges.length,
                          onChanged: (value) => _toggleSelectAll(challenges),
                          activeColor: Colors.teal,
                          checkColor: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ...groupedChallenges.entries.map((entry) {
                      final type = entry.key;
                      final typeChallenges = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  _challengeInfo[type]?['icon'] ?? '🎯',
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  type.replaceAll('_', ' ').toUpperCase(),
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
                                    '${typeChallenges.length}',
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
                          ...typeChallenges.map((doc) {
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
                                            _selectAll = false;
                                          }
                                        });
                                      },
                                      activeColor: Colors.teal,
                                    ),
                                    CircleAvatar(
                                      backgroundColor: challenge['isActive'] == true
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.2),
                                      child: Text(
                                        challenge['icon'] ?? '🎯',
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        challenge['title'] ?? 'Untitled',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (challenge['isActive'] == true)
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
                                      challenge['description'] ?? '',
                                      style: const TextStyle(color: Colors.grey),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        _buildInfoChip(
                                          'Target: ${challenge['targetValue']}',
                                          Icons.flag,
                                        ),
                                        _buildInfoChip(
                                          '${challenge['rewardPoints']} pts',
                                          Icons.stars,
                                        ),
                                        _buildInfoChip(
                                          challenge['period'] ?? 'N/A',
                                          Icons.schedule,
                                        ),
                                        if (challenge['categoryName'] != null)
                                          _buildInfoChip(
                                            challenge['categoryName'],
                                            Icons.category,
                                          ),
                                        if (challenge['rewardBadge'] != null)
                                          _buildInfoChip(
                                            'Badge',
                                            Icons.emoji_events,
                                          ),
                                      ],
                                    ),
                                    if (challenge['createdAt'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Created: ${DateFormat('MMM dd, yyyy').format((challenge['createdAt'] as Timestamp).toDate())}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                                        ),
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
                                      tooltip: challenge['isActive'] == true ? 'Deactivate' : 'Activate',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteChallenge(challengeId, challenge['title'] ?? 'Untitled'),
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
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
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
    super.dispose();
  }
}