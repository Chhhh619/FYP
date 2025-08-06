import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'subscription_record.dart';
import 'edit_subscription.dart'; // Import the new edit page

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  DateTime _calculateNextDueDate(DateTime lastGenerated, String repeat) {
    switch (repeat.toLowerCase()) {
      case 'daily':
        return lastGenerated.add(const Duration(days: 1));
      case 'weekly':
        return lastGenerated.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          lastGenerated.year,
          lastGenerated.month + 1,
          lastGenerated.day,
        );
      case 'annually':
        return DateTime(
          lastGenerated.year + 1,
          lastGenerated.month,
          lastGenerated.day,
        );
      default:
        return lastGenerated;
    }
  }

  Future<void> _editSubscription(String subscriptionId, Map<String, dynamic> subscriptionData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSubscriptionPage(
          subscriptionId: subscriptionId,
          subscriptionData: subscriptionData,
        ),
      ),
    );

    // Refresh the page if the subscription was updated
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _deleteSubscription(String subscriptionId) async {
    try {
      await _firestore.collection('subscriptions').doc(subscriptionId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete subscription: $e')),
      );
    }
  }

  void _showSubscriptionOptions(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unnamed';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.teal),
                title: const Text('Edit Subscription', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _editSubscription(doc.id, data);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Subscription', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(doc.id, name);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(String subscriptionId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(33, 35, 34, 1),
        title: const Text('Delete Subscription', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete the "$name" subscription?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.teal)),
          ),
          TextButton(
            onPressed: () {
              _deleteSubscription(subscriptionId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // Back arrow button with grey background
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              // Title
              const Expanded(
                child: Text(
                  'Subscriptions',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 16),
              // Add button with grey background
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddSubscriptionPage()),
                  );
                  setState(() {}); // Rebuild to fetch updated subscriptions
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white)))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('subscriptions')
            .where('userId', isEqualTo: user.uid)
            .orderBy('startDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.subscriptions,
                    size: 80,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No subscriptions yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first subscription to get started',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final sevenDaysFromNow = now.add(const Duration(days: 7));

          final pendingBills = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final startDate = (data['startDate'] as Timestamp).toDate();
            final repeat = data['repeat'] ?? 'Monthly';
            final lastGenerated = data['lastGenerated'] != null
                ? (data['lastGenerated'] as Timestamp).toDate()
                : startDate;
            final nextDueDate = _calculateNextDueDate(lastGenerated, repeat);
            return !nextDueDate.isBefore(now) && nextDueDate.isBefore(sevenDaysFromNow);
          }).toList();

          return ListView(
            children: [
              if (pendingBills.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Pending Bills (Next 7 Days)',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...pendingBills.map((doc) => _buildSubscriptionTile(doc, now, true)).toList(),
                const SizedBox(height: 16),
              ],

              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'All Subscriptions',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...docs.map((doc) => _buildSubscriptionTile(doc, now, false)).toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionTile(QueryDocumentSnapshot doc, DateTime now, bool isPending) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unnamed';
    final amount = (data['amount'] is int || data['amount'] is double)
        ? (data['amount'] as num).toStringAsFixed(2)
        : '0.00';
    final icon = data['icon'] ?? '❔';
    final startDate = (data['startDate'] as Timestamp).toDate();
    final repeat = data['repeat'] ?? 'Monthly';
    final lastGenerated = data['lastGenerated'] != null
        ? (data['lastGenerated'] as Timestamp).toDate()
        : startDate;
    final nextDueDate = _calculateNextDueDate(lastGenerated, repeat);
    final formattedDate = '${nextDueDate.day} ${_monthName(nextDueDate.month)}';

    final isAssetPath = icon.startsWith('assets/');
    final isImageUrl = icon.startsWith('http://') || icon.startsWith('https://');

    return GestureDetector(
      onTap: () => _showSubscriptionOptions(doc),
      onLongPress: () => _showDeleteConfirmation(doc.id, name),
      child: Card(
        color: isPending ? Colors.orange[900]?.withOpacity(0.3) : Colors.grey[800],
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          leading: CircleAvatar(
            backgroundColor: Colors.teal.withOpacity(0.2),
            child: isAssetPath
                ? ClipOval(
              child: Image.asset(
                icon,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    '❔',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  );
                },
              ),
            )
                : isImageUrl
                ? ClipOval(
              child: Image.network(
                icon,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    '❔',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  );
                },
              ),
            )
                : Text(icon, style: const TextStyle(fontSize: 18, color: Colors.white)),
          ),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPending ? 'Due: $formattedDate' : 'Next: $formattedDate',
                style: TextStyle(
                  color: isPending ? Colors.orange[300] : Colors.cyan,
                  fontWeight: isPending ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              Text(
                'Repeats $repeat',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RM$amount',
                style: TextStyle(
                  color: isPending ? Colors.orange[300] : Colors.cyan,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}