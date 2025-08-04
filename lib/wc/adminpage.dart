import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'banned_users_page.dart';
import 'admin_challenges_page.dart';
import 'financial_tips.dart'; // Import Tip class from financial_tips.dart
import 'package:fyp/ch/categories_list.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _tipTitleController = TextEditingController();
  final TextEditingController _tipDescriptionController = TextEditingController();
  final TextEditingController _categoryNameController = TextEditingController();
  String? _tipCategory;
  String? _categoryType;
  String _selectedEmoji = '💰';
  bool _isLoading = true;
  bool _hasAccess = false;

  final List<String> _categories = [
    'dining',
    'budgeting',
    'savings',
    'debt',
    'shopping',
    'transport',
    'subscription',
  ];

  final List<String> _categoryTypes = ['expense', 'income'];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tipTitleController.dispose();
    _tipDescriptionController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in as an admin')),
      );
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userDoc.exists && userData != null && userData['isAdmin'] == true) {
        setState(() {
          _hasAccess = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied: Admin only')),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking admin access: $e')),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildUserDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserProfile(Map<String, dynamic> userData, String userId) {
    final isBanned = userData['banned'] == true;
    final isAdmin = userData['isAdmin'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.teal),
            const SizedBox(width: 8),
            const Text(
              'User Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userData['photoURL'] != null)
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(userData['photoURL'] as String),
                  ),
                ),
              const SizedBox(height: 16),
              _buildUserDetailRow('User ID:', userId),
              _buildUserDetailRow('Name:', userData['displayName'] ?? 'N/A'),
              _buildUserDetailRow('Email:', userData['email'] ?? 'N/A'),
              _buildUserDetailRow('Username:', userData['username'] ?? 'N/A'),
              _buildUserDetailRow('Points:', userData['points']?.toString() ?? '0'),
              _buildUserDetailRow('Badge:', userData['equippedBadge'] ?? 'None'),
              _buildUserDetailRow('Transactions:', userData['totalTransactions']?.toString() ?? '0'),
              _buildUserDetailRow(
                'Joined:',
                userData['created_at'] != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format((userData['created_at'] as Timestamp).toDate())
                    : 'N/A',
              ),
              _buildUserDetailRow(
                'Last Login:',
                userData['lastLogin'] != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format((userData['lastLogin'] as Timestamp).toDate())
                    : 'N/A',
              ),
              _buildUserDetailRow('Status:', isBanned ? 'Banned' : (isAdmin ? 'Admin' : 'Active')),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showUserChallengeManagement(userId, userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'User');
                },
                icon: const Icon(Icons.emoji_events),
                label: const Text('Manage Challenges'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 8),
              if (!isAdmin && !isBanned)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _banUser(userId, userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'User');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Ban User'),
                ),
              if (isBanned)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _unbanUser(userId, userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'User');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Unban User'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showUserChallengeManagement(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manage Challenges for $userName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.grey),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssignChallengeDialog(userId, userName),
                      icon: const Icon(Icons.add),
                      label: const Text('Assign Challenge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Current Challenges:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('challengeProgress')
                      .snapshots(),
                  builder: (context, progressSnapshot) {
                    if (progressSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.teal));
                    }
                    if (!progressSnapshot.hasData || progressSnapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No challenges assigned',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('challenges').snapshots(),
                      builder: (context, challengesSnapshot) {
                        if (challengesSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.teal));
                        }
                        final challenges = Map.fromEntries(
                          challengesSnapshot.data?.docs.map((doc) =>
                              MapEntry(doc.id, doc.data() as Map<String, dynamic>)) ?? [],
                        );
                        return ListView.builder(
                          itemCount: progressSnapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final progressDoc = progressSnapshot.data!.docs[index];
                            final progressData = progressDoc.data() as Map<String, dynamic>;
                            final challengeId = progressDoc.id;
                            final challengeData = challenges[challengeId] as Map<String, dynamic>?;

                            if (challengeData == null) {
                              return ListTile(
                                title: const Text('Unknown Challenge', style: TextStyle(color: Colors.red)),
                                subtitle: Text('Challenge ID: $challengeId', style: const TextStyle(color: Colors.grey)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeUserChallenge(userId, challengeId),
                                ),
                              );
                            }

                            final progress = progressData['progress'] ?? 0;
                            final isCompleted = progressData['isCompleted'] ?? false;
                            final isClaimed = progressData['isClaimed'] ?? false;

                            return Card(
                              color: Colors.grey[800],
                              child: ListTile(
                                leading: Text(
                                  challengeData['icon'] ?? '🎯',
                                  style: const TextStyle(fontSize: 24),
                                ),
                                title: Text(
                                  challengeData['title'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      challengeData['description'] ?? '',
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Progress: ${progress.toInt()}/${challengeData['targetValue']?.toInt() ?? 0}',
                                      style: TextStyle(
                                        color: isCompleted ? Colors.green : Colors.yellow,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isCompleted)
                                      Text(
                                        isClaimed ? 'Completed & Claimed' : 'Completed - Not Claimed',
                                        style: TextStyle(
                                          color: isClaimed ? Colors.green : Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCompleted && !isClaimed)
                                      IconButton(
                                        icon: const Icon(Icons.card_giftcard, color: Colors.green),
                                        onPressed: () => _forceClaimReward(userId, challengeId, challengeData),
                                        tooltip: 'Force Claim Reward',
                                      ),

                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeUserChallenge(userId, challengeId),
                                      tooltip: 'Remove Challenge',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignChallengeDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_task, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Assign Challenge to $userName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'Available Challenges:',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('challenges')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.teal));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No active challenges available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final challengeDoc = snapshot.data!.docs[index];
                        final challengeData = challengeDoc.data() as Map<String, dynamic>;
                        final challengeId = challengeDoc.id;
                        return Card(
                          color: Colors.grey[800],
                          child: ListTile(
                            leading: Text(
                              challengeData['icon'] ?? '🎯',
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              challengeData['title'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  challengeData['description'] ?? '',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Reward: ${challengeData['rewardPoints'] ?? 0} points',
                                  style: const TextStyle(color: Colors.yellow, fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _assignChallengeToUser(userId, challengeId, challengeData),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Assign'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _assignChallengeToUser(String userId, String challengeId, Map<String, dynamic> challengeData) async {
    try {
      final existingProgress = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .doc(challengeId)
          .get();
      if (existingProgress.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User already has this challenge'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .doc(challengeId)
          .set({
        'progress': 0,
        'isCompleted': false,
        'isClaimed': false,
        'assignedAt': FieldValue.serverTimestamp(),
        'assignedBy': _auth.currentUser?.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Challenge "${challengeData['title']}" assigned successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning challenge: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeUserChallenge(String userId, String challengeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .doc(challengeId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing challenge: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetSpecificChallenge(String userId, String challengeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .doc(challengeId)
          .update({
        'progress': 0,
        'isCompleted': false,
        'isClaimed': false,
        'resetAt': FieldValue.serverTimestamp(),
        'resetBy': _auth.currentUser?.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting challenge: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetUserChallenges(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Reset All Challenges', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reset all challenges for $userName? This will reset progress but keep the challenges assigned.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset All', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final progressSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .get();
      final batch = _firestore.batch();
      for (var doc in progressSnapshot.docs) {
        batch.update(doc.reference, {
          'progress': 0,
          'isCompleted': false,
          'isClaimed': false,
          'resetAt': FieldValue.serverTimestamp(),
          'resetBy': _auth.currentUser?.uid,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All challenges reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resetting challenges: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _forceClaimReward(String userId, String challengeId, Map<String, dynamic> challengeData) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'points': FieldValue.increment(challengeData['rewardPoints'] ?? 0),
      });
      final progressRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('challengeProgress')
          .doc(challengeId);
      batch.update(progressRef, {
        'isClaimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
        'claimedBy': _auth.currentUser?.uid,
      });
      if (challengeData['rewardBadge'] != null) {
        final badgeData = challengeData['rewardBadge'] as Map<String, dynamic>;
        final badgeRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc(badgeData['id'] as String);
        batch.set(badgeRef, {
          'id': badgeData['id'],
          'name': badgeData['name'],
          'description': badgeData['description'],
          'icon': badgeData['icon'],
          'earnedAt': FieldValue.serverTimestamp(),
          'challengeId': challengeId,
          'forceClaimed': true,
          'claimedBy': _auth.currentUser?.uid,
        });
      }
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reward claimed! +${challengeData['rewardPoints'] ?? 0} points'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error claiming reward: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _banUser(String userId, String userName) async {
    // Check if user is trying to ban themselves
    if (userId == _auth.currentUser?.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot ban yourself'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Ban User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to ban "${userName.isEmpty ? userId : userName}"?\n\nThis will prevent them from accessing the application.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ban User'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update user document with ban information
      await _firestore.collection('users').doc(userId).update({
        'banned': true,
        'bannedAt': FieldValue.serverTimestamp(),
        'bannedBy': _auth.currentUser?.uid,
        'bannedReason': 'Banned by admin', // You can add a reason field
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User "$userName" has been banned successfully'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _unbanUser(userId, userName),
          ),
        ),
      );
    } catch (e) {
      print('Error banning user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error banning user: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// Improved unban user function
  Future<void> _unbanUser(String userId, String userName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Unban User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to unban "${userName.isEmpty ? userId : userName}"?\n\nThis will restore their access to the application.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unban User'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update user document to remove ban
      await _firestore.collection('users').doc(userId).update({
        'banned': false,
        'unbannedAt': FieldValue.serverTimestamp(),
        'unbannedBy': _auth.currentUser?.uid,
        // Optionally remove ban-related fields
        'bannedAt': FieldValue.delete(),
        'bannedBy': FieldValue.delete(),
        'bannedReason': FieldValue.delete(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User "$userName" has been unbanned successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error unbanning user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error unbanning user: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// Add this method to check if a user can be banned
  bool _canBanUser(Map<String, dynamic> userData, String userId) {
    // Don't allow banning admins or the current user
    if (userData['isAdmin'] == true || userId == _auth.currentUser?.uid) {
      return false;
    }
    // Don't allow banning already banned users
    if (userData['banned'] == true) {
      return false;
    }
    return true;
  }

// Add this method to check if a user can be unbanned
  bool _canUnbanUser(Map<String, dynamic> userData) {
    // Only allow unbanning if user is currently banned
    return userData['banned'] == true;
  }

  Future<void> _addTip() async {
    if (_tipTitleController.text.trim().isEmpty ||
        _tipDescriptionController.text.trim().isEmpty ||
        _tipCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all tip fields')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await _firestore.collection('tips').add({
        'title': _tipTitleController.text.trim(),
        'description': _tipDescriptionController.text.trim(),
        'category': _tipCategory,
        'timestamp': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tip added successfully')),
      );
      _tipTitleController.clear();
      _tipDescriptionController.clear();
      _tipCategory = null;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding tip: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editTip(String tipId, Map<String, dynamic> tipData) async {
    _tipTitleController.text = tipData['title'] ?? '';
    _tipDescriptionController.text = tipData['description'] ?? '';
    _tipCategory = tipData['category'] as String?;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Edit Financial Tip',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _tipTitleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tipDescriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipCategory,
                hint: const Text(
                  'Select Category',
                  style: TextStyle(color: Colors.grey),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _tipCategory = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
              if (_tipTitleController.text.trim().isEmpty ||
                  _tipDescriptionController.text.trim().isEmpty ||
                  _tipCategory == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all tip fields')),
                );
                return;
              }
              setState(() {
                _isLoading = true;
              });
              try {
                await _firestore.collection('tips').doc(tipId).update({
                  'title': _tipTitleController.text.trim(),
                  'description': _tipDescriptionController.text.trim(),
                  'category': _tipCategory,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tip updated successfully')),
                );
                _tipTitleController.clear();
                _tipDescriptionController.clear();
                _tipCategory = null;
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating tip: $e')),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.black,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Update Tip'),
          ),
        ],
      ),
    );
  }

  void _showAddTipDialog() {
    _tipTitleController.clear();
    _tipDescriptionController.clear();
    _tipCategory = null;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Add New Financial Tip',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _tipTitleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tipDescriptionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _tipCategory,
                hint: const Text(
                  'Select Category',
                  style: TextStyle(color: Colors.grey),
                ),
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.teal, width: 2),
                  ),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _tipCategory = value;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _addTip,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.black,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Add Tip'),
          ),
        ],
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

  // ==================== CATEGORY MANAGEMENT ====================
  void _showAddCategoryDialog() {
    _categoryNameController.clear();
    _categoryType = 'expense';
    _selectedEmoji = '💰';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Add Default Category',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _categoryNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _categoryType,
                  hint: const Text(
                    'Select Type',
                    style: TextStyle(color: Colors.grey),
                  ),
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal, width: 2),
                    ),
                  ),
                  items: _categoryTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _categoryType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Emoji:',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 8),
                // Alternative: Use Wrap widget instead of GridView
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: [
                    for (var emoji in [
                      '💰', '🍔', '🚗', '🏠', '🛒', '🎮',
                      '✈️', '🏥', '🎓', '💊', '👕', '🎁',
                      '🍿', '☕', '🍺', '🍎', '🍕', '🏋️'
                    ])
                      GestureDetector(
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: _selectedEmoji == emoji
                              ? Colors.teal
                              : Colors.grey[700],
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _addDefaultCategory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.black,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Future<void> _addDefaultCategory() async {
    if (_categoryNameController.text.trim().isEmpty || _categoryType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all category fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('categories').add({
        'name': _categoryNameController.text.trim(),
        'icon': _selectedEmoji,
        'type': _categoryType,
        'userid': "", // Change from null to empty string

      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default category added successfully')),
      );
      _categoryNameController.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding category: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _deleteCategory(String categoryId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Delete Category', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this default category?',
          style: TextStyle(color: Colors.white),
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

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('categories').doc(categoryId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildCategoryCard(Map<String, dynamic> category, String categoryId) {
    return Card(
      color: Colors.grey[800],
      child: ListTile(
        leading: Text(
          category['icon'] ?? '💰',
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(
          category['name'] ?? 'Unknown',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          'Type: ${category['type'] ?? 'N/A'}',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCategory(categoryId),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }
    if (!_hasAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(
          child: Text(
            'Checking admin access...',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.teal),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminChallengesPage()),
              );
            },
            tooltip: 'Manage Global Challenges',
          ),

          IconButton(
            icon: const Icon(Icons.person_off, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BannedUsersPage()),
              );
            },
            tooltip: 'View Banned Users',
          ),
        ],
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              labelColor: Colors.teal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.teal,
              tabs: [
                Tab(icon: Icon(Icons.lightbulb), text: 'Financial Tips'),
                Tab(icon: Icon(Icons.category), text: 'Categories'),
                Tab(icon: Icon(Icons.people), text: 'User Management'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Financial Tips Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Financial Tips',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showAddTipDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Add New Tip'),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: StreamBuilder<List<Tip>>(
                            stream: _firestore
                                .collection('tips')
                                .orderBy('timestamp', descending: true)
                                .snapshots()
                                .map((snapshot) {
                              print('Firestore tips snapshot: ${snapshot.docs.length} documents');
                              return snapshot.docs.map((doc) {
                                print('Processing tip: ${doc.id} - ${doc.data()}');
                                return Tip.fromFirestore(doc);
                              }).toList();
                            }),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: Colors.teal));
                              }
                              if (snapshot.hasError) {
                                print('Error loading tips: ${snapshot.error}');
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Error: ${snapshot.error}',
                                        style: const TextStyle(color: Colors.white),
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
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                print('No tips found in Firestore');
                                return const Center(
                                  child: Text(
                                    'No tips available',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }
                              final tips = snapshot.data!;
                              print('Tips loaded in admin page: ${tips.map((t) => "${t.title} (${t.category})").toList()}');
                              return ListView.builder(
                                itemCount: tips.length,
                                itemBuilder: (context, index) {
                                  final tip = tips[index];
                                  return Card(
                                    color: Colors.grey[800],
                                    child: ListTile(
                                      leading: Icon(
                                        _getIconForCategory(tip.category),
                                        color: Colors.teal,
                                      ),
                                      title: Text(
                                        tip.title,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Text(
                                        '${tip.category} - ${tip.description}',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.white),
                                            onPressed: () => _editTip(tip.id, {
                                              'title': tip.title,
                                              'description': tip.description,
                                              'category': tip.category,
                                            }),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () async {
                                              try {
                                                await _firestore.collection('tips').doc(tip.id).delete();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Tip deleted')),
                                                );
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
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
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Default Categories Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Manage Default Categories',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showAddCategoryDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Add Default Category'),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _firestore
                                .collection('categories')
                                .where('userid', whereIn: [""]) // Only empty string

                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: Colors.teal));
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No default categories available',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }
                              return ListView.builder(
                                itemCount: snapshot.data!.docs.length,
                                itemBuilder: (context, index) {
                                  final doc = snapshot.data!.docs[index];
                                  final category = doc.data() as Map<String, dynamic>;
                                  return _buildCategoryCard(category, doc.id);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User Management Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Management',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _firestore.collection('users').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: Colors.teal));
                              }
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Error: ${snapshot.error}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No users available',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }
                              final users = snapshot.data!.docs;
                              return ListView.builder(
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final userData = users[index].data() as Map<String, dynamic>;
                                  final userId = users[index].id;
                                  final isBanned = userData['banned'] == true;
                                  final isAdmin = userData['isAdmin'] == true;
                                  return Card(
                                    color: Colors.grey[800],
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isBanned ? Colors.red : (isAdmin ? Colors.orange : Colors.teal),
                                        child: Text(
                                          userData['displayName']?.substring(0, 1) ??
                                              userData['email']?.substring(0, 1) ?? 'U',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              userData['displayName'] ??
                                                  userData['email']?.split('@')[0] ?? 'User',
                                              style: TextStyle(
                                                color: isBanned ? Colors.redAccent : Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (isAdmin)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'ADMIN',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          if (isBanned)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'BANNED',
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
                                            userData['email'] ?? 'N/A',
                                            style: TextStyle(
                                              color: isBanned ? Colors.redAccent[200] : Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            'Points: ${userData['points'] ?? 0} | Transactions: ${userData['totalTransactions'] ?? 0}',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.emoji_events, color: Colors.teal),
                                            onPressed: () => _showUserChallengeManagement(
                                              userId,
                                              userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'User',
                                            ),
                                            tooltip: 'Manage Challenges',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.info_outline, color: Colors.white),
                                            onPressed: () => _showUserProfile(userData, userId),
                                            tooltip: 'View Profile',
                                          ),
                                          if (!isBanned && !isAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.block, color: Colors.red),
                                              onPressed: () => _banUser(
                                                userId,
                                                userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'User',
                                              ),
                                              tooltip: 'Ban User',
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
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