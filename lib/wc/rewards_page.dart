import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Fetch user's badges and equipped badge
      final badgeSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .get();
      final userDoc = await _firestore.collection('users').doc(userId).get();
      setState(() {
        _badges = badgeSnapshot.docs.map((doc) => doc.data()).toList();
        _equippedBadge = userDoc.data()?['equippedBadge'];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading badges: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _equipBadge(String badgeId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'equippedBadge': badgeId,
      });
      setState(() {
        _equippedBadge = badgeId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Badge equipped!')),
      );
    } catch (e) {
      print('Error equipping badge: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to equip badge: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        body: Center(
          child: Text(
            'Please log in to view rewards.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(28, 28, 28, 1),
        title: Text(
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
          : _badges.isEmpty
          ? Center(
        child: Text(
          'No badges earned yet. Complete challenges to earn badges!',
          style: TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _badges.length,
        itemBuilder: (context, index) {
          final badge = _badges[index];
          return _buildBadgeCard(badge);
        },
      ),
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge) {
    final isEquipped = _equippedBadge == badge['id'];
    return Card(
      color: Color.fromRGBO(33, 35, 34, 1),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Text(
          badge['icon'],
          style: TextStyle(fontSize: 24),
        ),
        title: Text(
          badge['name'],
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        subtitle: Text(
          badge['description'],
          style: TextStyle(color: Colors.grey[300], fontSize: 14),
        ),
        trailing: ElevatedButton(
          onPressed: isEquipped ? null : () => _equipBadge(badge['id']),
          style: ElevatedButton.styleFrom(
            backgroundColor: isEquipped ? Colors.grey : Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: Text(isEquipped ? 'Equipped' : 'Equip'),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
              (index) => Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Card(
              color: Color.fromRGBO(33, 35, 34, 1),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[700],
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 18,
                            color: Colors.grey[700],
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 150,
                            height: 14,
                            color: Colors.grey[700],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}