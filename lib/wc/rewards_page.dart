import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  _RewardsPageState createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _badges = [];
  String? _equippedBadge;
  bool _isLoading = true;
  int _userPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadBadgesAndPoints();
  }

  Future<void> _loadBadgesAndPoints() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Fetch user's badges and equipped badge and points
      final badgeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .orderBy('earnedAt', descending: true)
          .get();

      final userDoc = await _firestore.collection('users').doc(userId).get();

      setState(() {
        _badges = badgeSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        final userData = userDoc.data();
        _equippedBadge = userData?['equippedBadge'];
        _userPoints = userData?['points'] ?? 0;
        _isLoading = false;
      });

      print('Badges loaded: ${_badges.map((b) => b['name']).toList()}');
      print('User points: $_userPoints');
      print('Equipped badge: $_equippedBadge');
    } catch (e) {
      print('Error loading badges and points: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _equipBadge(String badgeId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      await _firestore.collection('users').doc(userId).update({
        'equippedBadge': badgeId,
      });

      setState(() {
        _equippedBadge = badgeId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Badge equipped!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true; // Indicate success
    } catch (e) {
      print('Error equipping badge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to equip badge: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false; // Indicate failure
    }
  }

  Future<bool> _unequipBadge() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      await _firestore.collection('users').doc(userId).update({
        'equippedBadge': FieldValue.delete(),
      });

      setState(() {
        _equippedBadge = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Badge unequipped!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true; // Indicate success
    } catch (e) {
      print('Error unequipping badge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unequip badge: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false; // Indicate failure
    }
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final isEquipped = _equippedBadge == badge['id'];
    final earnedAt = badge['earnedAt'] as Timestamp?;
    final challengeId = badge['challengeId'] as String?;

    return Card(
      color: const Color.fromRGBO(33, 35, 34, 1),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: isEquipped ? 8 : 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isEquipped
              ? Border.all(color: Colors.teal, width: 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge icon with background
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isEquipped ? Colors.teal.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: isEquipped
                          ? Border.all(color: Colors.teal, width: 2)
                          : Border.all(color: Colors.grey, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        badge['icon'] ?? '🏆',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Badge info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                badge['name'] ?? 'Unknown Badge',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isEquipped) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'EQUIPPED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge['description'] ?? 'No description available',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Earned date and challenge info
                        Row(
                          children: [
                            const Icon(Icons.schedule, color: Colors.grey, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                earnedAt != null
                                    ? 'Earned ${DateFormat('MMM dd, yyyy').format(earnedAt.toDate())}'
                                    : 'Recently earned',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        if (challengeId != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.yellow, size: 16),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'From challenge',
                                  style: const TextStyle(color: Colors.yellow, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  if (!isEquipped)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final success = await _equipBadge(badge['id']);
                          if (success) {
                            Navigator.pop(context, true); // Return true to indicate badge was equipped
                          }
                        },
                        icon: const Icon(Icons.star, size: 18),
                        label: const Text('Equip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (isEquipped)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final success = await _unequipBadge();
                          if (success) {
                            Navigator.pop(context, true); // Return true to indicate badge was unequipped
                          }
                        },
                        icon: const Icon(Icons.star_border, size: 18),
                        label: const Text('Unequip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(33, 35, 34, 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Icon(Icons.stars, color: Colors.yellow, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '$_userPoints',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Total Points',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.grey[600],
              ),
              Column(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.orange, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '${_badges.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Badges Earned',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),

          if (_equippedBadge != null) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Currently Equipped:',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_badges.any((badge) => badge['id'] == _equippedBadge))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _badges.firstWhere((badge) => badge['id'] == _equippedBadge)['icon'] ?? '🏆',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _badges.firstWhere((badge) => badge['id'] == _equippedBadge)['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _badges.firstWhere((badge) => badge['id'] == _equippedBadge)['description'] ?? '',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Rewards',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Text(
            'Please log in to view rewards.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFB0BEC5).withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        title: const Text(
          'Rewards',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,

      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
        color: Colors.teal,
        backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
        onRefresh: _loadBadgesAndPoints,
        child: _badges.isEmpty
            ? _buildEmptyState()
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsHeader(),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Your Badges',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              ..._badges.map((badge) => _buildBadgeCard(badge)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildStatsHeader(),
          const SizedBox(height: 40),
          const Center(
            child: Column(
              children: [
                Icon(Icons.emoji_events, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Text(
                  'No badges earned yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Complete challenges to earn badges and show off your financial achievements!',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 24),
                Icon(Icons.trending_up, color: Colors.teal, size: 40),
                SizedBox(height: 8),
                Text(
                  'Start by recording your transactions',
                  style: TextStyle(color: Colors.teal, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Stats skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(33, 35, 34, 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(2, (index) => Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 24,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 14,
                    color: Colors.grey[700],
                  ),
                ],
              )),
            ),
          ),
          const SizedBox(height: 24),

          // Badge cards skeleton
          ...List.generate(3, (index) => Card(
            color: const Color.fromRGBO(33, 35, 34, 1),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 150,
                          height: 18,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 200,
                          height: 14,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 12,
                          color: Colors.grey[700],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}