import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BannedUsersPage extends StatefulWidget {
  const BannedUsersPage({super.key});

  @override
  _BannedUsersPageState createState() => _BannedUsersPageState();
}

class _BannedUsersPageState extends State<BannedUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _unbanUser(String userId, String userName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('Unban User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to unban "${userName.isEmpty ? userId : userName}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unban', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('users').doc(userId).update({
        'banned': false,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unbanned successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unbanning user: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showUserProfile(Map<String, dynamic> userData, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text('User Profile', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User ID: $userId', style: const TextStyle(color: Colors.white)),
              Text('Display Name: ${userData['displayName'] ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
              Text('Email: ${userData['email'] ?? 'N/A'}', style: const TextStyle(color: Colors.white)),
              Text('Points: ${userData['points']?.toString() ?? '0'}', style: const TextStyle(color: Colors.white)),
              Text('Equipped Badge: ${userData['equippedBadge'] ?? 'None'}', style: const TextStyle(color: Colors.white)),
              Text('Total Transactions: ${userData['totalTransactions']?.toString() ?? '0'}', style: const TextStyle(color: Colors.white)),
              Text(
                'Account Created: ${userData['createdAt'] != null ? DateFormat('yyyy-MM-dd').format((userData['createdAt'] as Timestamp).toDate()) : 'N/A'}',
                style: const TextStyle(color: Colors.white),
              ),
              Text('Is Admin: ${userData['isAdmin'] == true ? 'Yes' : 'No'}', style: const TextStyle(color: Colors.white)),
              Text('Banned: ${userData['banned'] == true ? 'Yes' : 'No'}', style: const TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: const Text(
          'Banned Users',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Banned Users List',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').where('banned', isEqualTo: true).snapshots(),
                builder: (context, snapshot) {
                  if (_isLoading) {
                    return const Center(child: CircularProgressIndicator(color: Colors.teal));
                  }
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
                        'No banned users',
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
                      return Card(
                        color: Colors.grey[800],
                        child: ListTile(
                          title: Text(
                            userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'User',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Email: ${userData['email'] ?? 'N/A'}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.person, color: Colors.white),
                                onPressed: () => _showUserProfile(userData, userId),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restore, color: Colors.teal),
                                onPressed: () => _unbanUser(
                                  userId,
                                  userData['displayName'] ?? userData['email']?.split('@')[0] ?? 'User',
                                ),
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
    );
  }
}