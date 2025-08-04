import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/favourite_tips.dart';
import 'package:fyp/ch/settings.dart';
import 'package:intl/intl.dart';

class Tip {
  final String id;
  final String title;
  final String description;
  final String category;

  Tip({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
  });

  factory Tip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tip(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
    );
  }
}

class TipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Tip>> getTips() {
    return _firestore
        .collection('tips')
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => Tip.fromFirestore(doc)).toList());
  }

  Future<Map<String, double>> getSpendingInsights(
      String userId, DateTime startDate, DateTime endDate) async {
    final transactionSnapshot = await _firestore
        .collection('transactions')
        .where('userid', isEqualTo: userId)
        .where('timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();
    print('Transactions found: ${transactionSnapshot.docs.length}');

    final spending = <String, double>{};
    for (var doc in transactionSnapshot.docs) {
      final data = doc.data();
      final categoryRef = data['category'] as DocumentReference;
      final categorySnapshot = await categoryRef.get();
      final categoryName = categorySnapshot.get('name') as String? ?? 'unknown';
      final amount = (data['amount'] is int)
          ? (data['amount'] as int).toDouble()
          : (data['amount'] as double? ?? 0.0);
      print(
          'Transaction: ID=${doc.id}, Category=$categoryName, Amount=$amount');
      if (categoryName != 'unknown' && data['type'] == 'expense') {
        spending[categoryName.toLowerCase()] =
            (spending[categoryName.toLowerCase()] ?? 0.0) + amount.abs();
      }
    }
    print('Spending insights: $spending');
    return spending;
  }

  Future<void> markTipFeedback(
      String tipId, bool isHelpful, bool isIrrelevant) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tips_feedback')
          .doc(tipId)
          .set({
        'tipId': tipId,
        'isHelpful': isHelpful,
        'isIrrelevant': isIrrelevant,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update tip feedback: $e');
    }
  }

  Stream<Map<String, Map<String, bool>>> getTipFeedback(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('tips_feedback')
        .snapshots()
        .map((snapshot) {
      final feedback = <String, Map<String, bool>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        feedback[doc.id] = {
          'isHelpful': data['isHelpful'] ?? false,
          'isIrrelevant': data['isIrrelevant'] ?? false,
        };
      }
      return feedback;
    });
  }

  Future<int> getEngagedTipsCount(String userId, Set<String> currentTipIds) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('tips_feedback')
        .get();

    return snapshot.docs
        .where((doc) => currentTipIds.contains(doc.id))
        .length;
  }
}

class FinancialTipsScreen extends StatefulWidget {
  const FinancialTipsScreen({super.key});

  @override
  _FinancialTipsScreenState createState() => _FinancialTipsScreenState();
}

class _FinancialTipsScreenState extends State<FinancialTipsScreen> {
  final TipService _tipService = TipService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _selectedIndex = 1; // Align with "Trending" tab
  int _totalTips = 0;
  int _engagedTips = 0;
  Set<String> _currentTipIds = {};

  @override
  void initState() {
    super.initState();
    _loadTipStats();

    // Add listener for tip changes
    _tipService.getTips().listen((tips) {
      setState(() {
        _currentTipIds = tips.map((tip) => tip.id).toSet();
      });
      _loadTipStats();
    });
  }

  Future<void> _loadTipStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for tip stats');
      return;
    }

    try {
      // Get all current tips
      final tipSnapshot = await _tipService.getTips().first;
      final currentTipIds = tipSnapshot.map((tip) => tip.id).toSet();

      // Get all engagements
      final engagementSnapshot = await _tipService.getTipFeedback(userId).first;

      // Count only engagements for tips that still exist
      final validEngagements = engagementSnapshot.entries
          .where((entry) => currentTipIds.contains(entry.key))
          .length;

      print('Total tips: ${tipSnapshot.length}, Valid engagements: $validEngagements');
      setState(() {
        _totalTips = tipSnapshot.length;
        _engagedTips = validEngagements;
        _currentTipIds = currentTipIds;
      });
    } catch (e) {
      print('Error loading tip stats: $e');
    }
  }

  Map<String, double> getSpendingThresholds() {
    return {
      'dining': 500.0,
      'budgeting': 300.0,
      'savings': 300.0,
      'debt': 500.0,
      'shopping': 600.0,
      'transport': 200.0,
      'subscription': 100.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for FinancialTipsScreen');
      return Scaffold(
        backgroundColor: const Color(0xFF1C2322),
        body: const Center(
          child: Text(
            'Please log in to view tips',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return Scaffold(
      backgroundColor: const Color(0xFF1C2322),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2322),
        title: const Text(
          'Financial Tips',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.thumb_up, color: Colors.teal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FavoriteTipsScreen()),
              );
            },
            tooltip: 'Favorite Tips',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learning Progress',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _totalTips > 0 ? _engagedTips / _totalTips : 0,
                  backgroundColor: Colors.grey[700],
                  color: Colors.teal,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  'Engaged with $_engagedTips/$_totalTips tips',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Tip>>(
              stream: _tipService.getTips(),
              builder: (context, tipSnapshot) {
                if (tipSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }
                if (tipSnapshot.hasError) {
                  print('Tip StreamBuilder Error: ${tipSnapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error loading tips: ${tipSnapshot.error}',
                          style:
                          const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (!tipSnapshot.hasData || tipSnapshot.data!.isEmpty) {
                  print('No tips found in Firestore');
                  return const Center(
                    child: Text(
                      'No tips available',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }

                final tips = tipSnapshot.data!;
                print('Tips loaded: ${tips.map((t) => "${t.title} (${t.category})").toList()}');
                return FutureBuilder<Map<String, double>>(
                  future:
                  _tipService.getSpendingInsights(userId, startOfMonth, endOfMonth),
                  builder: (context, insightsSnapshot) {
                    if (insightsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.teal));
                    }
                    if (insightsSnapshot.hasError) {
                      print('Insights FutureBuilder Error: ${insightsSnapshot.error}');
                      return Center(
                        child: Text(
                          'Error loading insights: ${insightsSnapshot.error}',
                          style:
                          const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }

                    final spendingInsights = insightsSnapshot.data ?? {};
                    print('Spending insights in build: $spendingInsights');

                    return StreamBuilder<Map<String, Map<String, bool>>>(
                      stream: _tipService.getTipFeedback(userId),
                      builder: (context, feedbackSnapshot) {
                        if (feedbackSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.teal));
                        }
                        final feedback = feedbackSnapshot.data ?? {};
                        print('Feedback loaded: $feedback');

                        final thresholds = getSpendingThresholds();
                        final filteredTips = tips
                            .where((tip) {
                          // Skip if tip was deleted
                          if (!_currentTipIds.contains(tip.id)) return false;

                          final spending =
                              spendingInsights[tip.category.toLowerCase()] ?? 0.0;
                          final threshold =
                              thresholds[tip.category.toLowerCase()] ??
                                  double.infinity;
                          final isIrrelevant =
                              feedback[tip.id]?['isIrrelevant'] ?? false;
                          final isHelpful =
                              feedback[tip.id]?['isHelpful'] ?? false;
                          final shouldShow = spending >= threshold && !isIrrelevant && !isHelpful;
                          print(
                              'Tip: ${tip.title}, Category: ${tip.category}, Spending: $spending, Threshold: $threshold, IsIrrelevant: $isIrrelevant, IsHelpful: $isHelpful, ShouldShow: $shouldShow');
                          return shouldShow;
                        })
                            .toList();
                        print(
                            'Filtered tips: ${filteredTips.map((t) => t.title).toList()}');

                        if (filteredTips.isEmpty) {
                          return const Center(
                            child: Text(
                              'No relevant tips for your spending. Check your favorite tips!',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          );
                        }

                        filteredTips.sort((a, b) {
                          final aScore =
                              spendingInsights[a.category.toLowerCase()] ?? 0;
                          final bScore =
                              spendingInsights[b.category.toLowerCase()] ?? 0;
                          return bScore.compareTo(aScore);
                        });

                        return ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: filteredTips.length,
                          itemBuilder: (context, index) {
                            final tip = filteredTips[index];
                            final insight =
                            spendingInsights[tip.category.toLowerCase()];
                            final contextMessage = insight != null
                                ? 'Your ${tip.category} expenses are high this month (RM${insight.toStringAsFixed(1)}). '
                                : '';

                            return Card(
                              color: const Color(0xFF212322),
                              child: ListTile(
                                leading: Icon(
                                  _getIconForCategory(tip.category),
                                  color: Colors.teal,
                                ),
                                title: Text(
                                  tip.title,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 18),
                                ),
                                subtitle: Text(
                                  '$contextMessage${tip.description}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 14),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.thumb_up,
                                          color: Colors.teal),
                                      onPressed: () async {
                                        try {
                                          await _tipService.markTipFeedback(
                                              tip.id, true, false);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                Text('Marked as helpful')),
                                          );
                                          await _loadTipStats();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      onPressed: () async {
                                        try {
                                          await _tipService.markTipFeedback(
                                              tip.id, false, true);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                Text('Marked as irrelevant')),
                                          );
                                          await _loadTipStats();
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            // Stay on FinancialTipsScreen
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FavoriteTipsScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
        },
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'dining':
        return Icons.restaurant;
      case 'budgeting':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'debt':
        return Icons.money_off;
      case 'shopping':
        return Icons.shopping_cart;
      case 'transport':
        return Icons.directions_bus;
      case 'subscription':
        return Icons.subscriptions;
      default:
        return Icons.attach_money;
    }
  }
}