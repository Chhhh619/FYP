import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp/bottom_nav_bar.dart';
import 'package:fyp/ch/homepage.dart';
import 'package:fyp/wc/favourite_tips.dart';
import 'package:fyp/ch/settings.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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
    // FIX: Change 'userid' to 'userId' to match the field name used when storing transactions
    final transactionSnapshot = await _firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)  // ✅ Fixed: was 'userid'
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

      print('Transaction: ID=${doc.id}, Category=$categoryName, Amount=$amount');

      // Only count expenses for spending insights
      if (categoryName != 'unknown' && data['type'] == 'expense') {
        spending[categoryName.toLowerCase()] =
            (spending[categoryName.toLowerCase()] ?? 0.0) + amount.abs();
      }
    }

    print('Spending insights: $spending');
    return spending;
  }

  // NEW METHOD: Get dynamic spending thresholds from categories
  Future<Map<String, double>> getDynamicSpendingThresholds() async {
    try {
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .where('userId', isEqualTo: '') // Default categories
          .where('type', isEqualTo: 'expense') // Only expense categories
          .get();

      final thresholds = <String, double>{};
      for (var doc in categoriesSnapshot.docs) {
        final data = doc.data();
        final categoryName = data['name'] as String?;

        // ✅ Handle both string and double threshold values
        final thresholdRaw = data['threshold'];
        double? threshold;

        if (thresholdRaw is String) {
          threshold = double.tryParse(thresholdRaw);
        } else if (thresholdRaw is double) {
          threshold = thresholdRaw;
        } else if (thresholdRaw is int) {
          threshold = thresholdRaw.toDouble();
        }

        if (categoryName != null && threshold != null && threshold > 0) {
          // ✅ Normalize category names to lowercase
          thresholds[categoryName.toLowerCase()] = threshold;
          print('Loaded threshold: ${categoryName.toLowerCase()} = $threshold');
        }
      }

      print('Dynamic thresholds loaded: $thresholds');
      return thresholds;
    } catch (e) {
      print('Error loading dynamic thresholds: $e');
      return {};
    }
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _selectedIndex = 1; // Align with "Trending" tab
  int _totalTips = 0;
  int _engagedTips = 0;
  Set<String> _currentTipIds = {};

  // Add a StreamSubscription to properly manage the listener
  late StreamSubscription<List<Tip>> _tipsSubscription;

  @override
  void initState() {
    super.initState();

    // Set up the tips listener with proper state management
    _tipsSubscription = _tipService.getTips().listen((tips) {
      // Update the current tip IDs
      final newTipIds = tips.map((tip) => tip.id).toSet();

      // Only update if there's a change
      if (!setEquals(_currentTipIds, newTipIds)) {
        setState(() {
          _currentTipIds = newTipIds;
          _totalTips = tips.length; // Update total tips count
        });

        // Reload engagement stats when tips change
        _updateEngagementStats();
      }
    });
  }

  @override
  void dispose() {
    _tipsSubscription.cancel();
    super.dispose();
  }

  // Separate method to update only engagement stats
  Future<void> _updateEngagementStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for engagement stats');
      return;
    }

    try {
      // Get all engagements for current user
      final engagementSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tips_feedback')
          .get();

      // Count only engagements for tips that still exist
      final validEngagements = engagementSnapshot.docs
          .where((doc) => _currentTipIds.contains(doc.id))
          .length;

      print('Current tips: ${_currentTipIds.length}, Valid engagements: $validEngagements');

      setState(() {
        _engagedTips = validEngagements;
      });
    } catch (e) {
      print('Error loading engagement stats: $e');
    }
  }

  // Simplified method that's called when needed
  Future<void> _loadTipStats() async {
    await _updateEngagementStats();
  }

  // Add this helper function at the class level
  bool setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  // REMOVE the old hardcoded getSpendingThresholds method since we're using dynamic thresholds now

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in for FinancialTipsScreen');
      return Scaffold(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1), // Updated to match homepage
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
      backgroundColor: Color.fromRGBO(28, 28, 28, 1), // Updated to match homepage
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1), // Updated to match homepage
        elevation: 0, // Added to match homepage style
        title: const Text(
          'Financial Tips',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), // Added fontWeight to match homepage
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
            padding: const EdgeInsets.all(18.0), // Updated padding to match homepage (18 vs 16)
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
                  style: TextStyle(color: Colors.grey[400], fontSize: 14), // Updated to match homepage grey shade
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white, // Updated to white text
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
                  future: _tipService.getSpendingInsights(userId, startOfMonth, endOfMonth),
                  builder: (context, insightsSnapshot) {
                    if (insightsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.teal));
                    }
                    if (insightsSnapshot.hasError) {
                      print('Insights FutureBuilder Error: ${insightsSnapshot.error}');
                      return Center(
                        child: Text(
                          'Error loading insights: ${insightsSnapshot.error}',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    }

                    final spendingInsights = insightsSnapshot.data ?? {};
                    print('Spending insights in build: $spendingInsights');

                    // NEW: Get dynamic thresholds
                    return FutureBuilder<Map<String, double>>(
                      future: _tipService.getDynamicSpendingThresholds(),
                      builder: (context, thresholdSnapshot) {
                        if (thresholdSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.teal));
                        }
                        if (thresholdSnapshot.hasError) {
                          print('Threshold FutureBuilder Error: ${thresholdSnapshot.error}');
                          return Center(
                            child: Text(
                              'Error loading thresholds: ${thresholdSnapshot.error}',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          );
                        }

                        final dynamicThresholds = thresholdSnapshot.data ?? {};
                        print('Dynamic thresholds in build: $dynamicThresholds');

                        return StreamBuilder<Map<String, Map<String, bool>>>(
                          stream: _tipService.getTipFeedback(userId),
                          builder: (context, feedbackSnapshot) {
                            if (feedbackSnapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator(color: Colors.teal));
                            }
                            final feedback = feedbackSnapshot.data ?? {};
                            print('Feedback loaded: $feedback');

                            final filteredTips = tips.where((tip) {
                              // Skip if tip was deleted
                              if (!_currentTipIds.contains(tip.id)) return false;

                              // ✅ Normalize category names consistently
                              final tipCategory = tip.category.toLowerCase();
                              final spending = spendingInsights[tipCategory] ?? 0.0;
                              final threshold = dynamicThresholds[tipCategory] ?? double.infinity;
                              final isIrrelevant = feedback[tip.id]?['isIrrelevant'] ?? false;
                              final isHelpful = feedback[tip.id]?['isHelpful'] ?? false;
                              final shouldShow = spending >= threshold && !isIrrelevant && !isHelpful;

                              print('=== TIP FILTER DEBUG ===');
                              print('Tip: ${tip.title}');
                              print('Original Category: ${tip.category}');
                              print('Normalized Category: $tipCategory');
                              print('Spending: $spending');
                              print('Threshold: $threshold');
                              print('IsIrrelevant: $isIrrelevant');
                              print('IsHelpful: $isHelpful');
                              print('ShouldShow: $shouldShow');
                              print('========================');

                              return shouldShow;
                            }).toList();

                            print('Filtered tips: ${filteredTips.map((t) => t.title).toList()}');

                            if (filteredTips.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lightbulb_outline, size: 80, color: Colors.grey[600]), // Added icon to match homepage style
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Great job! No urgent tips needed',
                                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Check your favorite tips for more insights!',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            filteredTips.sort((a, b) {
                              final aScore = spendingInsights[a.category.toLowerCase()] ?? 0;
                              final bScore = spendingInsights[b.category.toLowerCase()] ?? 0;
                              return bScore.compareTo(aScore);
                            });

                            return ListView.builder(
                              padding: const EdgeInsets.all(18.0), // Updated padding to match homepage
                              itemCount: filteredTips.length,
                              itemBuilder: (context, index) {
                                final tip = filteredTips[index];
                                final insight = spendingInsights[tip.category.toLowerCase()];
                                final threshold = dynamicThresholds[tip.category.toLowerCase()];

                                // Enhanced context message with threshold info
                                final contextMessage = insight != null && threshold != null
                                    ? 'Your ${tip.category} expenses are RM${insight.toStringAsFixed(1)} this month '
                                    '(${((insight - threshold)).toStringAsFixed(1)} over the RM${threshold.toStringAsFixed(0)} threshold). '
                                    : insight != null
                                    ? 'Your ${tip.category} expenses are high this month (RM${insight.toStringAsFixed(1)}). '
                                    : '';

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10), // Added spacing between cards to match homepage
                                  child: Card(
                                    color: Color.fromRGBO(33, 35, 34, 1), // Updated to match homepage card color
                                    child: ListTile(
                                      leading: Icon(
                                        _getIconForCategory(tip.category),
                                        color: Colors.teal,
                                        size: 28, // Slightly larger icon
                                      ),
                                      title: Text(
                                        tip.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500), // Added fontWeight to match homepage
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 8), // Added padding for better spacing
                                        child: Text(
                                          '$contextMessage${tip.description}',
                                          style: TextStyle(
                                              color: Colors.grey[400], // Updated to match homepage grey shade
                                              fontSize: 14),
                                        ),
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
                                  ),
                                );
                              },
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